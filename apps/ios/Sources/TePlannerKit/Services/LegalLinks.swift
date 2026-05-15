import Foundation

/// Public URLs for the Tautomation legal documents. Used by the login
/// page consent line and the Settings → 关于 → 隐私政策 / 用户协议
/// navigation links.
///
/// Apple App Review requires these URLs to be live + reachable when
/// the binary is submitted — they're verified against the App Store
/// Connect metadata. Hosting plan documented in
/// `docs/legal/README.md`. If the URLs change, update both here AND
/// the ASC App Privacy / Support URL fields in lockstep, otherwise
/// review may reject the binary for an inconsistent privacy link.
public enum LegalLinks {

    /// Public privacy policy. Currently a placeholder — point at the
    /// gh-pages / api.teplanner.cloud/legal/ host once the static
    /// pages go live. The DRAFT markdown lives at
    /// `docs/legal/privacy-policy.md`.
    public static let privacyPolicy = URL(string: "https://teplanner.cloud/legal/privacy.html")!

    /// Public terms of service / user agreement.
    public static let termsOfService = URL(string: "https://teplanner.cloud/legal/terms.html")!
}
