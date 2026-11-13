# Release state — 2026-11-13

App Store Connect record: **小提琴自学** · Apple ID `6827607435` · bundle `com.archintera.VibratoCoach` · team `GB38532D8G` · SKU `com.archintera.VibratoCoach` · primary language zh-Hans.

## Current status

- App Store version **1.0 — Waiting for Review** (submitted 2026-11-13 10:43 UTC)
- Release type: **automatically release after approval**
- Attached build: **1.0 (9)** (free launch) · delivery UUID `28b57775-17ab-4966-a223-455b059245a2` · `VALID`
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
| 7 | New icon + first-lesson screen ported from dorewio |
| 8 | StoreKit 2 Pro buyout + paywall + gated training/studio |
| 9 | **Free launch**: Pro gating disabled (`ProLaunchMode.gatingEnabled = false`), all features free |

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

## Launch mode (build 9)

Paid Apps Agreement is not signed yet and the developer cannot complete Apple 2FA right now, so 1.0 launches as a **free app with all features unlocked**: `ProLaunchMode.gatingEnabled = false` in `dorewio/ProStore.swift`. The StoreKit/IAP code and the `dorewio Pro` product remain in place; flipping the flag to `true` in the 1.1 build re-enables the paywall after the Paid Apps Agreement is active.

China mainland is excluded from availability (174 of 175 territories); ICP filing is a later task. Re-enable CHN in Pricing and Availability after the ICP filing number is entered in App Information.

## Monetization — dorewio Pro (deferred to 1.1)

- Model: **one-time non-consumable unlock** (buyout). Product ID `com.archintera.VibratoCoach.pro.lifetime`.
- Price: base territory USA **$9.99** (Apple price points; China ≈ ¥68; no subscription, no renewal).
- IAP record: `6834334407` — state **READY_TO_SUBMIT**, localized (zh-Hans), review screenshot uploaded, available in all 175 territories.
- Free tier: tuner, metronome, first lesson, daily plan, basic rhythm/sight-reading/fingerboard/ear-training.
- Pro: all technique training (bow/vibrato/intonation), score studio (MusicXML/MXL import + playback, audio import + melody extraction), full stats.
- Implementation: `dorewio/ProStore.swift` (StoreKit 2, `Transaction.updates` / `currentEntitlements`, restore via `AppStore.sync()`), `ProGate` and `PaywallView`; locked destinations in `ContentView`/`PracticeLibraryView`.
- App Store review notes include the product ID and restore path.

## Blocking prerequisites before submission

1. **Paid Apps Agreement must be signed** in App Store Connect → Business → Agreements (requires bank/tax details). The Business page currently reports "To offer apps or other in-app purchases, you must sign the Paid Apps Agreement."
2. **Mainland China App 备案 (ICP)** must be completed and the filing number entered in App Store Connect before China distribution.
3. First IAP must be submitted together with app version 1.0 (review submission must contain both the version and the IAP).

## Next steps

1. Sign the Paid Apps Agreement (and consider the Small Business Program for 15% commission).
2. Create the review submission with version 1.0 + IAP `6834334407`, submit for review.
3. After approval: verify the paywall/restore flow with a sandbox account, then release.
4. Complete App 备案 for mainland China.
