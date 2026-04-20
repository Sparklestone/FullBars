import { NextRequest, NextResponse } from "next/server";
import { createServiceClient } from "@/lib/supabase";

// GET /api/partners
export async function GET() {
  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("ad_partners")
    .select("*")
    .order("name");

  if (error)
    return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}

// POST /api/partners — create a new partner
export async function POST(req: NextRequest) {
  const body = await req.json();
  const supabase = createServiceClient();

  const { data, error } = await supabase
    .from("ad_partners")
    .insert({
      name: body.name,
      partner_type: body.partner_type,
      logo_url: body.logo_url,
      website_url: body.website_url,
      contact_email: body.contact_email,
      is_active: body.is_active ?? true,
    })
    .select()
    .single();

  if (error)
    return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data, { status: 201 });
}
