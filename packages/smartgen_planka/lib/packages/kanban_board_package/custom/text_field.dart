import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Provider/provider_list.dart';

class TField extends ConsumerStatefulWidget {
  const TField({super.key, this.onSubmitted});

  final void Function(String value)? onSubmitted;

  @override
  ConsumerState<TField> createState() => _TFieldState();
}

class _TFieldState extends ConsumerState<TField> {
  final FocusNode node = FocusNode();

  @override
  void initState() {
    super.initState();
    // Web + semantics: autofocus alone often never attaches the DOM input.
    // Match Add Card — explicit post-frame requestFocus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node.requestFocus();
    });
  }

  @override
  void dispose() {
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = ref.read(ProviderList.boardProvider);
    return TextFormField(
      decoration: const InputDecoration(
        enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide.none),
        disabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
      ),
      autofocus: true,
      enabled: true,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.text,
      style: prov.board.textStyle,
      controller: prov.board.newCardTextController,
      focusNode: node,
      onFieldSubmitted: (value) {
        widget.onSubmitted?.call(value);
      },
    );
  }
}
