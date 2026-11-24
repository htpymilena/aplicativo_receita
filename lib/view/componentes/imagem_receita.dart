import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../theme/cores.dart';

/// Componente que renderiza imagens de receitas de forma multiplataforma (Web e Nativo).
/// Suporta URLs de internet (http/https), dados base64 (data:image), URLs de blob (Web) e arquivos locais (Android/Desktop).
class ImagemReceita extends StatelessWidget {
  final String? caminhoOuUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const ImagemReceita({
    super.key,
    required this.caminhoOuUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (caminhoOuUrl == null || caminhoOuUrl!.trim().isEmpty) {
      return _construirPlaceholder();
    }

    final caminho = caminhoOuUrl!.trim();

    // 1. Imagem em Base64 (data:image)
    if (caminho.startsWith('data:image')) {
      try {
        final commaIndex = caminho.indexOf(',');
        if (commaIndex != -1) {
          final base64Str = caminho.substring(commaIndex + 1);
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _construirPlaceholder(),
          );
        }
      } catch (_) {
        return _construirPlaceholder();
      }
    }

    // 2. URLs da Web (http, https, //, www. ou blob no Flutter Web)
    if (caminho.startsWith('http://') ||
        caminho.startsWith('https://') ||
        caminho.startsWith('//') ||
        caminho.startsWith('www.') ||
        (kIsWeb && caminho.startsWith('blob:'))) {
      final urlFinal = caminho.startsWith('//')
          ? 'https:$caminho'
          : (caminho.startsWith('www.') ? 'https://$caminho' : caminho);
      return Image.network(
        urlFinal,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _construirPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: CoresApp.orange50,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }

    // 3. Arquivo local no dispositivo nativo (Android, Windows, etc.)
    if (!kIsWeb) {
      if (caminho.startsWith('fotos_receitas/') || caminho.startsWith('fotos_receitas\\')) {
        return FutureBuilder<Directory>(
          future: getApplicationDocumentsDirectory().catchError((_) => Directory('')),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.path.isEmpty) {
              return _construirPlaceholder();
            }
            final baseDir = snapshot.data!;
            final arquivo = File(p.join(baseDir.path, caminho));
            if (arquivo.existsSync()) {
              return Image.file(
                arquivo,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (context, error, stackTrace) => _construirPlaceholder(),
              );
            }
            return _construirPlaceholder();
          },
        );
      }

      try {
        final arquivo = File(caminho);
        if (arquivo.existsSync()) {
          return Image.file(
            arquivo,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _construirPlaceholder(),
          );
        }
      } catch (_) {
        return _construirPlaceholder();
      }
    }

    return _construirPlaceholder();
  }

  Widget _construirPlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = (constraints.maxHeight < 90 && constraints.maxHeight > 0) ||
            (height != null && height! < 90);
        return Container(
          width: width,
          height: height,
          color: CoresApp.orange100,
          child: Center(
            child: compact
                ? const Icon(
                    Icons.restaurant_menu,
                    size: 32,
                    color: CoresApp.orange700,
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 40,
                        color: CoresApp.orange700,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Sem foto cadastrada',
                        style: TextStyle(
                          color: CoresApp.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
