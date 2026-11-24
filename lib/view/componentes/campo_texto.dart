import 'package:flutter/material.dart';
import '../theme/cores.dart';

/// Campo de texto acessível com alvo de toque adequado e rótulos claros.
class CampoTextoApp extends StatelessWidget {
  final String label;
  final String? dica;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? erro;
  final Widget? prefixo;
  final Widget? sufixo;
  final bool obscureText;
  final TextInputType? keyboardType;

  const CampoTextoApp({
    super.key,
    required this.label,
    this.dica,
    this.controller,
    this.onChanged,
    this.erro,
    this.prefixo,
    this.sufixo,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: CoresApp.ink,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: dica,
          errorText: erro,
          prefixIcon: prefixo,
          suffixIcon: sufixo,
        ),
      ),
    );
  }
}
