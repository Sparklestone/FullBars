import { NextRequest, NextResponse } from "next/server";
import { createServiceClient } from "@/lib/supabase";

// GET /api/analytics?zip=10001&isp=Comcast
export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const zip = searchParams.get("zip");
  const isp = searchParams.get("isp");
  const view = searchParams.get("view") ?? "overview";

  const supabase = createServiceClient();

  if (view === "isp_by_zip" && zip) {
    const { data, error } = await supabase
      .from("isp_performance_by_zip")
      .select("*")
      .eq("zip_code", zip)
      .order("avg_score", { ascending: false });

    if (error)
      return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json(data);
  }

  if (view === "isp_by_state" && isp) {
    const { data, error } = await supabase
      .from("isp_performance_by_state")
      .select("*")
      .eq("isp_name", isp)
      .order("scan_count", { ascending: false });

    if (error)
      return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json(data);
  }

  if (view === "dead_zones") {
    const { data, error } = await supabase
      .from("dead_zone_stats_by_dwelling")
      .select("*")
      .order("avg_dead_zones", { ascending: false })
      .limit(50);

    if (error)
      return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json(data);
  }

  if (view === "room_types") {
    const { data, error } = await supabase
      .from("room_type_performance")
      .select("*")
      .order("room_count", { ascending: false });

    if (error)
      return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json(data);
  }

  // Default: overview stats
  const { data, error } = await supabase
    .from("scan_sessions")
    .select(
      "zip_code, isp_name, overall_grade, overall_score, measured_download_mbps, dead_zone_count"
    )
    .order("uploaded_at", { ascending: false })
    .limit(100);

  if (error)
    return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}

// POST /api/analytics/refresh — refresh materialized views
export async function POST() {
  const supabase = createServiceClient();
  const { error } = await supabase.rpc("refresh_analytics_views");

  if (error)
    return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json({ success: true, refreshed_at: new Date().toISOString() });
}
