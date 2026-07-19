# PERT Daily Planner

A mobile-first, fully offline daily planner that turns uncertain duration guesses into an automatic back-to-back timeline. One Flutter codebase produces an Android APK and a responsive web app.

## What it does

- Creates, edits, deletes, completes, postpones, and drag-reorders tasks.
- Accepts optimistic (`O`), most-likely (`M`), and pessimistic (`P`) estimates with live validation of `0 < O ≤ M ≤ P`.
- Calculates every end time automatically; users never type an end time.
- Reflows all later unfinished tasks after an estimate, start-time, completion, or order change.
- Supports nested subtasks. Parent expected times and variances are the sums of their subtask chain.
- Updates `Starts in`, `time left`, and `Overdue` countdowns every second.
- Schedules high-priority Android reminders at task start and expected end with exact alarms, idle-mode delivery, and reboot restoration.
- Generates daily, weekly (selected weekdays), and monthly occurrences.
- Tracks current/best streaks and the last seven days for repeating tasks.
- Includes daily timeline, month/two-week/week calendar, and streak views.
- Uses Material 3 with light and dark themes.
- Stores data in SQLite on Android and browser LocalStorage on the web. No login, server, or network is required.

## PERT calculation

For each task:

```text
Expected time     TE = (O + 4M + P) / 6
Standard deviation σ = (P - O) / 6
Variance            σ²
End time              = start + TE
```

Along a task/subtask chain, expected times and variances add. The day bar shows total expected work, projected finish, and the approximate 95% finish window:

```text
projected finish ± 2 × sqrt(sum of variances)
```

## Install the Android APK (no local tools)

1. Open this repository's **Actions** tab.
2. Open the newest successful **Build APK and deploy web** run.
3. Under **Artifacts**, download `pert-daily-planner-apk-<run number>`.
4. Unzip it, copy `app-release.apk` to the Android phone, and open it.
5. If Android asks, allow installation from the browser/file-manager used to open the APK.
6. On first launch, allow notifications and exact alarms. If either permission is denied, tasks still save and the app displays an alarm warning with an **Enable** action.

The cloud APK is release-optimized and signed with Android's debug key for direct side-loading. Use a private release keystore before Play Store distribution.

## Web app

The main branch deploys to:

**https://vsreeni29-commits.github.io/GptDailyPlanner/**

The web version keeps planner data in browser LocalStorage. Browser limitations mean OS alarms are intentionally skipped; the app displays that limitation while keeping countdowns and all planning features operational.

## Alarm behavior

Android scheduling uses `flutter_local_notifications`, which delegates exact schedules to Android `AlarmManager` using `exactAllowWhileIdle`. The manifest includes notification, exact-alarm, and boot-completed permissions plus the plugin's scheduled-notification and reboot receivers. There is no persistent foreground/background service.

The app maintains a rolling 30-day horizon, capped at the nearest 450 start/end reminders to respect Android pending-alarm limits. The horizon refreshes at launch and after every planner mutation. If the cap is reached, the app shows a visible warning instead of silently dropping the condition.

Some Android manufacturers apply additional battery restrictions. If a permitted alarm still does not fire, exempt **PERT Daily Planner** from that manufacturer's battery-optimization screen.

## Automated delivery

Every push runs:

1. `dart format` verification
2. `flutter analyze`
3. `flutter test`
4. release APK build and artifact upload
5. release web build and artifact upload
6. GitHub Pages deployment for `main`

The workflow is in [`.github/workflows/build-and-deploy.yml`](.github/workflows/build-and-deploy.yml) and pins Flutter `3.44.6` for reproducible builds.

## Optional local development

```bash
flutter pub get
flutter test
flutter run
```

Android 7.0 (API 24) or newer is supported.
