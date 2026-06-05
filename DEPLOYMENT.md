# paiOS — Deployment & Signing Notes

Working notes for building and installing paiOS to a physical iPhone + Apple Watch.
Status as of 2026-06-05.

## TL;DR

- ✅ **iPhone app installs and runs** — signed, on device, working.
- ❌ **Watch app will NOT install on the Apple Watch** — "This app could not be installed at this time." Root cause still unidentified (see Known Issue below). App Store watch apps install fine; only this dev-signed one fails.

## Identity / reference values

| Thing | Value |
|---|---|
| Apple ID | desantisll@gmail.com (Lou DeSantis) |
| **Team (paid)** | **`3YBM7ACN68`** (LEONARD LOUIS DE SANTIS — Admin) — *use this* |
| Team (personal/free, stale) | `4N5M88DQ9D` — do NOT use; account doesn't own it for builds |
| iOS app bundle id | `ai.ourpai.paios` |
| Watch app bundle id | `ai.ourpai.paios.watchkitapp` |
| iPhone | iPhone 16 Pro · UDID `00008140-00144C260093C01C` · CoreDevice `9C37B784-0FA5-5233-A3FB-D74BC4483BAD` |
| Apple Watch | Ultra 2 (Watch7,5) · UDID `00008310-000D32162188A01E` · CoreDevice `0DA6BCC1-F53F-5FAC-8D7E-A5605C6E9CFF` |

## Signing setup (what's in the project now)

- Both explicit **App IDs registered** in the portal (`ai.ourpai.paios`, `ai.ourpai.paios.watchkitapp`), all capabilities OFF.
- **iOS app:** automatic signing, team `3YBM7ACN68`.
- **Watch app:** **manual** signing with the explicit profile **`paiOS Watch Dev`** (an "iOS App Development" profile generated for `ai.ourpai.paios.watchkitapp`, all certs, all devices incl. the Ultra 2).
  - Set in `project.yml` under the `paiOS Watch App` target: `CODE_SIGN_STYLE: Manual`, `PROVISIONING_PROFILE_SPECIFIER: "paiOS Watch Dev"`, `CODE_SIGN_IDENTITY: "Apple Development"`.
- The watch's UDID **is** registered to the team and **is** in the `paiOS Watch Dev` profile (verified).

### Where the provisioning profile lives
- **Canonical:** Apple Developer portal → Profiles → **paiOS Watch Dev** (re-downloadable anytime; Xcode auto-downloads it when signed into the account with the App ID present).
- **Local backup:** `signing/paiOS_Watch_Dev.mobileprovision` (gitignored — contains device UDIDs/team, kept out of the public repo). UUID `82ab9972-89db-4e75-9779-cb425f35487b`.
- For Xcode to use it, it must be copied to `~/Library/Developer/Xcode/UserData/Provisioning Profiles/<UUID>.mobileprovision`.

## Build & install (from a Mac with Xcode 26.1, the devices connected, signed into the Apple ID)

```bash
cd ~/.../paiOS    # the repo

# build the iOS app for the connected iPhone (embeds the watch app), with provisioning
xcodebuild -project paiOS.xcodeproj -scheme paiOS \
  -destination 'platform=iOS,id=<IPHONE_UDID>' \
  -allowProvisioningUpdates -derivedDataPath build build

# install to the iPhone over USB (carries the embedded watch app)
xcrun devicectl device install app --device <IPHONE_COREDEVICE_ID> \
  build/Build/Products/Debug-iphoneos/paiOS.app
```
Then the watch app is *supposed* to install to the watch via the iPhone's **Watch app** (Bluetooth) — that's the step that fails.

> Direct `devicectl ... install --device <WATCH_COREDEVICE_ID>` times out: "Timed out while attempting to establish tunnel" — the Mac↔watch wireless dev tunnel won't hold (worse on gated/community Wi-Fi). The phone→watch Bluetooth path doesn't need it.

## Known Issue — watch app won't install ❌

Symptom: in the iPhone's Watch app, tapping Install on **Claude Code** spins, then "**This app could not be installed at this time.**" App Store watch apps (e.g. Google Maps) install fine on the same watch.

### Ruled out (confirmed NOT the cause)
- ❌ Wrong team — fixed (was stale `4N5M88DQ9D`; now correct `3YBM7ACN68`). iOS app installs.
- ❌ Watch not registered — it IS registered to the team and IS in the profile.
- ❌ Developer Mode off — it's been **on** for weeks.
- ❌ Free-account 3-app limit — paid account, no limit.
- ❌ Profile platform missing watchOS — red herring; "iOS App Development" profiles cover watchOS even though the `Platform` field shows only `[iOS, visionOS]`.
- ❌ Wildcard vs explicit profile — switched the watch app to the explicit `paiOS Watch Dev` profile (manual signing). **Still fails.**
- ❌ Mac↔watch network tunnel — irrelevant; the install is phone→watch over Bluetooth.

### Not yet tried (next steps for the other machine)
1. **Get the watch's own install log.** The "could not be installed" verdict is made on the *watch*, and doesn't reach the iPhone syslog. Capture it via: Xcode → Window → Devices & Simulators → select the watch → **View Device Logs / Open Console**, OR a `sysdiagnose` on the watch, while retrying the install. The exact `installd`/`profiled` reason will end the guessing.
2. **Run it straight from Xcode** to the watch (select `paiOS Watch App` scheme + the watch destination, ⌘R) on a **clean, non-captive Wi-Fi** (home network or iPhone Personal Hotspot, so the Mac↔watch tunnel can hold). Xcode's GUI install path + a stable link may surface a clearer error or just work.
3. **Bump the watch app `CFBundleVersion`/`MARKETING_VERSION`** so it differs from any half-installed prior copy, and try a fresh install after deleting any stuck/placeholder copy from the watch.
4. **Check the embedded watch app entitlements** match the profile exactly (`codesign -d --entitlements - "<watch app>"` vs the profile's entitlements).
5. **Last resort:** rebuild the watch target as a clean Xcode-template watchOS app (single target) and diff its Info.plist/build settings against ours — there may be a subtle key (e.g. `WKCompanionAppBundleIdentifier`, `MinimumOSVersion`, `UIDeviceFamily`) the companion installer is unhappy with.

### The most suspicious remaining lead
The watch app is a **companion** (`WKApplication=YES` + `WKCompanionAppBundleIdentifier=ai.ourpai.paios`) embedded in the iOS app. The original standalone build needed `WKWatchOnly=YES`; switching to the companion model is correct for WatchConnectivity but the companion **install handshake** (versions/identifiers must line up exactly between the iOS app and its embedded watch app) is the least-verified part. Worth re-checking that the iOS app's installed copy and the watch app agree on bundle id prefix + version, and that the watch app truly shipped *inside* the installed iOS app (`paiOS.app/Watch/paiOS Watch App.app`).

## Repo

Public: https://github.com/loudoguno/paiOS — the app code, README, assets. Signing material (`signing/`) and build output are gitignored.
