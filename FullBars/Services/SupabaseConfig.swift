import Foundation

/// Supabase configuration.
/// Replace placeholder values with your actual Supabase project credentials.
/// The anon key is safe to embed in the iOS app — RLS policies restrict what it can do.
enum SupabaseConfig {
    /// Your Supabase project URL (e.g. "https://xyzcompany.supabase.co")
    static let projectURL = "https://dntfzocihgobisbqllcf.supabase.co"

    /// Public anon key — restricted by RLS to INSERT only on analytics tables + SELECT on ads.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRudGZ6b2NpaGdvYmlzYnFsbGNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1MjYzNjYsImV4cCI6MjA5MjEwMjM2Nn0.9fcyA_9z1iGL-Kdtnt0PtxKSB7agc5pIl61-7lzm49k"

    /// REST API base URL
    static var restURL: String { "\(projectURL)/rest/v1" }

    /// RPC base URL for calling Postgres functions
    static var rpcURL: String { "\(projectURL)/rest/v1/rpc" }

    /// Whether analytics upload is enabled.
    /// Flip to false during development or if Supabase isn't configured yet.
    static var isConfigured: Bool {
        !projectURL.contains("YOUR_PROJECT_ID")
    }
}
