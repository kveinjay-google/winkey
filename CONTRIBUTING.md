# Contributing

Thanks for your interest in WinKey.

## Development

Build the app:

```sh
swift build
```

Package a local `.app` bundle:

```sh
scripts/build-app.sh
```

The packaged app is written to `dist/WinKey.app`.

## Guidelines

- Keep mappings conservative and easy to disable from the menu.
- Prefer macOS native shortcuts over custom automation when possible.
- Avoid storing or logging keyboard input.
- Test changes with Accessibility permission both enabled and disabled.
