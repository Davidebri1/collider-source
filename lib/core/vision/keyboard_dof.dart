import 'package:flutter/widgets.dart';

/// v8.7: true while any text field has focus (keyboard up). The app blurs
/// what is behind (depth of field) the same way on every screen.
class KeyboardDof {
  KeyboardDof._();
  static final ValueNotifier<bool> active = ValueNotifier(false);
  static bool _on = false;
  static void install() {
    if (_on) return;
    _on = true;
    FocusManager.instance.addListener(() {
      final ctx = FocusManager.instance.primaryFocus?.context;
      final editing = ctx != null && (ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null);
      if (active.value != editing) active.value = editing;
    });
  }
}
