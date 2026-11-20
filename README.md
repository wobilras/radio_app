# radio_app

Radio application

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android release signing

Set RADIO_RELEASE_STORE_FILE to an absolute keystore path and supply
RADIO_RELEASE_STORE_PASSWORD, RADIO_RELEASE_KEY_ALIAS, and
RADIO_RELEASE_KEY_PASSWORD through your local environment or CI secrets.
Run flutter build apk --release to produce a signed APK. Keep the
keystore and passwords outside Git.
