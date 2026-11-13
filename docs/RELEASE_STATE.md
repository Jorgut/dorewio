# Release state — 2026-11-13

App Store Connect record: **小提琴自学** · Apple ID `6827607435` · bundle `com.archintera.VibratoCoach` · team `GB38532D8G` · SKU `com.archintera.VibratoCoach` · primary language zh-Hans.

## Current status

- App Store version **1.0 — Prepare for Submission** (not submitted for review)
- Attached build: **1.0 (7)** · delivery UUID `3f574b00-f848-403f-bf58-585c37b47bee` · processing `VALID`
- Listing name: **dorewio** · subtitle **小提琴 · 调音 · 识谱 · 跟奏**
- Category: Music (primary) / Education (secondary) · Age rating **4+** · copyright `2026 Altankhuu Jorgutyn`
- Pricing: app **free** (no in-app purchases yet) · availability: all 175 countries/regions
- App Privacy: **Data Not Collected** (published)
- Screenshots: 5 × iPhone 6.9"/6.7" (1320×2868) — see `docs/screenshots/app-1.0/`
- Review contact: Altankhuu JORGUTYN · +8618588751947 · honaler@gmail.com · demo account not required
- Privacy policy: <https://jorgut.github.io/dorewio/PRIVACY.html> · Support: <https://jorgut.github.io/dorewio/SUPPORT.html>

## Build history in this version

| Build | Notes |
|---|---|
| 4 | First upload of the rebranded project; old icon |
| 5 | Added `PrivacyInfo.xcprivacy` |
| 6 | New dorewio icon + display name `dorewio` |
| 7 | Current build: new icon + first-lesson screen ported from dorewio |

## Known caveats

- **App Store Connect still displays the old app icon** in the app header. Build 6/7 binaries contain the new icon (verified in the IPA), but Apple's app-record icon refreshes when the version is submitted/approved; it is not editable before that.
- App Store screenshots currently in ASC show the 1.0 (7) UI: first lesson, learning tab, training tab, score studio, today.
- No real-device pass of build 7 yet; TestFlight internal builds are available.
- Mainland China distribution requires an App 备案 (ICP filing) number in App Store Connect. **Not yet provided** — this blocks China mainland availability.

## Archive / export / upload (requires explicit approval)

```bash
# 1) Archive (bundle id stays com.archintera.VibratoCoach)
xcodebuild archive -project dorewio.xcodeproj -scheme dorewio \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/dorewio.xcarchive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  MARKETING_VERSION=1.0 CURRENT_PROJECT_VERSION=8

# 2) Export App Store IPA
cat > build/ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>GB38532D8G</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath build/dorewio.xcarchive \
  -exportPath build/export -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

# 3) Upload
xcrun altool --upload-app -f build/export/dorewio.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
```

Never commit `$ASC_KEY_PATH` (`.p8`), `.xcarchive`, `.ipa` or provisioning profiles.

## Next steps

1. Decide monetization: **buyout Pro (¥68, recommended)** vs subscription — see `docs/BUSINESS_MODEL_RESEARCH_2026-11-13.md`.
2. Implement StoreKit 2 (buyout + paywall + restore) and ship as build 8, still version 1.0.
3. Complete App 备案 (ICP) for mainland China before enabling China distribution.
4. Submit version 1.0 for review after IAP is added (first IAP must ship with a version).
