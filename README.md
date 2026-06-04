# Notebook Mobile App (Flutter)

A local-first mobile note-taking app built with Flutter. Notes are stored on-device, with optional note locking via PIN and (when available) biometric authentication.

## Features

- **Create, edit, and delete notes**
- **Rich text editor** (powered by `flutter_quill`)
- **Note locking**
  - Lock with **PIN**
  - Optionally unlock with **biometrics** (where supported)
- **Attachments**
  - Attach files to notes
  - Open attachments with the platform file opener
- **Voice-to-structured notes**
  - Speech recognition → heuristic conversion into a structured note
- **Export / backup**
  - Export notes as JSON and share via the OS share sheet
- **Local-only storage**
  - Notes persist on-device (no remote note server)

## Privacy Policy & Terms of Use

- **Privacy Policy:** accessible from **Settings → Privacy Policy**
- **Terms of Use:** accessible from **Settings → Terms of Use**

## Tech Stack

- **Flutter / Dart**
- **flutter_quill** for rich text editing
- **shared_preferences** for settings persistence (and web storage)
- **local_auth** for biometric unlock (where available)
- **speech_to_text** + **permission_handler** for voice-to-text
- **file_picker** + **open_filex** for attachments
- **share_plus** for exporting/sharing backups

## Project Setup

### Requirements
- Flutter SDK installed
- Android/iOS tooling set up as needed (or use a desktop/web target)

### Install Dependencies
From the `flutter_app` directory:

```bash
flutter pub get
```

### Run
```bash
flutter run
```

## Configuration & Storage Model (High Level)

- **Local storage:** notes are persisted locally on the device.
- **PIN storage:** PINs for locked notes are stored locally so the app can unlock the note later.
- **Export:** export generates a JSON file and shares it using the device share sheet.

## Troubleshooting

### Rich text editor toolbar errors / overflow
If you see editor toolbar layout issues:
- Use the editor toolbar **minimize/expand** toggle
- Restart the screen after changing toolbar mode

(Recent toolbar work focused on preventing Quill toolbar config/runtime issues and preventing layout overflow.)

### Biometric availability
If biometric unlock is not offered:
- Ensure the device has biometric capability enabled
- Ensure OS permissions are granted (if required)

## License

All source code in this repository is provided under the terms of the project’s selected license (if any).
If no license file exists, you may add one as your next step.

## Acknowledgements

- `flutter_quill`
- `local_auth`
- `speech_to_text`
- `file_picker`, `open_filex`
- `share_plus`
