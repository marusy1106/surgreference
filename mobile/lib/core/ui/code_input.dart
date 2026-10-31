import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme.dart';

/// Ввод 6-значного кода из письма: ячейки поверх невидимого поля. Поддерживает вставку и автоподстановку кода.
class CodeInput extends StatefulWidget {
  const CodeInput({super.key, required this.controller, this.onCompleted, this.autofocus = true, this.enabled = true});

  static const length = 6;

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;
  final bool enabled;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final code = value.text;
        return Semantics(
          label: 'Код подтверждения, введено ${code.length} из ${CodeInput.length} цифр',
          textField: true,
          child: GestureDetector(
            onTap: _focus.requestFocus,
            child: Stack(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < CodeInput.length; i++) ...[
                      if (i > 0) const SizedBox(width: SrSpace.s),
                      Expanded(
                        child: _Cell(
                          digit: i < code.length ? code[i] : null,
                          active: widget.enabled && i == code.length.clamp(0, CodeInput.length - 1),
                        ),
                      ),
                    ],
                  ],
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: ExcludeSemantics(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        autofocus: widget.autofocus,
                        enabled: widget.enabled,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        showCursor: false,
                        enableInteractiveSelection: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(CodeInput.length),
                        ],
                        onChanged: (text) {
                          if (text.length == CodeInput.length) widget.onCompleted?.call(text);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.digit, required this.active});

  final String? digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return AspectRatio(
      aspectRatio: 0.8,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? c.accent : c.line, width: active ? 2 : 1),
        ),
        child: digit == null ? null : FittedBox(child: Text(digit!, style: Theme.of(context).textTheme.headlineMedium)),
      ),
    );
  }
}
