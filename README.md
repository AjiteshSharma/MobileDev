Setup Instructions

Prereqs (install once):

Flutter SDK (Dart 3.11+), Android Studio SDK/Platform tools
Firebase CLI: npm i -g firebase-tools
FlutterFire CLI: dart pub global activate flutterfire_cli
Node.js (for secure_quiz/functions)
Project setup (from E:\MobileDev\Final_Project\secure_quiz):

Install deps: flutter pub get
Configure Firebase for platforms (generates lib/firebase_options.dart + platform files): flutterfire configure
Ensure Android config exists: android/app/google-services.json (your firebase.json is already wired to output this)
Deploy Firebase rules:
firebase deploy --only firestore:rules,storage
(Optional, if you use Cloud Functions parsing) deploy functions:
cd functions
npm install
cd ..
firebase deploy --only functions
Run:

Web: flutter run -d chrome
Android (debug): flutter run -d <deviceId>
Release APK: flutter build apk --release
Output: build/app/outputs/flutter-apk/app-release.apk
First-use data (important):

After signup, a Firestore doc is expected at users/{uid} with:
role: teacher or student
batch: required for student (used to restrict quiz access)
Quizzes also store batch and students can only read/attempt quizzes matching their batch (enforced in firestore.rules).
Feature List

Authentication:

Email/password signup + login (Firebase Auth)
Role-based routing (teacher / student) via Firestore users/{uid}.role
Batch/Class restriction:

Students are assigned a batch
Students can only see/attempt quizzes for the same batch (UI + Firestore rules + quiz screen guard)
Teacher features:

Create quizzes by uploading .xlsx or .csv (parses into quizzes/{id}/questions)
Manage quizzes (active/upcoming/completed views depending on your UI)
Quiz preview mode (teacher opens quiz without creating an attempt)
Quiz insights/analytics:
Per-student scores
Violations count
Auto-submitted attempts identification
Average/highest/lowest score
Export results as CSV (web-supported exporter)
Student features:

Student dashboard lists quizzes for their batch
Take quiz with autosave and timer
Results screen after submit/auto-submit/disqualification
Secure attempt / anti-cheating:

Screenshot/screen recording protection (where supported) via screen_protector
App background/switch detection (mobile)
Web tab-visibility/security hooks (web)
Violation logging + thresholds (flag/disqualify) + auto-submit reasons
Android immersive mode during quiz to avoid system nav overlap
Architecture & UX:

Provider-based state management (AuthViewModel)
Micro-interactions (press-scale + fade/slide-in widgets)
Basic widget tests added for key login/signup flows
