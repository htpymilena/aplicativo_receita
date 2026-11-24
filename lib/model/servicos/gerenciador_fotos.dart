import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Interface abstrata para permitir testes do seletor da galeria.
abstract class SeletorGaleria {
  Future<String?> escolherFoto();
}

class SeletorGaleriaPadrao implements SeletorGaleria {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<String?> escolherFoto() async {
    try {
      final XFile? arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1440,
        imageQuality: 85,
      );
      if (arquivo == null) return null;

      // No Web ou URLs/dados remotos, retorna o caminho do XFile diretamente
      if (kIsWeb ||
          arquivo.path.startsWith('http://') ||
          arquivo.path.startsWith('https://') ||
          arquivo.path.startsWith('blob:') ||
          arquivo.path.startsWith('data:image')) {
        return arquivo.path;
      }

      // No ambiente nativo (Android/iOS/Desktop), salva IMEDIATAMENTE na pasta permanente
      // de documentos do aplicativo para evitar que o arquivo temporário na pasta /cache
      // seja excluído pelo sistema operacional antes do usuário salvar a receita.
      final Directory baseDir = await getApplicationDocumentsDirectory();
      final pastaFotos = Directory(p.join(baseDir.path, 'fotos_receitas'));
      if (!pastaFotos.existsSync()) {
        pastaFotos.createSync(recursive: true);
      }

      final extensao = p.extension(arquivo.path).isNotEmpty
          ? p.extension(arquivo.path)
          : '.jpg';
      final nomeUnico = '${const Uuid().v4()}$extensao';
      final destinoFinal = File(p.join(pastaFotos.path, nomeUnico));

      // Salva usando XFile.saveTo (garante leitura segura mesmo de cache/content URIs)
      await arquivo.saveTo(destinoFinal.path);
      return destinoFinal.path;
    } catch (e) {
      debugPrint('Erro ao acessar a galeria e salvar foto: $e');
      return null;
    }
  }
}

/// Gerenciador de cópias e armazenamento local de fotos de receitas.
class GerenciadorFotos {
  final SeletorGaleria seletor;
  final String? pastaBaseTeste;

  GerenciadorFotos({
    SeletorGaleria? seletor,
    this.pastaBaseTeste,
  }) : seletor = seletor ?? SeletorGaleriaPadrao();

  Future<Directory> _obterDiretorioFotos() async {
    final Directory baseDir;
    if (pastaBaseTeste != null) {
      baseDir = Directory(pastaBaseTeste!);
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }
    final pastaFotos = Directory(p.join(baseDir.path, 'fotos_receitas'));
    if (!pastaFotos.existsSync()) {
      pastaFotos.createSync(recursive: true);
    }
    return pastaFotos;
  }

  /// Resolve um caminho relativo armazenado no banco para o caminho absoluto no dispositivo.
  /// No caso de links da Web, data URIs ou ambiente Web, retorna a própria URL.
  Future<String?> resolverCaminhoCompleto(String? caminhoRelativo) async {
    if (caminhoRelativo == null || caminhoRelativo.isEmpty) return null;
    if (caminhoRelativo.startsWith('http://') ||
        caminhoRelativo.startsWith('https://') ||
        caminhoRelativo.startsWith('//') ||
        caminhoRelativo.startsWith('www.') ||
        caminhoRelativo.startsWith('data:image') ||
        caminhoRelativo.startsWith('blob:') ||
        kIsWeb) {
      return caminhoRelativo;
    }
    final pastaFotos = await _obterDiretorioFotos();
    final nomeArquivo = p.basename(caminhoRelativo);
    final arquivo = File(p.join(pastaFotos.path, nomeArquivo));
    return arquivo.path;
  }

  /// Copia a foto temporária da galeria para a pasta do aplicativo e retorna o caminho relativo estável.
  /// Se for uma URL da Web, data URI ou ambiente Web, preserva o link diretamente sem operações de arquivo locais.
  Future<String> copiarParaApp(String caminhoTemporario) async {
    if (caminhoTemporario.startsWith('http://') ||
        caminhoTemporario.startsWith('https://') ||
        caminhoTemporario.startsWith('//') ||
        caminhoTemporario.startsWith('www.') ||
        caminhoTemporario.startsWith('data:image') ||
        caminhoTemporario.startsWith('blob:') ||
        kIsWeb) {
      return caminhoTemporario;
    }

    // Se já é um caminho relativo na pasta fotos_receitas, retorna diretamente normalizado
    if (caminhoTemporario.startsWith('fotos_receitas/') ||
        caminhoTemporario.startsWith('fotos_receitas\\')) {
      return caminhoTemporario.replaceAll('\\', '/');
    }

    // Se o caminho já aponta para um arquivo dentro de fotos_receitas (ex: salvo imediatamente na seleção)
    if (caminhoTemporario.contains('fotos_receitas')) {
      final nomeArquivo = p.basename(caminhoTemporario);
      return 'fotos_receitas/$nomeArquivo';
    }

    final pastaDestino = await _obterDiretorioFotos();
    final arquivoOrigem = File(caminhoTemporario);

    if (!await arquivoOrigem.exists()) {
      // Se não existe no caminho informado, verifica se já existe na pasta destino pelo nome do arquivo
      final nome = p.basename(caminhoTemporario);
      final possivelDestino = File(p.join(pastaDestino.path, nome));
      if (await possivelDestino.exists()) {
        return 'fotos_receitas/$nome';
      }
      throw FileSystemException(
        'Arquivo de imagem não encontrado. Por favor, selecione a foto novamente.',
        caminhoTemporario,
      );
    }

    final extensao = p.extension(caminhoTemporario).isNotEmpty
        ? p.extension(caminhoTemporario)
        : '.jpg';
    final nomeUnico = '${const Uuid().v4()}$extensao';
    final destinoFinal = File(p.join(pastaDestino.path, nomeUnico));

    await arquivoOrigem.copy(destinoFinal.path);
    return 'fotos_receitas/$nomeUnico';
  }

  /// Remove uma cópia recém-criada caso a transação com o banco de dados falhe.
  Future<void> limparCopiaRecente(String caminhoRelativo) async {
    if (caminhoRelativo.startsWith('http://') ||
        caminhoRelativo.startsWith('https://') ||
        caminhoRelativo.startsWith('//') ||
        caminhoRelativo.startsWith('www.') ||
        caminhoRelativo.startsWith('data:image') ||
        caminhoRelativo.startsWith('blob:') ||
        kIsWeb) {
      return;
    }
    try {
      final caminhoCompleto = await resolverCaminhoCompleto(caminhoRelativo);
      if (caminhoCompleto != null) {
        final f = File(caminhoCompleto);
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    } catch (e) {
      debugPrint('Aviso ao limpar cópia recente: $e');
    }
  }
}
