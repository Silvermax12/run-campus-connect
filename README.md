# RUN Campus Connect

A campus social platform for **Redeemer's University (RUN)** — connecting students and staff through feeds, messaging, institutional content, and verified fresher onboarding.

[![Flutter](https://img.shields.io/badge/Flutter-3.7+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-run--campus--connect-FFCA28?logo=firebase)](https://firebase.google.com)
[![Riverpod](https://img.shields.io/badge/State-Riverpod-00897B)](https://riverpod.dev)

---

## Overview

RUN Campus Connect is a cross-platform Flutter application that provides:

- **Social feed** with global, faculty, and department-scoped posts
- **Direct messaging** with push notifications and read receipts
- **Institutional hub** — news, history, governance, vision/mission, contacts
- **Fresher verification** — JAMB document upload with OCR validation
- **Push notifications** via FCM topics and direct messages
- **Over-the-air updates** via Shorebird and Firebase Remote Config

**Version:** `1.0.0+3`  
**Firebase project:** `run-campus-connect`

---

## Tech stack

| Layer | Technology |
|-------|------------|
| Mobile app | Flutter, Dart 3.7+ |
| State management | Riverpod 2.x (code generation) |
| Navigation | go_router |
| Backend | Firebase Auth, Cloud Firestore, FCM, Remote Config |
| Media | Cloudinary |
| Document OCR | Python FastAPI + EasyOCR |
| Push gateway | Vercel serverless (Node.js) |
| OTA updates | Shorebird |

---

## Quick start

```bash
# Install dependencies
flutter pub get

# Generate Riverpod code
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

For full setup (Firebase, Python backend, Vercel, Cloudinary), see **[Getting Started](docs/GETTING_STARTED.md)**.

---

## Documentation

| Document | Description |
|----------|-------------|
| [Documentation Index](docs/README.md) | Master documentation portal and system map |
| [Architecture](docs/ARCHITECTURE.md) | Multi-tier topology, layers, and data flows |
| [Getting Started](docs/GETTING_STARTED.md) | Prerequisites, local setup, and troubleshooting |
| [Features](docs/FEATURES.md) | Complete feature specs, screens, and business rules |
| [Database Schema](docs/DATABASE_SCHEMA.md) | Cloud Firestore collections, ERDs, and local storage |
| [Security & Rules](docs/SECURITY_AND_RULES.md) | Line-by-line Firestore and Storage security rules |
| [API Reference](docs/API_REFERENCE.md) | Python FastAPI, Vercel push gateway, and native channels |
| [Development Guide](docs/DEVELOPMENT_GUIDE.md) | Riverpod patterns, conventions, and build workflows |
| [Testing & QA](docs/TESTING_AND_QA.md) | 109-test-case testing matrix and automated UAT suite |
| [Scrapers & Maintenance](docs/SCRAPERS_AND_MAINTENANCE.md) | Web scrapers, data pipelines, and database utilities |
| [Codebase Inventory](docs/CODEBASE_INVENTORY.md) | Comprehensive file-by-file catalog of every project file |

---

## Project structure

```
run_campus_connect/
├── lib/                 # Flutter source (feature-first architecture)
├── python_backend/      # FastAPI OCR verification + scrapers
├── vercel_functions/    # FCM push notification gateway
├── assets/              # Images, governance HTML, Shorebird config
├── test/                # Unit and widget tests
└── docs/                # Project documentation
```

---

## Authentication

| User type | Method | Domain |
|-----------|--------|--------|
| Staff / students | Google Sign-In or email/password | `@run.edu.ng` |
| Freshers | JAMB-based signup + document OCR | `@fresher.run.edu.ng` |

---

## Running tests

```bash
flutter test
```

---

## Contributing

1. Read the [Development Guide](docs/DEVELOPMENT_GUIDE.md)
2. Follow feature-first folder conventions
3. Run `flutter analyze` and `flutter test` before submitting changes
4. Never commit secrets (`serviceAccountKey.json`, `.env` files)
