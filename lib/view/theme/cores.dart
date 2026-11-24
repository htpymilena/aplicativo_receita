import 'package:flutter/material.dart';

/// Tokens de cores fundamentados no guia de design (seções 3 e 4).
abstract class CoresApp {
  // 3.1 Neutros
  static const Color bg = Color(0xFFFFFBF5); // Branco quente
  static const Color surface = Color(0xFFFFFFFF); // Branco puro
  static const Color ink = Color(0xFF2B1B12); // Marrom escuro para texto principal e títulos
  static const Color inkSoft = Color(0xFF6A5546); // Texto secundário e legendas
  static const Color line = Color(0xFFE3CDB8); // Divisores decorativos
  static const Color lineStrong = Color(0xFF9C7B60); // Borda de campos e caixas
  static const Color disabled = Color(0xFFA8978A); // Elementos desabilitados
  static const Color disabledBg = Color(0xFFF0E6DC); // Fundo desabilitado

  // 3.2 Laranja (marca e ação)
  static const Color orange50 = Color(0xFFFFF4EB);
  static const Color orange100 = Color(0xFFFFE4CC);
  static const Color orange400 = Color(0xFFFB923C);
  static const Color orange500 = Color(0xFFF97316); // Botão primário (texto SEMPRE em ink)
  static const Color orange600 = Color(0xFFEA580C);
  static const Color orange700 = Color(0xFFC2410C); // Links, ícone ativo, texto laranja
  static const Color orange800 = Color(0xFF9A3412); // Foco acessível

  // 3.3 Amarelo (destaque)
  static const Color yellow100 = Color(0xFFFEF3C7);
  static const Color yellow300 = Color(0xFFFCD34D);
  static const Color yellow400 = Color(0xFFFBBF24);
  static const Color star = Color(0xFFF59E0B);

  // 3.4 Funcionais
  static const Color success = Color(0xFF1E7B3A);
  static const Color successBg = Color(0xFFE8F5EC);
  static const Color error = Color(0xFFB3261E);
  static const Color errorBg = Color(0xFFFDECEA);
}
