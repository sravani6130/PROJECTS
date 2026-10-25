# Gullak

Team **MautKaSamna** · Megathon 2026 (Vanguard problem statement)

Setup and run instructions for the three parts of this repository:

| Part | Folder | Needed for |
|---|---|---|
| Android app (Flutter) | `lib/`, `android/`, `assets/` | Playing the game |
| NGO API (Python, FastAPI) | `backend/` | Optional progress sync |
| NGO dashboard (static web) | `ngo-dashboard/` | Served by the API |

The app runs on its own; the API and dashboard are only needed to try the NGO sync.

## Prerequisites

- Flutter SDK, stable channel, 3.47 or newer (Dart 3.13.5 or newer)
- JDK 17
- Android SDK (platform 35 or 36, build-tools) and an emulator or a device
- Python 3.10 or newer (only for the NGO API)

Check the Flutter and Android setup with:

```bash
flutter doctor
```

## 1. Run the app

```bash
flutter pub get
flutter run                  # on a connected device or running emulator
```

Build an installable APK:

```bash
flutter build apk --debug    # build/app/outputs/flutter-apk/app-debug.apk
```

## 2. Run the NGO API and dashboard (optional)

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
cp .env.example .env         # optional; the defaults match it
.venv/bin/python -m app
```

- API: <http://127.0.0.1:8787/api/v1> (interactive docs at `/api/v1/docs`)
- Dashboard: <http://127.0.0.1:8787/>

If `PYTHONPATH` points at another Python install (ROS, conda), prefix the commands
with `env -u PYTHONPATH`.

Development logins and enrolment codes are listed in [`backend/README.md`](backend/README.md).

### Point the app at the API

A debug build on the Android emulator reaches an API on the same computer with no
extra setting (it uses `http://10.0.2.2:8787`). For any other server, set the
address at build time; release builds require HTTPS:

```bash
flutter run --dart-define=GULLAK_API_URL=https://<your-server>
flutter build apk --release --dart-define=GULLAK_API_URL=https://<your-server>
```

On a physical device over USB, forward the port and use `localhost`:

```bash
adb reverse tcp:8787 tcp:8787
flutter run --dart-define=GULLAK_API_URL=http://localhost:8787
```

### Deploy the API

`render.yaml` is a Render Blueprint for the API, the dashboard and a PostgreSQL
database. Steps are in [`backend/README.md`](backend/README.md).

## 3. Run the tests

```bash
flutter analyze
flutter test --concurrency=1                 # app tests (needs backend/.venv for test/e2e)
flutter test integration_test -d <device>    # on a device or emulator
```

```bash
cd backend
env -u PYTHONPATH PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 .venv/bin/python -m pytest
```

On Linux the app's database tests need the system `libsqlite3`.

## Datasets and model weights

None. The project uses no external datasets and no machine-learning models, so there
is nothing to download. All content is bundled in `assets/`.

## Documentation

- [`docs/OVERVIEW.md`](docs/OVERVIEW.md) — what the app does and how it is built
- [`docs/NGO_INTEGRATION.md`](docs/NGO_INTEGRATION.md) — NGO sync design
- [`backend/README.md`](backend/README.md), [`ngo-dashboard/README.md`](ngo-dashboard/README.md)

## License

[MIT](LICENSE). The bundled font, Baloo Tammudu 2, is under the SIL Open Font
License 1.1 (`assets/fonts/BalooTammudu2-OFL.txt`).
