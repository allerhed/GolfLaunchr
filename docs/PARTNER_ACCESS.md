# Partner (complimentary) Pro access: operator runbook

Spec: F19a. This file is the procedure; it contains **no codes**. Codes are secrets: keep them out of the repository, the app, analytics, logs, chat and screenshots.

## What the app does
Settings → Membership → **Redeem offer code** (sv: Medlemskap → Lös in erbjudandekod) opens Apple's own redemption sheet. The app never sees the code. After the sheet closes, the app asks StoreKit for the verified entitlement (four tries, two seconds apart) and only then shows Pro. A cancelled, invalid, expired, used or ineligible code leaves the verified entitlement unchanged, so nothing is unlocked on the sheet's say-so.
Complimentary access is labelled "Pro access — Complimentary / Pro-åtkomst — Kostnadsfri", with the real end date and "No charge when this access ends", **only** when StoreKit's verified offer metadata says the transaction came from a free offer code. If it cannot say so, the access is shown as plain Pro.
Pro access (paid or complimentary) never spends or resets the Free credits, hides the upgrade prompts, and ends at its verified expiry: the Free balance returns, history and exports stay readable.

## Creating offers (owner, in App Store Connect)
1. App → Subscriptions → the Pro group → monthly or annual product → Subscription Offers → **Offer codes**.
2. Type **Free**, automatic paid renewal **off**, eligibility as intended (new / existing / expired subscribers).
3. Duration: three months for influencers, six months for sponsored athletes, **using a duration Apple actually offers**; if the target is not offered, choose a supported term and record it. Code redemption expiry is separate from the access duration.
4. One-time codes need batches of at least 500: for a small programme use a unique **custom code limited to one redemption**.
5. Take screenshots of the configured offer for the evidence file before any code is distributed.

## Partner register (restricted, outside the repository)
Columns: partner ID / name · category (influencer / athlete) · campaign · owner · offer reference · assigned code reference (not the code) · intended term · redemption deadline · status (issued / confirmed / expired / disabled) · review date.
Status "confirmed" needs attributable evidence (a redemption report line or the partner's screenshot of the Membership screen). Issuing a code proves nothing. Keep partner counts separate from paying subscribers and revenue.

## Disable versus revoke
- **Disable an unredeemed code**: App Store Connect stops future redemptions. It does **not** touch access that was already redeemed.
- **Revoke active access**: there is no instant revoke for launch. Review before renewal and let redeemed access run its verified term. Do not promise early revocation; a local toggle in the app would be false. If identity-bound invitations, arbitrary durations or early revocation become necessary, that is a separate, reviewed authenticated partner service (future extension, not a launch dependency).
- Codes work for whoever redeems them first; they are not identity-bound. Do not claim that this prevents forwarding.

## Existing subscribers
Redemption must not be described as cancelling, refunding or stopping the renewal of an existing paid subscription. The app warns about this next to the button. The no-charge sentence applies to the complimentary offer only.

## Before distributing any real code (all NOT RUN until evidenced)
Sandbox and physical-device tests: sheet opens; free offer with no paid renewal; invalid, expired, used and ineligible codes; cancelled sheet; offline; verification delay; relaunch and restore; same-account second device; duplicate redemption; end-of-term downgrade; overlap with an active paid subscription; Free ledger, history and media preserved; disable before and after redemption; English and Swedish text with the real end dates. Attach screenshots to `docs/EVIDENCE.md`.
