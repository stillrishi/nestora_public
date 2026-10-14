# Nestora Android and cloud setup

Nestora's Android app uses Capacitor around the existing HTML interface. Supabase Auth manages email/password accounts, a private Supabase database stores one shared portfolio, and a private Storage bucket stores agreements, KYC, and receipts. New accounts must be approved by a portfolio owner before they can read or change any portfolio data.

## 1. Create the Supabase project

1. Create a Supabase project and keep its database password private.
2. In **SQL Editor**, run all of `supabase/schema.sql`.
3. In **Authentication → Providers → Email**, keep email/password enabled and email confirmation enabled.
4. In **Project Settings → API**, copy the Project URL and the public **anon/publishable** key into `cloud-config.js`. Do not use a `service_role` or secret key in the app.
5. Create the first account in Nestora. In **Authentication → Users**, copy its user UUID. In SQL Editor, grant it owner access:

   ```sql
   insert into public.portfolio_memberships (user_id, email, role)
   values ('PASTE-FIRST-OWNER-USER-UUID', 'owner@example.com', 'owner');
   ```

That owner can approve later signups using the **Access requests** button. Approved users join the same portfolio. Roles are `owner`, `editor`, and `viewer`; the initial approval screen grants editor access. Run SQL in the Supabase dashboard to change a member's role.

## 2. Build the Android app

Install Node.js 22 or newer and Android Studio with an Android SDK (API 24 or newer). In this folder:

```sh
npm install
npm run android:add
npm run android:sync
npm run android:open
```

In Android Studio, build a debug APK with **Build → Build Bundle(s) / APK(s) → Build APK(s)**. Gradle also supports `./gradlew assembleDebug` from the generated `android/` folder. Android Studio reports the output path, typically `android/app/build/outputs/apk/debug/app-debug.apk`.

For updates after editing `index.html` or `cloud-config.js`, run `npm run android:sync` before rebuilding. Keep the Supabase URL and public anon/publishable key in the packaged client; RLS is the access boundary. Never put an administrative/service-role key in the APK.

## Shared-data behavior

- All approved members use one shared portfolio. Editors can change its records and files; viewers can read them; owners manage member approvals.
- Files are in a private bucket and downloaded only after authentication. The `shared/` storage path and RLS rules restrict access to approved members.
- The app uses revision-checked saves so an older copy cannot silently overwrite edits made on another device. If two people edit at once, a conflict asks them to reload before saving.
- Existing browser-only data is not automatically merged into cloud. Export a JSON backup from the old browser app first; migration/import will be a separate explicit action before production use.

## Before distributing to other landlords

This build is configured for one shared portfolio. It is not a multi-workspace SaaS product. Do not grant untrusted people access because approved members can see tenant identity/KYC files. Configure a privacy policy, support email, data retention and account deletion process, and review Supabase Auth email delivery and storage limits before distributing broadly. To give each landlord a private portfolio, the data model needs a portfolio/workspace ID and workspace-level membership instead of this single shared portfolio.
