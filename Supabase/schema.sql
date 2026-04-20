-- FullBars Analytics Database Schema
-- Supabase / PostgreSQL
-- All data is anonymized — no PII, no exact addresses, no MAC addresses.
-- Location granularity: ZIP code only.

-- =============================================================================
-- EXTENSIONS
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";    -- for text search on ISP names

-- =============================================================================
-- ENUM TYPES
-- =============================================================================
CREATE TYPE dwelling_type AS ENUM (
  'house', 'apartment', 'condo', 'townhouse', 'rental_unit', 'commercial', 'other'
);

CREATE TYPE grade_letter AS ENUM ('A', 'B', 'C', 'D', 'F');

CREATE TYPE dead_zone_severity AS ENUM ('critical', 'severe', 'moderate');

CREATE TYPE device_type AS ENUM ('router', 'mesh_node', 'computer', 'tv', 'tablet');

CREATE TYPE room_type AS ENUM (
  'living_room', 'kitchen', 'dining_room', 'bedroom', 'master_bedroom',
  'bathroom', 'office', 'hallway', 'entryway', 'laundry',
  'garage', 'basement', 'attic', 'outdoor', 'other'
);

CREATE TYPE ad_placement_type AS ENUM ('isp', 'mesh_hardware', 'router', 'extender', 'general');

-- =============================================================================
-- CORE ANALYTICS TABLES
-- =============================================================================

-- Each completed scan session uploads one row here.
-- This is the primary fact table for ISP performance analytics.
CREATE TABLE scan_sessions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  app_version     TEXT NOT NULL DEFAULT '1.0.0',

  -- Location (ZIP only — no street address)
  zip_code        TEXT NOT NULL,
  state_code      TEXT,            -- derived from ZIP for regional rollups
  metro_area      TEXT,            -- CBSA name, derived server-side

  -- Dwelling characteristics
  dwelling_type   dwelling_type NOT NULL,
  square_footage  INT NOT NULL,
  floor_count     INT NOT NULL DEFAULT 1,
  occupant_count  INT NOT NULL DEFAULT 1,

  -- ISP / plan
  isp_name        TEXT NOT NULL,
  isp_promised_download_mbps  DOUBLE PRECISION NOT NULL DEFAULT 0,
  isp_promised_upload_mbps    DOUBLE PRECISION NOT NULL DEFAULT 0,

  -- Measured aggregate performance
  measured_download_mbps      DOUBLE PRECISION NOT NULL,
  measured_upload_mbps        DOUBLE PRECISION NOT NULL,
  measured_latency_ms         DOUBLE PRECISION NOT NULL,
  measured_jitter_ms          DOUBLE PRECISION NOT NULL DEFAULT 0,

  -- Coverage summary
  coverage_strong_pct   DOUBLE PRECISION NOT NULL DEFAULT 0,  -- % points >= -60 dBm
  coverage_moderate_pct DOUBLE PRECISION NOT NULL DEFAULT 0,  -- % points [-75, -60)
  coverage_weak_pct     DOUBLE PRECISION NOT NULL DEFAULT 0,  -- % points < -75 dBm
  total_points_sampled  INT NOT NULL DEFAULT 0,

  -- Network topology
  has_mesh_network BOOLEAN NOT NULL DEFAULT false,
  mesh_node_count  INT NOT NULL DEFAULT 0,
  wifi_device_count INT NOT NULL DEFAULT 0,
  ble_device_count  INT NOT NULL DEFAULT 0,

  -- Grading
  overall_grade    grade_letter NOT NULL,
  overall_score    DOUBLE PRECISION NOT NULL,  -- 0-100

  -- Room-level summary counts
  room_count       INT NOT NULL DEFAULT 0,
  dead_zone_count  INT NOT NULL DEFAULT 0,

  -- Speed deficit vs plan (computed on upload for fast queries)
  download_deficit_pct DOUBLE PRECISION GENERATED ALWAYS AS (
    CASE WHEN isp_promised_download_mbps > 0
         THEN ((isp_promised_download_mbps - measured_download_mbps) / isp_promised_download_mbps) * 100
         ELSE 0 END
  ) STORED,

  upload_deficit_pct DOUBLE PRECISION GENERATED ALWAYS AS (
    CASE WHEN isp_promised_upload_mbps > 0
         THEN ((isp_promised_upload_mbps - measured_upload_mbps) / isp_promised_upload_mbps) * 100
         ELSE 0 END
  ) STORED
);

