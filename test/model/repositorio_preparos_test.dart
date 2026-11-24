import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_receitas/model/repositorios/banco_dados.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';
import 'package:app_receitas/model/repositorios/repositorio_preparos.dart';
import 'package:app_receitas/model/servicos/rascunho_receita.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  final banco = BancoDados.instancia;
  late RepositorioReceitas repoReceitas;
  late RepositorioPreparos repoPreparos;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('preparos_repo_test_');
    dbPath = '${tempDir.path}/test_preparos.db';
    banco.customFactory = databaseFactoryFfi;
    await banco.inicializar(customPath: dbPath);
    repoReceitas = RepositorioReceitas(bancoDados: banco);
    repoPreparos = RepositorioPreparos(bancoDados: banco);
  });

  tearDown(() async {
    await banco.fechar();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('1.1 a 1.4, 3.1 e 4.1 RepositorioPreparos', () {
    test('1.1 Início transacional de preparo e conferências na versão atual', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      const rascunho = RascunhoReceita(
        titulo: 'Bolo de Cenoura',
        itens: [
          RascunhoItemReceita(nomeIngrediente: 'Cenoura', medida: '3 unidades'),
          RascunhoItemReceita(nomeIngrediente: 'Farinha', medida: '2 xícaras'),
        ],
        etapas: [
          'Bata as cenouras no liquidificador.',
          'Misture a farinha e asse a 180°C.',
        ],
      );

      final recCriada = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: rascunho,
      );

      final preparo = await repoPreparos.iniciarPreparo(
        idUsuario: autor.idUsuario,
        idReceita: recCriada.receita.idReceita,
      );

      expect(preparo.preparo.idUsuario, autor.idUsuario);
      expect(preparo.preparo.idVersao, recCriada.versao.idVersao);
      expect(preparo.preparo.ordemEtapaAtual, 1);
      expect(preparo.preparo.concluidoEm, isNull);
      expect(preparo.conferencias.length, 2);
      expect(preparo.conferencias.every((c) => c.estado == 'nao_conferido'), isTrue);
      expect(preparo.totalItens, 2);
      expect(preparo.totalConferidos, 0);
      expect(preparo.etapas.length, 2);

      // Falha ao tentar iniciar receita inexistente ou de outro usuário
      await expectLater(
        repoPreparos.iniciarPreparo(idUsuario: 'outro_usuario', idReceita: recCriada.receita.idReceita),
        throwsA(isA<StateError>()),
      );
    });

    test('1.2 Consulta de preparo e isolamento de versão frente a edições posteriores', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      final recCriada = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Panqueca Simples',
          itens: [
            RascunhoItemReceita(nomeIngrediente: 'Ovo', medida: '1 unidade'),
          ],
          etapas: ['Frite na frigideira.'],
        ),
      );

      // Inicia preparo na versão 1
      final preparoV1 = await repoPreparos.iniciarPreparo(
        idUsuario: autor.idUsuario,
        idReceita: recCriada.receita.idReceita,
      );

      // Edita a receita criando a versão 2 com novos ingredientes e etapas
      await repoReceitas.criarNovaVersao(
        idReceita: recCriada.receita.idReceita,
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Panqueca Turbinada',
          itens: [
            RascunhoItemReceita(nomeIngrediente: 'Ovo', medida: '2 unidades'),
            RascunhoItemReceita(nomeIngrediente: 'Aveia', medida: '1 xícara'),
          ],
          etapas: ['Misture tudo.', 'Frite em fogo baixo.'],
        ),
      );

      // Consulta o preparo iniciado
      final detalhado = await repoPreparos.obterPreparoDetalhado(
        idPreparo: preparoV1.preparo.idPreparo,
        idUsuario: autor.idUsuario,
      );

      expect(detalhado, isNotNull);
      expect(detalhado!.versao.numeroVersao, 1);
      expect(detalhado.conferencias.length, 1);
      expect(detalhado.conferencias.first.nomeIngrediente, 'Ovo');
      expect(detalhado.etapas.length, 1);

      // Outro usuário não tem acesso ao preparo
      final outroUsuario = await repoPreparos.obterPreparoDetalhado(
        idPreparo: preparoV1.preparo.idPreparo,
        idUsuario: 'usuario_estranho',
      );
      expect(outroUsuario, isNull);
    });

    test('1.3 Alteração de conferência, avanço de etapa e persistência após reabrir o banco', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      final recCriada = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Suco Natural',
          itens: [
            RascunhoItemReceita(nomeIngrediente: 'Laranja', medida: '4 unidades'),
            RascunhoItemReceita(nomeIngrediente: 'Gelo', medida: 'a gosto'),
          ],
          etapas: ['Esprema as laranjas.', 'Adicione o gelo.'],
        ),
      );

      final prep = await repoPreparos.iniciarPreparo(
        idUsuario: autor.idUsuario,
        idReceita: recCriada.receita.idReceita,
      );

      final item1 = prep.conferencias[0].idItem;
      final item2 = prep.conferencias[1].idItem;

      // Altera item 1 para tenho e item 2 para falta
      await repoPreparos.atualizarConferencia(
        idPreparo: prep.preparo.idPreparo,
        idItem: item1,
        novoEstado: 'tenho',
        idUsuario: autor.idUsuario,
      );

      await repoPreparos.atualizarConferencia(
        idPreparo: prep.preparo.idPreparo,
        idItem: item2,
        novoEstado: 'falta',
        idUsuario: autor.idUsuario,
      );

      // Corrige item 2 para nao_conferido
      await repoPreparos.atualizarConferencia(
        idPreparo: prep.preparo.idPreparo,
        idItem: item2,
        novoEstado: 'nao_conferido',
        idUsuario: autor.idUsuario,
      );

      // Atualiza etapa atual para 2
      await repoPreparos.atualizarEtapaAtual(
        idPreparo: prep.preparo.idPreparo,
        novaOrdem: 2,
        idUsuario: autor.idUsuario,
      );

      // Tenta avançar além do total de etapas -> deve falhar
      await expectLater(
        repoPreparos.atualizarEtapaAtual(
          idPreparo: prep.preparo.idPreparo,
          novaOrdem: 3,
          idUsuario: autor.idUsuario,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Reabre o banco de dados para conferir persistência física
      await banco.fechar();
      await banco.inicializar(customPath: dbPath);

      final recarregado = await repoPreparos.obterPreparoDetalhado(
        idPreparo: prep.preparo.idPreparo,
        idUsuario: autor.idUsuario,
      );

      expect(recarregado, isNotNull);
      expect(recarregado!.preparo.ordemEtapaAtual, 2);
      expect(recarregado.conferencias.firstWhere((c) => c.idItem == item1).estado, 'tenho');
      expect(recarregado.conferencias.firstWhere((c) => c.idItem == item2).estado, 'nao_conferido');
    });

    test('1.4 Conclusão idempotente, novo preparo gera outro id', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      final recCriada = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Salada',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Alface', medida: '1 maço')],
          etapas: ['Lave e sirva.'],
        ),
      );

      final prep1 = await repoPreparos.iniciarPreparo(
        idUsuario: autor.idUsuario,
        idReceita: recCriada.receita.idReceita,
      );

      // Conclui preparo
      final concluidoEm1 = await repoPreparos.concluirPreparo(
        idPreparo: prep1.preparo.idPreparo,
        idUsuario: autor.idUsuario,
      );

      expect(concluidoEm1, isNotNull);

      // Conclusão repetida retorna a mesma data
      final concluidoEmRepetido = await repoPreparos.concluirPreparo(
        idPreparo: prep1.preparo.idPreparo,
        idUsuario: autor.idUsuario,
      );
      expect(concluidoEmRepetido, concluidoEm1);

      // Novo preparo da mesma receita gera ID diferente
      final prep2 = await repoPreparos.iniciarPreparo(
        idUsuario: autor.idUsuario,
        idReceita: recCriada.receita.idReceita,
      );
      expect(prep2.preparo.idPreparo, isNot(equals(prep1.preparo.idPreparo)));
      expect(prep2.preparo.concluidoEm, isNull);
    });

    test('3.1 Listagem de preparos em andamento, concluídos e receita excluída logicamente', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      final rec1 = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Receita 1',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Item 1', medida: '1')],
          etapas: ['Etapa 1'],
        ),
      );

      final rec2 = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Receita 2',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Item 2', medida: '2')],
          etapas: ['Etapa 2'],
        ),
      );

      // Inicia preparo 1 (será concluído)
      final prep1 = await repoPreparos.iniciarPreparo(idUsuario: autor.idUsuario, idReceita: rec1.receita.idReceita);
      await repoPreparos.concluirPreparo(idPreparo: prep1.preparo.idPreparo, idUsuario: autor.idUsuario);

      // Inicia preparo 2 (ficará em andamento)
      final prep2 = await repoPreparos.iniciarPreparo(idUsuario: autor.idUsuario, idReceita: rec2.receita.idReceita);

      // Exclui logicamente a receita 1
      await repoReceitas.excluirReceitaLogica(idReceita: rec1.receita.idReceita, idAutor: autor.idUsuario);

      final andamento = await repoPreparos.listarPreparosEmAndamento(idUsuario: autor.idUsuario);
      final concluidos = await repoPreparos.listarPreparosConcluidos(idUsuario: autor.idUsuario);

      // Andamento deve conter apenas prep2
      expect(andamento.length, 1);
      expect(andamento.first.idPreparo, prep2.preparo.idPreparo);
      expect(andamento.first.receitaExcluida, isFalse);

      // Concluídos deve conter prep1 com indicação de receita excluída
      expect(concluidos.length, 1);
      expect(concluidos.first.idPreparo, prep1.preparo.idPreparo);
      expect(concluidos.first.receitaExcluida, isTrue);
    });

    test('4.1 Avaliação pessoal de preparo concluído (1 a 5 estrelas, privada)', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      final rec = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Biscoito',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Trigo', medida: '100g')],
          etapas: ['Asse por 15 min.'],
        ),
      );

      final prep = await repoPreparos.iniciarPreparo(idUsuario: autor.idUsuario, idReceita: rec.receita.idReceita);

      // Tentativa de avaliar preparo em andamento deve falhar
      await expectLater(
        repoPreparos.salvarAvaliacao(idPreparo: prep.preparo.idPreparo, idUsuario: autor.idUsuario, estrelas: 5),
        throwsA(isA<StateError>()),
      );

      // Conclui o preparo
      await repoPreparos.concluirPreparo(idPreparo: prep.preparo.idPreparo, idUsuario: autor.idUsuario);

      // Avaliação fora do intervalo deve falhar
      await expectLater(
        repoPreparos.salvarAvaliacao(idPreparo: prep.preparo.idPreparo, idUsuario: autor.idUsuario, estrelas: 0),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repoPreparos.salvarAvaliacao(idPreparo: prep.preparo.idPreparo, idUsuario: autor.idUsuario, estrelas: 6),
        throwsA(isA<ArgumentError>()),
      );

      // Salva avaliação válida de 4 estrelas
      final aval1 = await repoPreparos.salvarAvaliacao(
        idPreparo: prep.preparo.idPreparo,
        idUsuario: autor.idUsuario,
        estrelas: 4,
      );
      expect(aval1.estrelas, 4);
      expect(aval1.visibilidade, 'privada');

      // Atualiza a mesma avaliação para 5 estrelas
      final aval2 = await repoPreparos.salvarAvaliacao(
        idPreparo: prep.preparo.idPreparo,
        idUsuario: autor.idUsuario,
        estrelas: 5,
      );
      expect(aval2.estrelas, 5);

      // Confere via preparo detalhado
      final detalhe = await repoPreparos.obterPreparoDetalhado(
        idPreparo: prep.preparo.idPreparo,
        idUsuario: autor.idUsuario,
      );
      expect(detalhe?.avaliacao?.estrelas, 5);
    });
  });
}
