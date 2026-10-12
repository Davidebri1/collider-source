# Launch configuration — exact values

Everything needed to make auth and purchases real, with the values already
resolved from the codebase so nothing has to be re-derived at a dashboard.

Constants: bundle id / package `app.collider.native` · URL scheme `collider` ·
Supabase project ref `gmenftvasdbhkbinkdux` · RevenueCat project `eb674fb4`.

---

## 1. RevenueCat — DONE, prices included

Project **Collider** (`eb674fb4`), React Native, Productivity. Deliberately
separate from the pre-existing "AI Multiverse" project (`98ed0618`), which is a
different app; merging them would have pooled two products' revenue and
entitlements permanently.

Test Store app is `app7accaf8f68`.

| Product | Type | Price | Entitlement | Title | REST id |
|---|---|---|---|---|---|
| `collider.pro.monthly` | auto-renewing, P1M | USD 19.99 | `pro` | Collider Pro | `prod0b536bee09` |
| `collider.elite.monthly` | auto-renewing, P1M | USD 49.99 | `elite` | Collider Elite | `prod30dc7af1ce` |
| `collider.wallpaper.pack` | non-consumable | USD 2.99 | `wallpapers` | Live Wallpaper Pack | `prod022e5a4bc0` |

Identifiers match `IAP_PRODUCTS` in `src/services/iap.ts` exactly.

Test Store key is in `.env` as `EXPO_PUBLIC_REVENUECAT_TEST_KEY`. It exercises
the full purchase → entitlement path with no store accounts in existence.

**No offerings exist, and none are needed.** `buy()` in
`src/services/purchases.ts:162` calls `getOfferings()` but falls through to
`purchaseStoreProduct` when no package matches, and nothing else in `src/`
reads offerings. Add one only if a paywall is built that lists packages.

### Price is immutable — the only fix is delete and recreate
The new-product form says it outright: *"Saved pricing can't be edited
afterwards"*, and subscription duration is *"part of the product definition
and can't be changed later."* There is no price control on the product detail
page and no edit route. Correcting the original $0.99 products therefore meant
deleting all three and recreating them. Safe here only because all three had
zero transactions; check `…/products/{id}/transactions` before ever repeating it.

The $0.99 came from the **create form's own default** in the price field. It is
not inherited from anything — it just has to be overwritten before submitting.

### Where price actually lives
Not on the product record and not on the app-level products list. It is a
separate **project-level** resource:

```
GET /internal/v1/developers/me/projects/{project}/products/{prod}/prices
→ [{"currency":"USD","id":"prc…","price":19.99,"introductory_price":null}]
```

So a product can read as fully configured everywhere the API shows it while
still being priced wrong. Always check this endpoint.

### Automating this dashboard
- **Attach entitlements from the entitlement page, not the product page.**
  `/product-catalog/entitlements/{entl}` → Attach gives a plain checkbox list
  of products and works first try. The product page's Attach opens a Radix
  select that would not open under any click this session — coordinate clicks,
  ref clicks, and keyboard focus all failed. The doc previously prescribed a
  synthetic `pointerdown → mousedown → pointerup → mouseup → click` sequence;
  that requires JS execution, which the agent sandbox blocks. Use the
  entitlement page instead and the problem disappears.
- **`form_input` sets the DOM but not React's state on this form.** The number
  price field silently reverted, and a submit with `form_input`-filled text
  fields fired **no POST at all** — client-side validation saw empty state.
  Real keystrokes (`triple_click` → `ctrl+a` → `type`) are what register.
  Verify with `document.querySelectorAll('input')` values before submitting.
- **Buttons below the fold need two clicks:** the first only scrolls the
  element into view, the second activates it. Re-screenshot in between —
  coordinates are screenshot-space and the page will have moved.
- **If `screenshot` starts failing with "Browser pane is not displayed", stop
  clicking.** The page stops compositing, clicks land at stale coordinates,
  and focus silently stays on the previous field. One `title` ended up as
  `"Collider Elite49.99collider.elite.monthlyElite MonthlyCollider Elite49.99"`
  that way.
- **The DOM lags a render behind.** An attach that had already succeeded still
  read "No associated entitlements" on screen. Verify against
  `GET /internal/v1/developers/me/projects/{id}/apps/{app}/products` with header
  `X-Requested-With: XMLHttpRequest`, not against the page text.

---

## 2. Google — clients already exist, do NOT create new ones

Google Cloud project **Collider AI** (`collider-ai-498201`). Two OAuth clients
are already live and wired in `src/services/googleAuthConfig.ts`:

- Web: `936092858710-36a9kiqprhvmg7534pq9c32dkpu4tahh.apps.googleusercontent.com`
- iOS: `936092858710-bti8eattr6c405jjq8ce5000gsb1kt2d.apps.googleusercontent.com`
- Android: **not created.** Needs a SHA-1 signing fingerprint, which only
  exists after the first `eas build -p android`. Until then Android falls back
  to the web client.