-- Per-room metrics within a scan session.
-- Enables room-type analytics (e.g. "kitchens average 12% weaker signal than living rooms").
CREATE TABLE room_scans (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id      UUID NOT NULL REFERENCES scan_sessions(id) ON DELETE CASCADE,

  room_type       room_type NOT NULL,
  floor_index     INT NOT NULL DEFAULT 0,

  -- Speed test for this room
  download_mbps   DOUBLE PRECISION NOT NULL DEFAULT 0,
  upload_mbps     DOUBLE PRECISION NOT NULL DEFAULT 0,
  ping_ms         DOUBLE PRECISION NOT NULL DEFAULT 0,

  -- Signal stats (aggregated from heatmap points)
  avg_signal_dbm        INT NOT NULL DEFAULT -70,
  min_signal_dbm        INT NOT NULL DEFAULT -90,
  max_signal_dbm        INT NOT NULL DEFAULT -40,
  signal_std_dev        DOUBLE PRECISION NOT NULL DEFAULT 0,
  point_count           INT NOT NULL DEFAULT 0,

  -- Coverage breakdown for this room
  coverage_strong_pct   DOUBLE PRECISION NOT NULL DEFAULT 0,
  coverage_moderate_pct DOUBLE PRECISION NOT NULL DEFAULT 0,
  coverage_weak_pct     DOUBLE PRECISION NOT NULL DEFAULT 0,

  -- Area
  area_sq_meters  FLOAT NOT NULL DEFAULT 0,

  -- Grading
  grade_letter    grade_letter NOT NULL DEFAULT 'C',
  grade_score     DOUBLE PRECISION NOT NULL DEFAULT 50,

  -- Dead zones in this room
  dead_zone_count INT NOT NULL DEFAULT 0,

  -- Device placement counts
  router_count    INT NOT NULL DEFAULT 0,
  mesh_node_count INT NOT NULL DEFAULT 0,
  device_count    INT NOT NULL DEFAULT 0   -- non-network devices (TV, computer, etc.)
);

-- Dead zone details for pattern analysis.
-- Helps answer: "What room types have the most dead zones?"
CREATE TABLE dead_zones (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id      UUID NOT NULL REFERENCES scan_sessions(id) ON DELETE CASCADE,
  room_scan_id    UUID NOT NULL REFERENCES room_scans(id) ON DELETE CASCADE,

  severity        dead_zone_severity NOT NULL,
  radius_meters   FLOAT NOT NULL,

  -- Relative position within the room (0-1 normalized, not absolute coords)
  relative_x      FLOAT NOT NULL,    -- 0 = left wall, 1 = right wall
  relative_z      FLOAT NOT NULL,    -- 0 = front wall, 1 = back wall

  -- Was a device (TV, computer) found near this dead zone?
  has_device_nearby BOOLEAN NOT NULL DEFAULT false,
  nearby_device_type device_type
);

-- =============================================================================
-- ISP PERFORMANCE MATERIALIZED VIEWS
-- These power the "ISP Report Card" feature and data sales to ISPs.
-- =============================================================================

-- ISP performance by ZIP code — the core sellable dataset.
CREATE MATERIALIZED VIEW isp_performance_by_zip AS
SELECT
  isp_name,
  zip_code,
  state_code,
  COUNT(*)                                          AS scan_count,
  ROUND(AVG(measured_download_mbps)::numeric, 1)    AS avg_download_mbps,
  ROUND(AVG(measured_upload_mbps)::numeric, 1)      AS avg_upload_mbps,
  ROUND(AVG(measured_latency_ms)::numeric, 1)       AS avg_latency_ms,
  ROUND(AVG(download_deficit_pct)::numeric, 1)      AS avg_download_deficit_pct,
  ROUND(AVG(overall_score)::numeric, 1)             AS avg_score,
  ROUND(AVG(coverage_strong_pct)::numeric, 1)       AS avg_strong_coverage_pct,
  ROUND(AVG(dead_zone_count)::numeric, 1)           AS avg_dead_zones,
  MODE() WITHIN GROUP (ORDER BY overall_grade)      AS most_common_grade,
  MIN(uploaded_at)                                  AS first_scan,
  MAX(uploaded_at)                                  AS last_scan
FROM scan_sessions
GROUP BY isp_name, zip_code, state_code
WITH DATA;

CREATE UNIQUE INDEX idx_isp_perf_zip ON isp_performance_by_zip (isp_name, zip_code);

