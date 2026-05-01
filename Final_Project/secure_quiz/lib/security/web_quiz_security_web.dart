// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

class WebQuizSecurityBinding {
  WebQuizSecurityBinding(this._subscriptions);

  final List<StreamSubscription<dynamic>> _subscriptions;

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
  }
}

WebQuizSecurityBinding installWebQuizSecurity({
  required void Function(String type, String details) onViolation,
}) {
  final subs = <StreamSubscription<dynamic>>[];

  subs.add(
    html.document.onVisibilityChange.listen((_) {
      if (html.document.hidden == true) {
        onViolation(
          'tab_switch',
          'Document became hidden. Possible tab switch or app switch.',
        );
      }
    }),
  );

  subs.add(
    html.window.onBlur.listen((_) {
      onViolation('tab_switch', 'Window lost focus during quiz.');
    }),
  );

  subs.add(
    html.document.onCopy.listen((event) {
      event.preventDefault();
      onViolation('copy_attempt', 'Copy shortcut/menu was attempted.');
    }),
  );

  subs.add(
    html.document.onCut.listen((event) {
      event.preventDefault();
      onViolation('copy_attempt', 'Cut shortcut/menu was attempted.');
    }),
  );

  subs.add(
    html.document.onContextMenu.listen((event) {
      event.preventDefault();
      onViolation('context_menu', 'Context menu open attempt detected.');
    }),
  );

  subs.add(
    html.window.onKeyDown.listen((event) {
      final key = event.key?.toLowerCase() ?? '';
      final ctrl = event.ctrlKey;
      final meta = event.metaKey;
      final shift = event.shiftKey;

      final isCopyShortcut =
          (ctrl || meta) &&
          (key == 'c' ||
              key == 'x' ||
              key == 'v' ||
              key == 'a' ||
              key == 'p' ||
              key == 's' ||
              key == 'u');
      final isDevtoolsShortcut =
          key == 'f12' || ((ctrl || meta) && shift && key == 'i');
      final isPrintScreen = key == 'printscreen';

      if (isCopyShortcut) {
        event.preventDefault();
        onViolation('copy_attempt', 'Restricted keyboard shortcut was used.');
        return;
      }

      if (isDevtoolsShortcut) {
        event.preventDefault();
        onViolation(
          'devtools_attempt',
          'Developer tools shortcut was attempted.',
        );
        return;
      }

      if (isPrintScreen) {
        onViolation('screenshot', 'Print Screen key pressed on web.');
      }
    }),
  );

  return WebQuizSecurityBinding(subs);
}
