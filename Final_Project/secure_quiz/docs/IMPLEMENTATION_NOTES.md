# Secure Quiz Implementation Notes

## Implemented app features

- Firebase email/password login with role-based routing (`teacher` or `student`)
- Teacher quiz creation by uploading Excel and calling a Cloud Function parser
- Student dashboard with upcoming, active, and past quiz sections
- Secure quiz attempt session:
  - Screenshot/screen recording prevention hooks (platform-supported)
  - App switching/background detection
  - Violation logging to Firestore
  - Auto-flag/disqualify thresholds and auto-submit
  - Answer autosave to Firestore during quiz

## Firestore structure used by app

- `users/{uid}`
  - `role`: `teacher` | `student`
  - `displayName`, `email`, timestamps
- `quizzes/{quizId}`
  - `title`, `subject`, `batch`, `startAt`, `durationMinutes`
  - `createdBy`, `status`, `totalQuestions`, `totalPoints`, `filePath`
- `quizzes/{quizId}/questions/{questionId}`
  - `text`, `options[]`, `correctOption`, `points`, `order`
- `attempts/{quizId}_{studentId}`
  - `quizId`, `studentId`, `status`, `violationCount`, `answers{}`
- `attempts/{attemptId}/violations/{violationId}`
  - `type`, `details`, `createdAt`, `violationNumber`

## Cloud Function

Function: `parseQuizExcel`

Input:
- `quizId`
- `storagePath`

Expected spreadsheet columns (case-insensitive variants supported):
- `question`
- `optionA`, `optionB`, `optionC`, `optionD`
- `correctOption` (A/B/C/D or exact option text)
- `points`

## Security thresholds

Defined in `lib/services/attempt_service.dart`:
- Flag threshold: `2` violations
- Disqualification threshold: `4` violations

## Required setup before running

1. Configure Firebase for Flutter (`flutterfire configure`) and add platform config files.
2. Deploy rules:
   - `firebase deploy --only firestore:rules,storage`
3. Deploy functions:
   - `cd functions`
   - `npm install`
   - `firebase deploy --only functions`
4. Ensure users have role docs in `users/{uid}`.