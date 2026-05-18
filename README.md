# Plant IoT Flutter App

Flutter management-support app for the Plant IoT system.

GitHub Pages is for public/simple visualization. This Flutter app is for management support and care-action logging.

```text
sensor_logs latest row -> state card -> care action input -> care_logs
```

Use only the Supabase anon public key in this app. Do not place `SUPABASE_SENSOR_KEY` or a service_role key in Flutter.

Run with dart defines:

```powershell
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-public-key
```

If this directory was not created by `flutter create`, run once:

```powershell
flutter create .
flutter pub get
```

## Deploying to GitHub Pages (automatic)

This repository includes a GitHub Actions workflow that builds the Flutter web app and deploys `build/web` to the `gh-pages` branch on each push to `main`.

Steps:

1. Push your changes to the `main` branch.
	```bash
	git add .
	git commit -m "Update UI"
	git push origin main
	```

2. Wait for GitHub Actions to finish the `build` job (usually a few minutes). The workflow file is `.github/workflows/deploy.yml`.

3. The site will be published to GitHub Pages from the `gh-pages` branch. You can enable GitHub Pages in repository Settings → Pages if not automatic.

Notes:
- The workflow uses the built-in `GITHUB_TOKEN` so you don't need to add extra secrets.
- If you prefer faster previews during development, consider using `flutter run -d web-server` with `ngrok`.

