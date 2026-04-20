import { createServiceClient } from "@/lib/supabase";
import type { AdPlacement } from "@/lib/supabase";

async function getPlacements() {
  const supabase = createServiceClient();
  const { data } = await supabase
    .from("ad_placements")
    .select("*, ad_partners(name, partner_type)")
    .order("created_at", { ascending: false });
  return (data ?? []) as (AdPlacement & {
    ad_partners: { name: string; partner_type: string };
  })[];
}

async function getPlacementStats() {
  const supabase = createServiceClient();
  const { data: impressions } = await supabase
    .from("ad_impressions")
    .select("placement_id");
  const { data: clicks } = await supabase
    .from("ad_clicks")
    .select("impression_id, ad_impressions(placement_id)")
    .limit(10000);

  // Group by placement
  const impByPlacement: Record<string, number> = {};
  const clickByPlacement: Record<string, number> = {};

  (impressions ?? []).forEach((imp: any) => {
    impByPlacement[imp.placement_id] =
      (impByPlacement[imp.placement_id] ?? 0) + 1;
  });

  (clicks ?? []).forEach((click: any) => {
    const pid = click.ad_impressions?.placement_id;
    if (pid) clickByPlacement[pid] = (clickByPlacement[pid] ?? 0) + 1;
  });

  return { impByPlacement, clickByPlacement };
}

export default async function AdsPage() {
  let placements: any[] = [];
  let stats = { impByPlacement: {} as any, clickByPlacement: {} as any };

  try {
    [placements, stats] = await Promise.all([
      getPlacements(),
      getPlacementStats(),
    ]);
  } catch {
    // Supabase not configured
  }

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white">Ad Placements</h2>
          <p className="text-gray-500 mt-1">
            Manage solution-based recommendations by area code
          </p>
        </div>
        <a
          href="/ads/new"
          className="px-4 py-2 bg-cyan-500 text-white text-sm font-semibold rounded-lg hover:bg-cyan-600 transition"
        >
          + New Placement
        </a>
      </div>

      {/* Filter Bar */}
      <div className="flex gap-3">
        <FilterPill label="All" active />
        <FilterPill label="Active" />
        <FilterPill label="House Ads" />
        <FilterPill label="ISP" />
        <FilterPill label="Mesh Hardware" />
      </div>

      {/* Placements Table */}
      <div className="bg-[#111827] border border-gray-800 rounded-xl overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-gray-800 text-left">
              <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">
                Placement
              </th>
              <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">
                Partner
              </th>
              <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">
                Targeting
              </th>
              <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">
                Impressions
              </th>
              <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">
                Clicks
              </th>
              <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">
                CTR
              </th>
              <th className="px-6 py-3 text-xs font-medium text-gray-500 uppercase">
                Status
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-800">
            {placements.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-6 py-12 text-center">
                  <p className="text-gray-500">No placements yet.</p>
                  <p className="text-gray-600 text-sm mt-1">
                    Create your first ad placement to start showing
                    recommendations to users.
                  </p>
                </td>
              </tr>
            ) : (
              placements.map((p: any) => {
                const imps = stats.impByPlacement[p.id] ?? 0;
                const clicks = stats.clickByPlacement[p.id] ?? 0;
                const ctr = imps > 0 ? ((clicks / imps) * 100).toFixed(1) : "—";
                const zipCount = p.target_zip_codes?.length ?? 0;
                const targeting =
                  zipCount === 0
                    ? "Nationwide"
                    : `${zipCount} ZIP${zipCount !== 1 ? "s" : ""}`;

                return (
                  <tr
                    key={p.id}
                    className="hover:bg-gray-800/50 transition"
                  >
                    <td className="px-6 py-4">
                      <div>
                        <p className="text-sm text-white font-medium">
                          {p.headline}
                        </p>
                        <p className="text-xs text-gray-500 mt-0.5 max-w-xs truncate">
                          {p.body_text}
                        </p>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className="text-sm text-gray-300">
                        {p.ad_partners?.name ?? "—"}
                      </span>
                      <span className="text-xs text-gray-600 ml-2">
                        {p.ad_partners?.partner_type}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <span className="text-xs text-gray-400">{targeting}</span>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-300">
                      {imps.toLocaleString()}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-300">
                      {clicks.toLocaleString()}
                    </td>
                    <td className="px-6 py-4 text-sm text-cyan-400 font-mono">
                      {ctr}%
                    </td>
                    <td className="px-6 py-4">
                      <StatusBadge
                        active={p.is_active}
                        houseAd={p.is_house_ad}
                      />
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function FilterPill({ label, active }: { label: string; active?: boolean }) {
  return (
    <button
      className={`px-3 py-1.5 text-xs font-medium rounded-full border transition ${
        active
          ? "bg-cyan-500/10 border-cyan-500/30 text-cyan-400"
          : "border-gray-700 text-gray-500 hover:text-gray-300"
      }`}
    >
      {label}
    </button>
  );
}

function StatusBadge({
  active,
  houseAd,
}: {
  active: boolean;
  houseAd: boolean;
}) {
  if (houseAd) {
    return (
      <span className="text-xs font-medium px-2 py-0.5 rounded bg-purple-500/20 text-purple-400">
        House Ad
      </span>
    );
  }
  return (
    <span
      className={`text-xs font-medium px-2 py-0.5 rounded ${
        active
          ? "bg-green-500/20 text-green-400"
          : "bg-gray-500/20 text-gray-400"
      }`}
    >
      {active ? "Active" : "Paused"}
    </span>
  );
}