-- ISP performance by state — for regional reports.
CREATE MATERIALIZED VIEW isp_performance_by_state AS
SELECT
  isp_name,
  state_code,
  COUNT(*)                                          AS scan_count,
  ROUND(AVG(measured_download_mbps)::numeric, 1)    AS avg_download_mbps,
  ROUND(AVG(measured_upload_mbps)::numeric, 1)      AS avg_upload_mbps,
  ROUND(AVG(measured_latency_ms)::numeric, 1)       AS avg_latency_ms,
  ROUND(AVG(download_deficit_pct)::numeric, 1)      AS avg_download_deficit_pct,
  ROUND(AVG(overall_score)::numeric, 1)             AS avg_score,
  MODE() WITHIN GROUP (ORDER BY overall_grade)      AS most_common_grade
FROM scan_sessions
WHERE state_code IS NOT NULL
GROUP BY isp_name, state_code
WITH DATA;

CREATE UNIQUE INDEX idx_isp_perf_state ON isp_performance_by_state (isp_name, state_code);

-- Dead zone prevalence by dwelling type — for property managers.
CREATE MATERIALIZED VIEW dead_zone_stats_by_dwelling AS
SELECT
  dwelling_type,
  zip_code,
  COUNT(*)                                          AS scan_count,
  ROUND(AVG(dead_zone_count)::numeric, 1)           AS avg_dead_zones,
  ROUND(AVG(overall_score)::numeric, 1)             AS avg_score,
  ROUND(AVG(coverage_weak_pct)::numeric, 1)         AS avg_weak_coverage_pct,
  ROUND(AVG(square_footage)::numeric, 0)            AS avg_sq_ft
FROM scan_sessions
GROUP BY dwelling_type, zip_code
WITH DATA;

CREATE UNIQUE INDEX idx_dz_dwelling_zip ON dead_zone_stats_by_dwelling (dwelling_type, zip_code);

-- Room type performance — which rooms have the worst WiFi?
CREATE MATERIALIZED VIEW room_type_performance AS
SELECT
  rs.room_type,
  ss.dwelling_type,
  COUNT(*)                                          AS room_count,
  ROUND(AVG(rs.avg_signal_dbm)::numeric, 0)        AS avg_signal_dbm,
  ROUND(AVG(rs.download_mbps)::numeric, 1)          AS avg_download_mbps,
  ROUND(AVG(rs.coverage_weak_pct)::numeric, 1)      AS avg_weak_coverage_pct,
  ROUND(AVG(rs.dead_zone_count)::numeric, 1)        AS avg_dead_zones,
  ROUND(AVG(rs.grade_score)::numeric, 1)            AS avg_grade_score
FROM room_scans rs
JOIN scan_sessions ss ON rs.session_id = ss.id
GROUP BY rs.room_type, ss.dwelling_type
WITH DATA;

CREATE UNIQUE INDEX idx_room_type_perf ON room_type_performance (room_type, dwelling_type);

-- =============================================================================
-- AD / RECOMMENDATION SYSTEM
-- =============================================================================

-- Partners who pay for placement (ISPs, mesh hardware companies, etc.)
CREATE TABLE ad_partners (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  name            TEXT NOT NULL,              -- "Xfinity", "eero", "TP-Link"
  partner_type    ad_placement_type NOT NULL, -- isp, mesh_hardware, router, etc.
  logo_url        TEXT,
  website_url     TEXT,
  contact_email   TEXT,

  is_active       BOOLEAN NOT NULL DEFAULT true
);

