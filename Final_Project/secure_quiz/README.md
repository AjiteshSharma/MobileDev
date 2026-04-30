# Secure Quiz (Flutter + Firebase)

Secure mobile quiz platform with teacher/student roles, Excel-based quiz creation, and anti-cheating safeguards.

## Quick setup

1. Install packages:
   - `flutter pub get`
2. Configure Firebase for this Flutter app:
   - `flutterfire configure`
3. Add Firebase platform files if not auto-generated:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
4. Deploy backend rules/functions from project root:
   - `firebase deploy --only firestore:rules,storage`
   - `cd functions && npm install && firebase deploy --only functions`

## Default roles

User role is read from Firestore `users/{uid}.role`.
Supported values:
- `teacher`
- `student`

## Main modules

- `lib/screens/login_screen.dart`: Firebase auth + role redirect
- `lib/screens/create_quiz_screen.dart`: teacher Excel upload flow
- `lib/screens/quiz_taking_screen.dart`: secure quiz attempt with violation logging
- `lib/services/*`: auth, quiz, attempt services
- `functions/index.js`: Cloud Function to parse Excel into quiz questions
- `firestore.rules` and `storage.rules`: role-based security

See `docs/IMPLEMENTATION_NOTES.md` for schema and implementation details.