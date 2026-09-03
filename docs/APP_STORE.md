# App Store Submission

Drafts for App Store Connect, plus the state of each technical requirement.
Everything marked **NEEDS YOU** cannot be settled from the code.

## Technical state

| Item | State |
|---|---|
| App icon | 1024×1024, no alpha, compiled into the bundle |
| Display name | `Bouncy` (target is `coufistgade`; `CFBundleDisplayName` corrects it) |
| Bundle ID | `com.cclv.coufistgade` |
| Version / build | 1.0 (1) |
| Deployment target | iOS 18.0 |
| Device family | iPhone only, portrait only |
| Privacy manifest | `PrivacyInfo.xcprivacy` — UserDefaults declared, CA92.1 |
| Encryption | `ITSAppUsesNonExemptEncryption = false` |
| Launch screen | `UILaunchScreen` dict, no storyboard |
| Languages | English only (`knownRegions` = en, Base) |
| Achievements | Ten, local only — no Game Center, nothing to declare |
| Signing team | **NEEDS YOU** — `DEVELOPMENT_TEAM` is unset |

## Name and subtitle

- **Name**: Bouncy
- **Subtitle** (30 char max). Counted, not estimated:
  - `One ball. Sixty seconds.` — 24 ✓
  - `Chain the bounce, beat it` — 25 ✓
  - `Chain the bounce, beat the clock` — 32 ✗ (over)

Check availability: "Bouncy" is a common word and the name may be taken.

## Description

> Sixty seconds. One ball. How long can you keep it going?
>
> Drag the ball, let go, and watch it fly. Every ball you hit scores — and if you
> keep hitting them, the multiplier climbs: 2x, 3x, 5x, all the way to 10x. Pause
> too long and the chain breaks.
>
> There is nothing to learn. Pick it up, throw a ball, and try to beat your best.
> Ten achievements are waiting as you do.
>
> - Sixty-second rounds that fit in a spare moment
> - Real physics: the ball has weight, and it bounces like it should
> - Combo multipliers that reward keeping the ball moving
> - Ten achievements, from your first points to a ten-chain
> - One thumb, no buttons
> - No accounts, no ads, no tracking. Your scores stay on your phone.

## Keywords

100 characters, comma-separated, no spaces after commas, no words already in the
name or subtitle:

```
physics,ball,arcade,casual,combo,reflex,onehand,timeattack,highscore,quickplay,offline,achievements
```

That is 99 characters. `minimal` was dropped to make room for `achievements`:
few people search a style word, and the achievements are shipping functionality
that nothing else in the metadata pointed at.

## Age rating

**4+**. Nothing in the questionnaire applies: no violence (balls colliding is not
depicted violence), no profanity, no gambling, no user content, no ads, no
unrestricted web access. (数据收集见下面 Privacy 一节 —— 年龄分级问卷问的是
内容，推送 SDK 收集的诊断数据不影响 4+。)

## Privacy

**接入 Firebase Messaging 之后这一节变了 —— 不再是「Data Not Collected」。**

游戏本身仍然不收集任何东西（分数与设置只存在设备上）。但 FCM 会收集数据，
而 App Privacy 问的是整个 app、含第三方 SDK。以下是各 SDK 自带的
PrivacyInfo.xcprivacy 实际声明的内容（不是估计，是从 Pods 里读出来的）：

| SDK | 数据类型 | 关联到用户 | 用于追踪 | 用途 |
|---|---|---|---|---|
| FirebaseMessaging | Device ID | 否 | 否 | App Functionality |
| FirebaseMessaging | Other Data Types | 否 | 否 | Analytics |
| FirebaseMessaging | Other Diagnostic Data | 否 | 否 | App Functionality |
| FirebaseInstallations | Other Diagnostic Data | 否 | 否 | Analytics |
| GoogleDataTransport | Other Diagnostic Data | 否 | 否 | Analytics |

三项都是 **not linked / not used for tracking**，所以不触发 App Tracking
Transparency，不需要弹 IDFA 授权框。但 App Privacy 表单里必须勾上 Device ID
与 Diagnostics —— 漏填是 App Review 会打回的项。

隐私政策也要跟着改：不能再写「传输任何数据」，因为推送 token 确实会发给
Google。

A privacy policy URL is required for every submission even when nothing is
collected. **NEEDS YOU** — host one saying the app stores scores and settings on
the device only and transmits nothing.

## Terms

Not required: no accounts, no purchases, no subscriptions, no user content.
Apple's standard EULA covers it.

## Screenshots — NEEDS YOU

Required: 6.9" (1320×2868) and 6.5" (1242×2688). Take them on a real device, so
ProMotion and real haptic-driven play are represented.

Suggested set, in order:
1. Mid-throw with a combo running — the core loop in one frame
2. Home, showing a best score worth beating
3. The result screen with NEW RECORD and a freshly unlocked achievement
4. The achievements screen, part-way through the ten
5. Settings, showing there is nothing to buy

Use `-maxBalls` for a fuller playfield if a screenshot looks sparse. Turn off the
DEBUG overlays first — `showsFPS` and `showsNodeCount` are compiled out of
Release, so build Release for screenshots.

## Before uploading

1. Set `DEVELOPMENT_TEAM` and switch signing to a distribution profile.
2. Bump `CURRENT_PROJECT_VERSION` on every upload; App Store Connect rejects a
   reused build number.
3. Archive against a real device, not a simulator SDK.
4. Confirm the icon has no alpha channel — a rejection cause, and easy to
   reintroduce if the icon is ever re-exported.
