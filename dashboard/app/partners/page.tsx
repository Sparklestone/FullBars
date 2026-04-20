import { createServiceClient } from "@/lib/supabase";

async function getPartners() {
  const supabase = createServiceClient();
  const { data } = await supabase
    .from("ad_partners")
    .select("*, ad_placements(id, is_active)")
    .order("name");
  return data ?? [];
}

export default async function PartnersPage() {
  let partners: any[] = [];
  try {
    partners = await getPartners();
  } catch {
    // Supabase not configured
  }

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white">Partners</h2>
          <p className="text-gray-500 mt-1">
            ISPs, mesh hardware companies, and other ad partners
          </p>
        </div>
        <button className="px-4 py-2 bg-cyan-500 text-white text-sm font-semibold rounded-lg hover:bg-cyan-600 transition">
          + Add Partner
        </button>
      </div>

      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        {partners.length === 0 ? (
          <div className="col-span-full bg-[#111827] border border-gray-800 rounded-xl p-12 text-center">
            <p className="text-gray-500">No partners yet.</p>
            <p className="text-gray-600 text-sm mt-1">
              Add your first partner to start creating ad placements.
            </p>
          </div>
        ) : (
          partners.map((partner: any) => {
            const activePlacements =
              partner.ad_placements?.filter((p: any) => p.is_active).length ?? 0;
            const totalPlacements = partner.ad_placements?.length ?? 0;

            return (
              <div
                key={partner.id}
                className="bg-[#111827] border border-gray-800 rounded-xl p-5 hover:border-gray-700 transition"
              >
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <h3 className="text-white font-semibold">{partner.name}</h3>
                    <span className="text-xs text-gray-500">
                      {formatType(partner.partner_type)}
                    </span>
                  </div>
                  <span
                    className={`text-xs px-2 py-0.5 rounded ${
                      partner.is_active
                        ? "bg-green-500/20 text-green-400"
                        : "bg-gray-500/20 text-gray-400"
                    }`}
                  >
                    {partner.is_active ? "Active" : "Inactive"}
                  </span>
                </div>

                <div className="flex gap-4 text-xs text-gray-400 mt-4">
                  <span>{totalPlacements} placements</span>
                  <span>{activePlacements} active</span>
                </div>

                {partner.website_url && (
                  <a
                    href={partner.website_url}
                    target="_blank"
                    rel="noopener"
                    className="text-xs text-cyan-400 mt-3 inline-block hover:underline"
                  >
                    {partner.website_url}
                  </a>
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}

function formatType(type: string) {
  const labels: Record<string, string> = {
    isp: "Internet Service Provider",
    mesh_hardware: "Mesh Hardware",
    router: "Router Manufacturer",
    extender: "Range Extender",
    general: "General",
  };
  return labels[type] ?? type;
}
