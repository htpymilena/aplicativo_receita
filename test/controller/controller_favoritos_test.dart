import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/controller/controller_favoritos.dart';
import 'package:app_receitas/model/repositorios/repositorio_favoritos.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';

// Repositório simulado para testar concorrência e tratamento de falhas
class MockRepositorioFavoritos extends RepositorioFavoritos {
  MockRepositorioFavoritos() : super(forcarMemoria: true);

  bool falharAoAdicionar = false;
  int delayMs = 0;
  final Set<String> favoritosSimulados = {};

  @override
  Future<bool> ehFavorito({required String idUsuario, required String idReceita}) async {
    return favoritosSimulados.contains(idReceita);
  }

  @override
  Future<void> adicionarFavorito({
    required String idUsuario,
    required String idReceita,
    DateTime? salvoEm,
  }) async {
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    if (falharAoAdicionar) {
      throw StateError('Falha simulada na escrita');
    }
    favoritosSimulados.add(idReceita);
  }

  @override
  Future<void> removerFavorito({
    required String idUsuario,
    required String idReceita,
  }) async {
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    favoritosSimulados.remove(idReceita);
  }

  @override
  Future<List<ReceitaResumo>> listarFavoritos(String idUsuario) async {
    return favoritosSimulados.map((id) {
      return ReceitaResumo(
        idReceita: id,
        titulo: 'Receita $id',
        categoria: 'Geral',
        numeroVersao: 1,
      );
    }).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRepositorioFavoritos mockRepo;
  late ControllerFavoritos controller;

  setUp(() {
    mockRepo = MockRepositorioFavoritos();
    controller = ControllerFavoritos(repositorio: mockRepo);
  });

  group('3.1 ControllerFavoritos', () {
    test('Alternância com sucesso e estado compartilhado', () async {
      await controller.trocarUsuario('user_1');
      expect(controller.isFavorito('rec_1'), isFalse);

      // Alterna para favoritar
      final res1 = await controller.alternarFavorito('rec_1');
      expect(res1, isTrue);
      expect(controller.isFavorito('rec_1'), isTrue);
      expect(controller.favoritos.length, 1);
      expect(controller.favoritos.first.idReceita, 'rec_1');

      // Alterna novamente para remover
      final res2 = await controller.alternarFavorito('rec_1');
      expect(res2, isTrue);
      expect(controller.isFavorito('rec_1'), isFalse);
      expect(controller.favoritos.isEmpty, isTrue);
    });

    test('Bloqueio de escrita concorrente para a mesma receita', () async {
      await controller.trocarUsuario('user_1');
      mockRepo.delayMs = 50;

      // Inicia a primeira alternância
      final f1 = controller.alternarFavorito('rec_1');
      expect(controller.estaProcessando('rec_1'), isTrue);

      // Tentativa simultânea para a mesma receita deve ser bloqueada
      final f2 = controller.alternarFavorito('rec_1');
      final res2 = await f2;
      expect(res2, isFalse); // Bloqueado!

      final res1 = await f1;
      expect(res1, isTrue);
      expect(controller.estaProcessando('rec_1'), isFalse);
      expect(controller.isFavorito('rec_1'), isTrue);
    });

    test('Tratamento de erro restaura estado anterior', () async {
      await controller.trocarUsuario('user_1');
      mockRepo.falharAoAdicionar = true;

      expect(controller.isFavorito('rec_falha'), isFalse);

      // Tentativa de favoritar falha
      final res = await controller.alternarFavorito('rec_falha');
      expect(res, isFalse);
      expect(controller.erro, contains('Falha simulada na escrita'));
      // Estado deve ser restaurado para falso
      expect(controller.isFavorito('rec_falha'), isFalse);
    });

    test('Recarga ao trocar usuário isola estado', () async {
      await controller.trocarUsuario('user_1');
      await controller.alternarFavorito('rec_user1');
      expect(controller.isFavorito('rec_user1'), isTrue);

      // Troca para outro usuário
      mockRepo.favoritosSimulados.clear();
      await controller.trocarUsuario('user_2');
      expect(controller.isFavorito('rec_user1'), isFalse);
      expect(controller.favoritos.isEmpty, isTrue);
    });
  });
}
