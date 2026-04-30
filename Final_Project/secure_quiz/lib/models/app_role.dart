enum AppRole { teacher, student, unknown }

AppRole appRoleFromDynamic(dynamic rawRole) {
  if (rawRole == null) {
    return AppRole.unknown;
  }

  final normalized = rawRole.toString().trim().toLowerCase();
  switch (normalized) {
    case 'teacher':
      return AppRole.teacher;
    case 'student':
      return AppRole.student;
    default:
      return AppRole.unknown;
  }
}

extension AppRoleValue on AppRole {
  String get firestoreValue {
    switch (this) {
      case AppRole.teacher:
        return 'teacher';
      case AppRole.student:
        return 'student';
      case AppRole.unknown:
        return 'unknown';
    }
  }
}
