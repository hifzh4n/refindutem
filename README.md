# ReFind UTeM

ReFind UTeM is a verified campus lost-and-found app for Universiti Teknikal Malaysia Melaka. It helps students and staff report missing belongings, publish found items, browse open cases around campus, and close resolved reports.

## What It Does

- Report lost items with category, date, location, description, contact preference, and optional image.
- Report found items with handover status so owners know where the item is being kept.
- Browse lost and found listings from other users with search, category filtering, pagination, image previews, and contact details.
- Keep personal report history and mark solved cases as closed.
- Manage a profile with first name, last name, email, phone, password, and cropped avatar upload.
- Protect app pages behind Supabase authentication for verified UTeM users.
- Store report and avatar images in private Supabase buckets and display them through signed URLs.

## Tech Stack

- Flutter web/mobile/desktop
- Supabase Auth, Postgres, Storage, RLS, and RPC
- GoRouter for protected routes
- Provider-based dependency injection
- GitHub Actions for analyze, tests, formatting, and GitHub Pages deployment

## Supabase Configuration

Supabase credentials are not committed to this repository. The Flutter client should only receive the Supabase URL and anon or publishable key. Never ship a service role key in the client.

Preferred build-time configuration:

```bash
flutter run \
  --dart-define=SUPABASE_URL=your-project-url \
  --dart-define=SUPABASE_ANON_KEY=your-anon-or-publishable-key
```

Local development fallback:

```bash
SUPABASE_URL=your-project-url
SUPABASE_ANON_KEY=your-anon-or-publishable-key
```

Runtime asset override:

1. Copy `assets/config/supabase.example.json` to `assets/config/supabase.json`.
2. Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
3. Use this only for deployment-specific public config. Do not commit `supabase.json`.

By default, missing config shows a startup screen with recovery steps. During local development, opt into fast-fail behavior with:

```bash
flutter run --dart-define=SUPABASE_FAST_FAIL=true
```

## Database Setup

Apply the migration in `supabase/migrations/20250516000000_initial_schema.sql` to provision:

- `lost_item_reports`
- `found_item_reports`
- private `profiles`, `lost-item-images`, and `found-item-images` buckets
- RLS policies for report ownership and authenticated browsing
- `update_my_phone(text)` RPC

After schema or policy changes, re-run Supabase security and performance advisors.

## Security Notes

- RLS is enabled for lost and found report tables.
- Storage buckets are private.
- Client uploads use authenticated user paths.
- Images are displayed using signed URLs, not public bucket URLs.
- Only the Supabase anon or publishable key belongs in client builds.
- GitHub Pages production builds read Supabase config from GitHub Actions secrets.

## Run Locally

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=your-project-url \
  --dart-define=SUPABASE_ANON_KEY=your-anon-or-publishable-key
```

## Verify

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Build For Web

```bash
flutter build web --release --base-href /refindutem/ \
  --dart-define=SUPABASE_URL=your-project-url \
  --dart-define=SUPABASE_ANON_KEY=your-anon-or-publishable-key
```

## Deploy To GitHub Pages

The workflow in `.github/workflows/flutter_ci.yml` can deploy `build/web` to GitHub Pages after every successful push to `main`.

Required repository secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

In GitHub, set Pages source to **GitHub Actions**. The deployed app will be served from:

```text
https://hifzh4n.github.io/refindutem/
```

If repository secrets are not configured yet, the workflow keeps CI green and skips the Actions deployment. The repository can also serve a manually built release from the `gh-pages` branch.
