# FullBars — App Store Listing

## App Name
FullBars: Wi-Fi Coverage Scanner

## Subtitle (30 chars)
Map, Grade & Fix Your Wi-Fi

## Category
Primary: Utilities  
Secondary: Productivity

## Price
Free (with In-App Purchases — FullBars Pro)

---

## Description

FullBars turns your iPhone into a professional-grade Wi-Fi coverage scanner.
Walk through every room in your home and get a detailed report card on signal
strength, speed, latency, and dead zones — no extra hardware required.

**How it works**

Set up your home layout, then walk room by room while FullBars records signal
data at every step. When you're done, the app grades each room A through F
and pinpoints exactly where your Wi-Fi struggles.

**What you get**

- Room-by-room Wi-Fi grades based on signal, speed, latency, and
  interference
- Heat map overlays showing strong and weak coverage areas
- Dead zone detection with severity ratings
- Mesh router placement recommendations so you know where to add nodes
- Speed tests at every location compared to your ISP's promised plan
- An overall home grade you can share as a verifiable badge — great for
  rentals and real-estate listings
- BLE device interference scanning
- Multi-floor support with per-floor summaries

**FullBars Pro (optional upgrade)**

- Scan multiple homes (vacation house, parents' place, rental property)
- Shareable Wi-Fi badge with QR verification
- Full rescan history with trend comparisons
- PDF coverage report export
- Advanced mesh placement optimizer

---

## Keywords (100 chars max)

wifi,signal,coverage,speed test,dead zone,mesh,router,heatmap,network,home

## Promotional Text (170 chars)

Grade your home Wi-Fi room by room. Find dead zones, get mesh placement tips,
and prove your coverage with a shareable badge.

---

## What's New (Version 1.0)

Initial release — scan your home, grade every room, and find dead zones.

---

## Screenshot Plan

Capture on iPhone 16 Pro Max (6.9") and iPhone SE 3 (4.7") for required
sizes. All screenshots in dark mode.

| # | Screen | Caption |
|---|--------|---------|
| 1 | Dashboard with overall grade ring showing "A" | "Your home Wi-Fi, graded A through F" |
| 2 | Room list with colour-coded grades (A, B, C) | "Every room scored individually" |
| 3 | Room detail with heatmap overlay | "See exactly where signal drops" |
| 4 | Dead zone detection with mesh recommendations | "Find dead zones, fix them fast" |
| 5 | Speed test with ISP plan comparison | "Are you getting what you pay for?" |
| 6 | Share badge view with QR code | "Prove your Wi-Fi works" |

**iPad screenshots** (if universal build is planned later):
Reuse the same 6 screens on iPad Pro 12.9" (6th gen).

---

## App Privacy

**Data Linked to You:** None  
**Data Not Linked to You:** Diagnostics (crash logs)  
**Data Used to Track You:** None  

If the user opts in to anonymous data sharing:  
**Data Not Linked to You:** Usage Data (anonymised Wi-Fi quality metrics)

---

## Review Notes for App Review

FullBars uses the device's Wi-Fi information (via NEHotspotHelper or
CNCopyCurrentNetworkInfo where available) and ARKit/RoomPlan for room
scanning. No special entitlements beyond location services (required for
Wi-Fi SSID access) and camera (ARKit).

The app does NOT require a physical Wi-Fi network to review — all grading
screens work with seeded demo data when launched with the `--uitesting` flag,
which populates the SwiftData store with sample rooms and metrics.
