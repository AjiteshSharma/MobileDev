class WebQuizSecurityBinding {
  void dispose() {}
}

WebQuizSecurityBinding installWebQuizSecurity({
  required void Function(String type, String details) onViolation,
}) {
  return WebQuizSecurityBinding();
}
