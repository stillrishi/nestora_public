# Nestora

Nestora is a landlord property manager for tracking properties, tenancies, rent, expenses, and documents. This repository contains the app source only.

## Use your own Supabase project

1. Create a Supabase project.
2. Run [`supabase/schema.sql`](supabase/schema.sql) in its SQL Editor.
3. Enable email/password sign-in and email confirmation in Authentication settings.
4. Put your own Project URL and publishable key in `cloud-config.js`. Do not use a secret or service-role key.
5. Follow [ANDROID_SETUP.md](ANDROID_SETUP.md) to make the first account an owner and approve other accounts.

Each Supabase project created from this schema has one shared portfolio. Anyone approved in that project can see its records and files. Do not use a shared project for unrelated landlords; each landlord should configure their own Supabase project unless the app is changed to support separate workspaces.

## Build the Android app

Install Node.js 22 or newer and Android Studio. From this repository folder, run:

```sh
npm install
npm run android:add
npm run android:open
```

In Android Studio, wait for Gradle sync, then choose **Build → Generate App Bundles or APKs → Build APK(s)**. The debug APK is created under `android/app/build/outputs/apk/debug/`.

## Privacy and security

The app source is public, but Supabase records and uploaded files stay in the Supabase project configured by each installer. The publishable key is intended for client apps; database access is controlled by the included Row Level Security policies. Never commit tenant information, backups, uploaded files, passwords, or a Supabase secret/service-role key.