-- Individual ad campaigns / placements.
CREATE TABLE ad_placements (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  partner_id      UUID NOT NULL REFERENCES ad_partners(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Targeting
  target_zip_codes   TEXT[] NOT NULL DEFAULT '{}',     -- Empty = nationwide
  target_states      TEXT[] NOT NULL DEFAULT '{}',     -- Empty = all states
  target_dwelling_types dwelling_type[] NOT NULL DEFAULT '{}', -- Empty = all

  -- When to show this ad
  trigger_condition  JSONB NOT NULL DEFAULT '{}',
  -- Examples:
  -- {"min_dead_zones": 2}                     — show when user has 2+ dead zones
  -- {"max_download_pct": 50}                  — show when getting < 50% of plan speed
  -- {"min_weak_coverage_pct": 30}             — show when > 30% weak coverage
  -- {"isp_name": "Comcast"}                   — show to Comcast users specifically

  -- Ad content
  headline        TEXT NOT NULL,              -- "Upgrade to Xfinity Gigabit"
  body_text       TEXT NOT NULL,              -- "Get 1000 Mbps for $49.99/mo"
  cta_text        TEXT NOT NULL DEFAULT 'Learn More',
  cta_url         TEXT NOT NULL,              -- Affiliate/tracking link
  discount_code   TEXT,                       -- Optional promo code
  badge_text      TEXT,                       -- "FullBars Recommended" or "Partner Deal"

  -- Budget & scheduling
  daily_impression_cap  INT,                  -- NULL = unlimited
  total_impression_cap  INT,                  -- NULL = unlimited
  start_date      DATE,                       -- NULL = start immediately
  end_date        DATE,                       -- NULL = run indefinitely
  cost_per_impression   DOUBLE PRECISION DEFAULT 0,
  cost_per_click        DOUBLE PRECISION DEFAULT 0,

  is_active       BOOLEAN NOT NULL DEFAULT true,
  is_house_ad     BOOLEAN NOT NULL DEFAULT false  -- FullBars-created demo ads
);

-- Track impressions (ad shown to user in recommendations).
CREATE TABLE ad_impressions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  placement_id    UUID NOT NULL REFERENCES ad_placements(id) ON DELETE CASCADE,
  session_id      UUID REFERENCES scan_sessions(id) ON DELETE SET NULL,
  impression_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Context when shown
  zip_code        TEXT NOT NULL,
  isp_name        TEXT,
  dead_zone_count INT DEFAULT 0,
  overall_grade   grade_letter,

  -- Device fingerprint (anonymous, for dedup only)
  device_hash     TEXT NOT NULL   -- SHA256 of vendor ID, rotated monthly
);

-- Track clicks (user tapped the CTA).
CREATE TABLE ad_clicks (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  impression_id   UUID NOT NULL REFERENCES ad_impressions(id) ON DELETE CASCADE,
  clicked_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- For conversion tracking
  device_hash     TEXT NOT NULL
);

-- =============================================================================
-- INDEXES FOR COMMON QUERY PATTERNS
-- =============================================================================

-- Fast lookups by ZIP code (ISP comparison dashboards)
CREATE INDEX idx_sessions_zip ON scan_sessions (zip_code);
CREATE INDEX idx_sessions_isp ON scan_sessions (isp_name);
CREATE INDEX idx_sessions_isp_zip ON scan_sessions (isp_name, zip_code);
CREATE INDEX idx_sessions_uploaded ON scan_sessions (uploaded_at DESC);
CREATE INDEX idx_sessions_grade ON scan_sessions (overall_grade);
CREATE INDEX idx_sessions_dwelling ON scan_sessions (dwelling_type, zip_code);

-- Room scan lookups
CREATE INDEX idx_room_scans_session ON room_scans (session_id);
CREATE INDEX idx_room_scans_type ON room_scans (room_type);

-- Dead zone lookups
CREATE INDEX idx_dead_zones_session ON dead_zones (session_id);
CREATE INDEX idx_dead_zones_severity ON dead_zones (severity);

-- Ad system indexes
CREATE INDEX idx_placements_partner ON ad_placements (partner_id);
CREATE INDEX idx_placements_active ON ad_placements (is_active) WHERE is_active = true;
CREATE INDEX idx_impressions_placement ON ad_impressions (placement_id);
CREATE INDEX idx_impressions_date ON ad_impressions (impression_at DESC);
CREATE INDEX idx_impressions_zip ON ad_impressions (zip_code);
CREATE INDEX idx_clicks_impression ON ad_clicks (impression_id);

-- GIN index for array-based ZIP targeting on ads
CREATE INDEX idx_placements_target_zips ON ad_placements USING GIN (target_zip_codes);
CREATE INDEX idx_placements_trigger ON ad_placements USING GIN (trigger_condition);

-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================================
-- Analytics data is insert-only from the app. Only the dashboard reads it.

ALTER TABLE scan_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE dead_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE ad_impressions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ad_clicks ENABLE ROW LEVEL SECURITY;

-- Anon key (iOS app): can INSERT analytics, nothing else
CREATE POLICY "App can insert sessions"  ON scan_sessions  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "App can insert rooms"     ON room_scans     FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "App can insert dead_zones" ON dead_zones    FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "App can insert impressions" ON ad_impressions FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "App can insert clicks"    ON ad_clicks      FOR INSERT TO anon WITH CHECK (true);