### Two separate Google integrations — don't conflate them
1. **Calendar + Tasks** (`services/googleAuth.ts`) — talks to Google directly
   for those scopes. Already working.
2. **Sign in with Google** (`services/auth.ts`) — goes through
   `supabase.auth.signInWithOAuth`, so Google redirects to *Supabase*, not to
   the app.

They can share one OAuth client, provided every redirect URI below is
registered on the web client.

### Authorized redirect URIs on the WEB client — DONE
```
https://gmenftvasdbhkbinkdux.supabase.co/auth/v1/callback
http://localhost:8081
```
- The Supabase callback is what Sign-in-with-Google needs.
- `localhost:8081` is what `GOOGLE_REDIRECT_URI` uses for `expo start --web`.

**There is no proxy URI, and no Expo username is needed.** An earlier revision
of this file told you to register `https://auth.expo.io/@<username>/collider`.
That was wrong and would have added a dead entry. Expo retired the proxy: in
expo-auth-session 57 `makeRedirectUri` accepts only `{ native, scheme,
isTripleSlashed, queryParams, path, preferLocalhost }`. `auth.ts` was calling
`makeRedirectUri({ useProxy: true } as any)` — the `as any` is why it compiled,
the unknown key was dropped silently, and both Google and Apple sign-in were
pointing at a URI nobody had registered. Now explicit: `collider://` on native,
dev-server origin on web.

`localhost:19006` is also omitted deliberately — that was the web port for
SDK ≤47. This app is on SDK 54, which serves 8081.

### Also needed
The web client's **client secret** — Supabase's Google provider requires it.
Already set. It lives only in Supabase, in no file in this repo; keep it that
way. The previous secret (`****CjFq`) is unrecoverable but still valid — revoke
it in Google Cloud once nothing depends on it.

---

## 3. Supabase auth providers

Dashboard → Authentication → Providers.

- **Google: DONE** — enabled, web client id + secret set, verified after a
  reload.
- **Apple: blocked.** Needs Services ID, Team ID, Key ID and the `.p8` contents
  from the Apple Developer account. This is the last provider.
- **URL configuration: DONE.** Redirect allowlist is `collider://**` and
  `http://localhost:8081/**` — the two things `makeRedirectUri` can now
  actually return. No proxy entry (see §2).
- **Site URL: `http://localhost:8081`.** It was sitting on Supabase's
  `http://localhost:3000` default, which nothing in this project serves. Site
  URL is the fallback when a redirect isn't in the allowlist, so a wrong value
  fails closed and silently.

  It should eventually be the marketing site, **but `collider.app` does not
  resolve** — `curl https://collider.app` fails to resolve the host. Point Site
  URL at it only once it is actually live.

Email/password needs nothing — `signInWithEmail` already works, including its
sign-up fallback.

---

## 4. Apple

**Everything below is blocked by one unsigned agreement.** The account
(`ebridavid@gmail.com`, David Ebri) is in good standing and logged in, but the
updated **Apple Developer Program License Agreement** has not been accepted.
Apple returns *"Access Unavailable — you currently don't have access to this
membership resource"* for Certificates, Identifiers & Profiles, and the same
lock applies to App Store Connect and the App Store Connect API.

So this is not, as previously recorded, a matter of missing Services ID / Team
ID / Key ID / `.p8`. Those cannot even be generated yet. Accept the agreement
at developer.apple.com/account → "Review agreement" and the whole section
below becomes doable. It is a binding contract, so it is the owner's click.

- App ID `app.collider.native`: enable **In-App Purchase** and
  **Sign In with Apple**.
- Sign-in key: Keys → new key → enable Sign In with Apple → download the `.p8`
  (one download only). Collect **Key ID** and **Team ID**.
- App Store Connect: a subscription group with the two auto-renewables, plus
  the wallpaper pack as a non-consumable. Same three identifiers as RevenueCat.
- Grab the **App-Specific Shared Secret** if not using RevenueCat for receipts.

## 5. Google Play

- Monetize → Products: two subscriptions + one in-app product, same identifiers.
- Service account only needed if you skip RevenueCat for receipt validation.

---

## The real gate

**None of this is testable in Expo Go.** IAP and native Sign in with Apple both
require a development build (`eas build --profile development`). Worth doing
first so the rest is verified rather than configured blind.

Secrets that must never enter `.env`: the Google client secret, the Apple
`.p8`, the Play service-account JSON, and any RevenueCat *secret* key.
`EXPO_PUBLIC_*` values ship inside the bundle and are extractable — the
RevenueCat public SDK keys are fine there, nothing else is.
