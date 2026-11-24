import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_receitas/model/repositorios/banco_dados.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';
import 'package:app_receitas/model/repositorios/repositorio_preparos.dart';
import 'package:app_receitas/model/servicos/rascunho_receita.dart';
import 'package:app_receitas/controller/controller_preparo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  final banco = BancoDados.instancia;
  late RepositorioReceitas repoReceitas;
  late RepositorioPreparos repoPreparos;
  late ControllerPreparo controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('controller_preparo_test_');
    dbPath = '${tempDir.path}/test_ctrl_preparos.db';
    banco.customFactory = databaseFactoryFfi;
    await banco.inicializar(customPath: dbPath);
    repoReceitas = RepositorioReceitas(bancoDados: banco);
    repoPreparos = RepositorioPreparos(bancoDados: banco);
    controller = ControllerPreparo(repositorio: repoPreparos, bancoDados: banco);
  });

  tearDown(() async {
    await banco.fechar();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('2.1 ControllerPreparo', () {
    test('Bloqueio de início duplicado, contadores e alteração com atualização imediata', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      final rec = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Omelete de Ervas',
          itens: [
            RascunhoItemReceita(nomeIngrediente: 'Ovo', medida: '2 unidades'),
            RascunhoItemReceita(nomeIngrediente: 'Orégano', medida: 'a gosto'),
          ],
          etapas: ['Bata os ovos.', 'Frite em fogo brando.'],
        ),
      );

      // Inicia receita
      final prep = await controller.iniciarReceita(rec.receita.idReceita);
      expect(prep, isNotNull);
      expect(controller.totalItens, 2);
      expect(controller.totalConferidos, 0);
      expect(controller.totalTenho, 0);
      expect(controller.totalFalta, 0);
      expect(controller.temFaltantes, isFalse);

      final item1 = prep!.conferencias[0].idItem;
      final item2 = prep.conferencias[1].idItem;

      // Altera item 1 para tenho
      await controller.alterarConferencia(item1, 'tenho');
      expect(controller.totalConferidos, 1);
      expect(controller.totalTenho, 1);
      expect(controller.totalFalta, 0);

      // Altera item 2 para falta
      await controller.alterarConferencia(item2, 'falta');
      expect(controller.totalConferidos, 2);
      expect(controller.totalTenho, 1);
      expect(controller.totalFalta, 1);
      expect(controller.temFaltantes, isTrue);

      // Avança etapa
      expect(controller.etapaAtual, 1);
      await controller.mudarEtapa(2);
      expect(controller.etapaAtual, 2);

      // Conclui preparo
      final ok = await controller.concluirPreparo();
      expect(ok, isTrue);
      expect(controller.preparoAtual?.preparo.concluidoEm, isNotNull);
    });
  });
}
