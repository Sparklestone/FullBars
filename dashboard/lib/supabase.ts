import { createClient } from "@supabase/supabase-js";

// Server-side client with service role key (full access)
export function createServiceClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );
}

// Types matching our Supabase schema
export interface ScanSession {
  id: string;
  uploaded_at: string;
  zip_code: string;
  state_code: string | null;
  dwelling_type: string;
  square_footage: number;
  floor_count: number;
  isp_name: string;
  isp_promised_download_mbps: number;
  measured_download_mbps: number;
  measured_upload_mbps: number;
  measured_latency_ms: number;
  coverage_strong_pct: number;
  coverage_moderate_pct: number;
  coverage_weak_pct: number;
  has_mesh_network: boolean;
  overall_grade: string;
  overall_score: number;
  room_count: number;
  dead_zone_count: number;
  download_deficit_pct: number;
}

export interface AdPartner {
  id: string;
  name: string;
  partner_type: string;
  logo_url: string | null;
  website_url: string | null;
  contact_email: string | null;
  is_active: boolean;
  created_at: string;
}

export interface AdPlacement {
  id: string;
  partner_id: string;
  target_zip_codes: string[];
  target_states: string[];
  target_dwelling_types: string[];
  trigger_condition: Record<string, unknown>;
  headline: string;
  body_text: string;
  cta_text: string;
  cta_url: string;
  discount_code: string | null;
  badge_text: string | null;
  daily_impression_cap: number | null;
  total_impression_cap: number | null;
  start_date: string | null;
  end_date: string | null;
  cost_per_impression: number;
  cost_per_click: number;
  is_active: boolean;
  is_house_ad: boolean;
  created_at: string;
}

export interface ISPPerformance {
  isp_name: string;
  zip_code: string;
  scan_count: number;
  avg_download_mbps: number;
  avg_upload_mbps: number;
  avg_latency_ms: number;
  avg_download_deficit_pct: number;
  avg_score: number;
  avg_strong_coverage_pct: number;
  avg_dead_zones: number;
  most_common_grade: string;
}

export interface AdImpression {
  id: string;
  placement_id: string;
  impression_at: string;
  zip_code: string;
  isp_name: string | null;
}

export interface AdClick {
  id: string;
  impression_id: string;
  clicked_at: string;
}
