import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "FullBars Admin Dashboard",
  description: "Ad placement management and analytics for FullBars",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen bg-[#0a0e1a]">
        <nav className="border-b border-gray-800 bg-[#111827]/80 backdrop-blur-sm sticky top-0 z-50">
          <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-lg bg-cyan-500/20 flex items-center justify-center">
                <span className="text-cyan-400 font-bold text-sm">FB</span>
              </div>
              <h1 className="text-lg font-semibold text-white">
                FullBars <span className="text-cyan-400">Admin</span>
              </h1>
            </div>
            <div className="flex items-center gap-6 text-sm">
              <a href="/" className="text-gray-400 hover:text-white transition">
                Dashboard
              </a>
              <a
                href="/ads"
                className="text-gray-400 hover:text-white transition"
              >
                Ad Placements
              </a>
              <a
                href="/partners"
                className="text-gray-400 hover:text-white transition"
              >
                Partners
              </a>
              <a
                href="/analytics"
                className="text-gray-400 hover:text-white transition"
              >
                Analytics
              </a>
            </div>
          </div>
        </nav>
        <main className="max-w-7xl mx-auto px-6 py-8">{children}</main>
      </body>
    </html>
  );
}
