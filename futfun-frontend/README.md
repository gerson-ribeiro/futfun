# FutFun - Flutter Frontend

A Flutter application for the FutFun World Cup 2026 betting pool.

## Project Structure

```
lib/
├── main.dart              # Entry point
├── app.dart               # App configuration
├── core/
│   ├── constants/         # App colors, strings, enums
│   ├── network/           # Dio HTTP client
│   ├── router/            # GoRouter configuration
│   └── services/          # Business logic services
├── shared/
│   └── widgets/           # Reusable widgets
└── features/
    ├── auth/              # Authentication
    ├── matches/           # Matches list and details
    ├── predictions/       # User predictions
    ├── ranking/           # Global ranking
    └── dashboard/         # Dashboard with charts
```

## Tech Stack

- **State Management:** Riverpod
- **Routing:** GoRouter
- **HTTP Client:** Dio
- **Secure Storage:** flutter_secure_storage
- **WebSockets:** socket_io_client
- **Charts:** fl_chart
- **Internationalization:** intl

## Getting Started

```bash
flutter pub get
flutter run
```

## Development

This project follows MVVM architecture with feature-first organization.

Each feature module contains:
- `data/` - Models and repositories
- `viewmodels/` - Business logic (AsyncNotifier)
- `views/` - UI screens and widgets

## API Integration

Backend API: `http://localhost:4000`

Authentication:
- Microsoft OAuth login
- Password setup/verification
- JWT token refresh
