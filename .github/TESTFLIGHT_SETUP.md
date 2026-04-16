# TestFlight CI Setup

The `testflight.yml` workflow archives and uploads to TestFlight whenever you push a version tag (e.g. `v1.0.0-beta.1`) or trigger it manually.

## Required GitHub Secrets

Add these in **Settings → Secrets and variables → Actions**:

| Secret | How to get it |
|--------|---------------|
| `P12_BASE64` | Export your distribution certificate from Keychain Access as `.p12`, then `base64 -i cert.p12` |
| `P12_PASSWORD` | The password you set when exporting the `.p12` |
| `PROVISIONING_BASE64` | Download your App Store provisioning profile from the Apple Developer portal, then `base64 -i profile.mobileprovision` |
| `KEYCHAIN_PASSWORD` | Any random password (used for the temporary CI keychain) |
| `ASC_KEY_ID` | App Store Connect API key ID (from App Store Connect → Users and Access → Integrations → Keys) |
| `ASC_ISSUER_ID` | The Issuer ID shown on the same page |
| `ASC_KEY_BASE64` | `base64 -i AuthKey_XXXXXXXX.p8` |

## Triggering a build

```bash
git tag v1.0.0-beta.1
git push origin v1.0.0-beta.1
```

Or go to **Actions → TestFlight → Run workflow** in the GitHub UI.
