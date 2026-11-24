import 'package:flutter/material.dart';
import '../theme/cores.dart';

enum TipoSelo {
  tenho,
  falta,
  naoConferido,
  publicada,
  privada,
  destaque,
}

/// Selo de estado com ícone e texto combinados (RNF-06: estado nunca apenas por cor).
class SeloEstado extends StatelessWidget {
  final TipoSelo tipo;
  final String? textoCustomizado;

  const SeloEstado({
    super.key,
    required this.tipo,
    this.textoCustomizado,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icone;
    final String textoPadrao;
    final Color corFundo;
    final Color corTexto;

    switch (tipo) {
      case TipoSelo.tenho:
        icone = Icons.check_circle_outline;
        textoPadrao = 'Tenho';
        corFundo = CoresApp.successBg;
        corTexto = CoresApp.success;
        break;
      case TipoSelo.falta:
        icone = Icons.cancel_outlined;
        textoPadrao = 'Falta';
        corFundo = CoresApp.errorBg;
        corTexto = CoresApp.error;
        break;
      case TipoSelo.naoConferido:
        icone = Icons.radio_button_unchecked;
        textoPadrao = 'Não conferido';
        corFundo = CoresApp.orange50;
        corTexto = CoresApp.inkSoft;
        break;
      case TipoSelo.publicada:
        icone = Icons.public;
        textoPadrao = 'Pública';
        corFundo = CoresApp.yellow100;
        corTexto = CoresApp.orange800;
        break;
      case TipoSelo.privada:
        icone = Icons.lock_outline;
        textoPadrao = 'Privada';
        corFundo = CoresApp.disabledBg;
        corTexto = CoresApp.inkSoft;
        break;
      case TipoSelo.destaque:
        icone = Icons.star;
        textoPadrao = 'Destaque';
        corFundo = CoresApp.yellow300;
        corTexto = CoresApp.orange800;
        break;
    }

    final rotulo = textoCustomizado ?? textoPadrao;

    return Semantics(
      label: 'Estado: $rotulo',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: corFundo,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 16, color: corTexto),
            const SizedBox(width: 6),
            Text(
              rotulo,
              style: TextStyle(
                color: corTexto,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
