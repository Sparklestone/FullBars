import { createServiceClient } from "@/lib/supabase";

async function getOverviewStats() {
  const supabase = createServiceClient();

  const [sessionsRes, partnersRes, placementsRes, impressionsRes, clicksRes] =
    await Promise.all([
      supabase
        .from("scan_sessions")
        .select("id", { count: "exact", head: true }),
      supabase
        .from("ad_partners")
        .select("id", { count: "exact", head: true })
        .eq("is_active", true),
      supabase
        .from("ad_placements")
        .select("id", { count: "exact", head: true })
        .eq("is_active", true),
      supabase
        .from("ad_impressions")
        .select("id", { count: "exact", head: true }),
      supabase.from("ad_clicks").select("id", { count: "exact", head: true }),
    ]);

  const totalScans = sessionsRes.count ?? 0;
  const activePartners = partnersRes.count ?? 0;
  const activePlacements = placementsRes.count ?? 0;
  const totalImpressions = impressionsRes.count ?? 0;
  const totalClicks = clicksRes.count ?? 0;
  const ctr =
    totalImpressions > 0
      ? ((totalClicks / totalImpressions) * 100).toFixed(1)
      : "0.0";

  return {
    totalScans,
    activePartners,
    activePlacements,
    totalImpressions,
    totalClicks,
    ctr,
  };
}

async function getRecentScans() {
  const supabase = createServiceClient();
  const { data } = await supabase
    .from("scan_sessions")
    .select(
      "id, uploaded_at, zip_code, isp_name, measured_download_mbps, overall_grade, overall_score, dead_zone_count"
    )
    .order("uploaded_at", { ascending: false })
    .limit(10);
  return data ?? [];
}

async function getTopISPs() {
  const supabase = createServiceClient();
  const { data } = await supabase
    .from("isp_performance_by_state")
    .select("*")
    .order("scan_count", { ascending: false })
    .limit(10);
  return data ?? [];
}

export default async function DashboardPage() {
  let stats, recentScans, topISPs;
  try {
    [stats, recentScans, topISPs] = await Promise.all([
      getOverviewStats(),
      getRecentScans(),
      getTopISPs(),
    ]);
  } catch {
    // Supabase not configured yet — show placeholder
    stats = {
      totalScans: 0,
      activePartners: 0,
      activePlacements: 0,
      totalImpressions: 0,
      totalClicks: 0,
      ctr: "0.0",
    };
    recentScans = [];
    topISPs = [];
  }

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-2xl font-bold text-white">Dashboard</h2>
        <p className="text-gray-500 mt-1">
          FullBars analytics and ad management overview
        </p>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <StatCard label="Total Scans" value={stats.totalScans.toLocaleString()} />
        <StatCard label="Active Partners" value={String(stats.activePartners)} />
        <StatCard label="Active Ads" value={String(stats.activePlacements)} />
        <StatCard
          label="Impressions"
          value={stats.totalImpressions.toLocaleString()}
        />
        <StatCard label="Clicks" value={stats.totalClicks.toLocaleString()} />
        <StatCard label="CTR" value={`${stats.ctr}%`} accent />
      </div>

      <div className="grid lg:grid-cols-2 gap-6">
        {/* Recent Scans */}
        <div className="bg-[#111827] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            Recent Scans
          </h3>
          {recentScans.length === 0 ? (
            <p className="text-gray-500 text-sm">
              No scans yet. Data will appear once users start scanning.
            </p>
          ) : (
            <div className="space-y-3">
              {recentScans.map((scan: any) => (
                <div
                  key={scan.id}
                  className="flex items-center justify-between py-2 border-b border-gray-800 last:border-0"
                >
                  <div>
                    <span className="text-sm text-white">{scan.isp_name}</span>
                    <span className="text-xs text-gray-500 ml-2">
                      {scan.zip_code}
                    </span>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-gray-400">
                      {Math.round(scan.measured_download_mbps)} Mbps
                    </span>
                    <GradeBadge grade={scan.overall_grade} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Top ISPs */}
        <div className="bg-[#111827] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            ISP Performance
          </h3>
          {topISPs.length === 0 ? (
            <p className="text-gray-500 text-sm">
              ISP rankings will populate as scan data comes in.
            </p>
          ) : (
            <div className="space-y-3">
              {topISPs.map((isp: any, i: number) => (
                <div
                  key={`${isp.isp_name}-${isp.state_code}`}
                  className="flex items-center justify-between py-2 border-b border-gray-800 last:border-0"
                >
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-gray-500 w-5">
                      #{i + 1}
                    </span>
                    <span className="text-sm text-white">{isp.isp_name}</span>
                    {isp.state_code && (
                      <span className="text-xs text-gray-500">
                        {isp.state_code}
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-xs text-gray-400">
                      {isp.avg_download_mbps} Mbps avg
                    </span>
                    <span className="text-xs text-cyan-400">
                      {isp.scan_count} scans
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent?: boolean;
}) {
  return (
    <div className="bg-[#111827] border border-gray-800 rounded-xl p-4">
      <p className="text-xs text-gray-500 mb-1">{label}</p>
      <p
        className={`text-2xl font-bold ${accent ? "text-cyan-400" : "text-white"}`}
      >
        {value}
      </p>
    </div>
  );
}

function GradeBadge({ grade }: { grade: string }) {
  const colors: Record<string, string> = {
    a: "bg-green-500/20 text-green-400",
    b: "bg-cyan-500/20 text-cyan-400",
    c: "bg-yellow-500/20 text-yellow-400",
    d: "bg-orange-500/20 text-orange-400",
    f: "bg-red-500/20 text-red-400",
  };
  return (
    <span
      className={`text-xs font-bold px-2 py-0.5 rounded ${colors[grade?.toLowerCase()] ?? "bg-gray-500/20 text-gray-400"}`}
    >
      {grade?.toUpperCase()}
    </span>
  );
}