-- App can also read ad placements (to show recommendations)
ALTER TABLE ad_placements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "App can read active ads"  ON ad_placements  FOR SELECT TO anon
  USING (is_active = true AND (start_date IS NULL OR start_date <= CURRENT_DATE)
         AND (end_date IS NULL OR end_date >= CURRENT_DATE));

ALTER TABLE ad_partners ENABLE ROW LEVEL SECURITY;
CREATE POLICY "App can read active partners" ON ad_partners FOR SELECT TO anon
  USING (is_active = true);

-- Service role (dashboard): full access — used by Vercel API routes
-- (service_role key is never exposed to the client)

-- =============================================================================
-- REFRESH FUNCTION FOR MATERIALIZED VIEWS
-- =============================================================================
CREATE OR REPLACE FUNCTION refresh_analytics_views()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY isp_performance_by_zip;
  REFRESH MATERIALIZED VIEW CONCURRENTLY isp_performance_by_state;
  REFRESH MATERIALIZED VIEW CONCURRENTLY dead_zone_stats_by_dwelling;
  REFRESH MATERIALIZED VIEW CONCURRENTLY room_type_performance;
END;
$$ LANGUAGE plpgsql;

-- Schedule via pg_cron (or Supabase cron): every 6 hours
-- SELECT cron.schedule('refresh-analytics', '0 */6 * * *', 'SELECT refresh_analytics_views()');

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Get ISP ranking for a ZIP code
CREATE OR REPLACE FUNCTION get_isp_rankings(p_zip TEXT)
RETURNS TABLE (
  rank       BIGINT,
  isp_name   TEXT,
  avg_score  NUMERIC,
  avg_download NUMERIC,
  scan_count BIGINT,
  grade      grade_letter
) AS $$
  SELECT
    ROW_NUMBER() OVER (ORDER BY avg_score DESC),
    isp_name,
    avg_score,
    avg_download_mbps,
    scan_count,
    most_common_grade
  FROM isp_performance_by_zip
  WHERE zip_code = p_zip
    AND scan_count >= 3  -- minimum sample size
  ORDER BY avg_score DESC;
$$ LANGUAGE sql STABLE;

-- Match ad placements for a user's context
CREATE OR REPLACE FUNCTION match_ads(
  p_zip TEXT,
  p_isp TEXT,
  p_dwelling dwelling_type,
  p_dead_zones INT,
  p_download_pct DOUBLE PRECISION,
  p_weak_coverage_pct DOUBLE PRECISION
)
RETURNS SETOF ad_placements AS $$
  SELECT ap.*
  FROM ad_placements ap
  WHERE ap.is_active = true
    AND (ap.start_date IS NULL OR ap.start_date <= CURRENT_DATE)
    AND (ap.end_date IS NULL OR ap.end_date >= CURRENT_DATE)
    AND (ap.target_zip_codes = '{}' OR p_zip = ANY(ap.target_zip_codes))
    AND (ap.target_states = '{}' OR (
      SELECT state_code FROM scan_sessions WHERE zip_code = p_zip LIMIT 1
    ) = ANY(ap.target_states))
    AND (ap.target_dwelling_types = '{}' OR p_dwelling = ANY(ap.target_dwelling_types))
    AND (
      ap.trigger_condition = '{}'
      OR (
        (ap.trigger_condition->>'min_dead_zones' IS NULL OR p_dead_zones >= (ap.trigger_condition->>'min_dead_zones')::int)
        AND (ap.trigger_condition->>'max_download_pct' IS NULL OR p_download_pct <= (ap.trigger_condition->>'max_download_pct')::float)
        AND (ap.trigger_condition->>'min_weak_coverage_pct' IS NULL OR p_weak_coverage_pct >= (ap.trigger_condition->>'min_weak_coverage_pct')::float)
        AND (ap.trigger_condition->>'isp_name' IS NULL OR LOWER(p_isp) = LOWER(ap.trigger_condition->>'isp_name'))
      )
    )
    AND (ap.total_impression_cap IS NULL OR (
      SELECT COUNT(*) FROM ad_impressions ai WHERE ai.placement_id = ap.id
    ) < ap.total_impression_cap)
  ORDER BY
    CASE WHEN ap.is_house_ad THEN 1 ELSE 0 END,  -- Paid ads first
    random()  -- Randomize within tier
  LIMIT 3;
$$ LANGUAGE sql STABLE;
