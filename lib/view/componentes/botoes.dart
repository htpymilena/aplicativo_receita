import 'package:flutter/material.dart';
import '../theme/cores.dart';

/// Botão primário com altura de 56 dp, fundo laranja e texto escuro ink (WCAG 5,91:1).
class BotaoPrimario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final String? motivoDesabilitado;
  final Widget? icone;

  const BotaoPrimario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.motivoDesabilitado,
    this.icone,
  });

  bool get estaHabilitado => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final botao = SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: CoresApp.orange500,
          foregroundColor: CoresApp.ink,
          disabledBackgroundColor: CoresApp.disabledBg,
          disabledForegroundColor: CoresApp.disabled,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icone != null) ...[
              icone!,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                texto,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if (!estaHabilitado && motivoDesabilitado != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          botao,
          const SizedBox(height: 6),
          Semantics(
            container: true,
            child: Text(
              motivoDesabilitado!,
              style: const TextStyle(
                color: CoresApp.inkSoft,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return botao;
  }
}

/// Botão secundário com borda laranja-escuro e fundo surface.
class BotaoSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final Widget? icone;

  const BotaoSecundario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: CoresApp.surface,
          foregroundColor: CoresApp.orange700,
          disabledForegroundColor: CoresApp.disabled,
          side: const BorderSide(color: CoresApp.orange700, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icone != null) ...[
              icone!,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                texto,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão terciário (link de texto) com alvo de toque mínimo de 48x48 dp.
class BotaoTerciario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;

  const BotaoTerciario({
    super.key,
    required this.texto,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: CoresApp.orange700,
          disabledForegroundColor: CoresApp.disabled,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(texto),
      ),
    );
  }
}
