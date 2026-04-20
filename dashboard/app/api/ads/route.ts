import { NextRequest, NextResponse } from "next/server";
import { createServiceClient } from "@/lib/supabase";

// GET /api/ads — list all placements
export async function GET() {
  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("ad_placements")
    .select("*, ad_partners(name, partner_type, logo_url)")
    .order("created_at", { ascending: false });

  if (error)
    return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}

// POST /api/ads — create a new placement
export async function POST(req: NextRequest) {
  const body = await req.json();
  const supabase = createServiceClient();

  const { data, error } = await supabase
    .from("ad_placements")
    .insert({
      partner_id: body.partner_id,
      target_zip_codes: body.target_zip_codes ?? [],
      target_states: body.target_states ?? [],
      target_dwelling_types: body.target_dwelling_types ?? [],
      trigger_condition: body.trigger_condition ?? {},
      headline: body.headline,
      body_text: body.body_text,
      cta_text: body.cta_text ?? "Learn More",
      cta_url: body.cta_url,
      discount_code: body.discount_code,
      badge_text: body.badge_text,
      daily_impression_cap: body.daily_impression_cap,
      total_impression_cap: body.total_impression_cap,
      start_date: body.start_date,
      end_date: body.end_date,
      cost_per_impression: body.cost_per_impression ?? 0,
      cost_per_click: body.cost_per_click ?? 0,
      is_active: body.is_active ?? true,
      is_house_ad: body.is_house_ad ?? false,
    })
    .select()
    .single();

  if (error)
    return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data, { status: 201 });
}

// PATCH /api/ads — update a placement
export async function PATCH(req: NextRequest) {
  const body = await req.json();
  const { id, ...updates } = body;

  if (!id)
    return NextResponse.json({ error: "id is required" }, { status: 400 });

  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("ad_placements")
    .update(updates)
    .eq("id", id)
    .select()
    .single();

  if (error)
    return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}

// DELETE /api/ads — delete a placement
export async function DELETE(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const id = searchParams.get("id");

  if (!id)
    return NextResponse.json({ error: "id is required" }, { status: 400 });

  const supabase = createServiceClient();
  const { error } = await supabase.from("ad_placements").delete().eq("id", id);

  if (error)
    return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json({ success: true });
}
