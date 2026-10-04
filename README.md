# Taskio Flutter

Todoist-style client for the [Taskio](https://github.com/ishaanyo/taskio) API (Next.js on Vercel + Neon).

## Features

- Sign up / log in
- Inbox, Today, Upcoming
- Projects
- Tasks with priority (P1–P4), due date, and due time
- Complete and delete

Priority matches the API: 4 = P1 (highest), 1 = P4.

## Run

```bash
flutter create . --project-name taskio
flutter pub get
flutter run
```

`flutter create .` adds the Android/iOS/web runners. Existing `lib/` files are kept.

On the login screen set the API base URL to your Vercel deployment, for example `https://taskio.vercel.app`. Android emulator can use `http://10.0.2.2:3000` when the Next.js app is running locally.

Allow cleartext only for local HTTP. Production HTTPS needs no extra config.
