import { createServiceClient } from "@/lib/supabase";

async function getAnalyticsSummary() {
  const supabase = createServiceClient();

  const [sessionsRes, gradeRes, ispRes] = await Promise.all([
    supabase
      .from("scan_sessions")
      .select("overall_score, measured_download_mbps, dead_zone_count")
      .limit(1000),
    supabase
      .from("scan_sessions")
      .select("overall_grade")
      .limit(10000),
    supabase
      .from("isp_performance_by_zip")
      .select("*")
      .order("scan_count", { ascending: false })
      .limit(20),
  ]);

  const sessions = sessionsRes.data ?? [];
  const grades = gradeRes.data ?? [];
  const topISPs = ispRes.data ?? [];

  // Grade distribution
  const gradeCounts: Record<string, number> = { a: 0, b: 0, c: 0, d: 0, f: 0 };
  grades.forEach((g: any) => {
    const key = g.overall_grade?.toLowerCase();
    if (key && gradeCounts[key] !== undefined) gradeCounts[key]++;
  });

  // Averages
  const avgScore =
    sessions.length > 0
      ? sessions.reduce((s: number, r: any) => s + r.overall_score, 0) /
        sessions.length
      : 0;
  const avgDownload =
    sessions.length > 0
      ? sessions.reduce(
          (s: number, r: any) => s + r.measured_download_mbps,
          0
        ) / sessions.length
      : 0;
  const avgDeadZones =
    sessions.length > 0
      ? sessions.reduce((s: number, r: any) => s + r.dead_zone_count, 0) /
        sessions.length
      : 0;

  return { gradeCounts, avgScore, avgDownload, avgDeadZones, topISPs, totalScans: grades.length };
}

export default async function AnalyticsPage() {
  let analytics;
  try {
    analytics = await getAnalyticsSummary();
  } catch {
    analytics = {
      gradeCounts: { a: 0, b: 0, c: 0, d: 0, f: 0 },
      avgScore: 0,
      avgDownload: 0,
      avgDeadZones: 0,
      topISPs: [],
      totalScans: 0,
    };
  }

  const gradeColors: Record<string, string> = {
    a: "bg-green-500",
    b: "bg-cyan-500",
    c: "bg-yellow-500",
    d: "bg-orange-500",
    f: "bg-red-500",
  };

  const totalGrades = Object.values(analytics.gradeCounts).reduce(
    (a, b) => a + b,
    0
  );

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white">Analytics</h2>
          <p className="text-gray-500 mt-1">
            Aggregated scan data across all users —{" "}
            {analytics.totalScans.toLocaleString()} total scans
          </p>
        </div>
        <form action="/api/analytics" method="POST">
          <button
            type="submit"
            className="px-4 py-2 bg-gray-800 text-gray-300 text-sm rounded-lg hover:bg-gray-700 transition border border-gray-700"
          >
            Refresh Views
          </button>
        </form>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <SummaryCard
          label="Average Score"
          value={analytics.avgScore.toFixed(0)}
          suffix="/100"
        />
        <SummaryCard
          label="Avg Download"
          value={analytics.avgDownload.toFixed(0)}
          suffix="Mbps"
        />
        <SummaryCard
          label="Avg Dead Zones"
          value={analytics.avgDeadZones.toFixed(1)}
          suffix="per home"
        />
        <SummaryCard
          label="Total Scans"
          value={analytics.totalScans.toLocaleString()}
        />
      </div>

      <div className="grid lg:grid-cols-2 gap-6">
        {/* Grade Distribution */}
        <div className="bg-[#111827] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-6">
            Grade Distribution
          </h3>
          {totalGrades === 0 ? (
            <p className="text-gray-500 text-sm">No data yet.</p>
          ) : (
            <div className="space-y-3">
              {Object.entries(analytics.gradeCounts).map(([grade, count]) => {
                const pct = totalGrades > 0 ? (count / totalGrades) * 100 : 0;
                return (
                  <div key={grade} className="flex items-center gap-3">
                    <span className="text-sm font-bold text-white w-6 text-center">
                      {grade.toUpperCase()}
                    </span>
                    <div className="flex-1 bg-gray-800 rounded-full h-4 overflow-hidden">
                      <div
                        className={`h-full rounded-full ${gradeColors[grade]}`}
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                    <span className="text-xs text-gray-400 w-16 text-right">
                      {count} ({pct.toFixed(0)}%)
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Top ISPs by Scan Volume */}
        <div className="bg-[#111827] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            Top ISPs by Volume
          </h3>
          {analytics.topISPs.length === 0 ? (
            <p className="text-gray-500 text-sm">No ISP data yet.</p>
          ) : (
            <div className="space-y-3">
              {analytics.topISPs.map((isp: any, i: number) => (
                <div
                  key={`${isp.isp_name}-${isp.zip_code}`}
                  className="flex items-center justify-between py-2 border-b border-gray-800 last:border-0"
                >
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-gray-600 w-5">#{i + 1}</span>
                    <div>
                      <span className="text-sm text-white">
                        {isp.isp_name}
                      </span>
                      <span className="text-xs text-gray-500 ml-2">
                        {isp.zip_code}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-4 text-xs">
                    <span className="text-gray-400">
                      {isp.avg_download_mbps} Mbps
                    </span>
                    <span className="text-cyan-400">
                      Score: {isp.avg_score}
                    </span>
                    <span className="text-gray-500">
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

function SummaryCard({
  label,
  value,
  suffix,
}: {
  label: string;
  value: string;
  suffix?: string;
}) {
  return (
    <div className="bg-[#111827] border border-gray-800 rounded-xl p-5">
      <p className="text-xs text-gray-500 mb-2">{label}</p>
      <div className="flex items-baseline gap-1">
        <span className="text-3xl font-bold text-white">{value}</span>
        {suffix && (
          <span className="text-sm text-gray-500">{suffix}</span>
        )}
      </div>
    </div>
  );
}
