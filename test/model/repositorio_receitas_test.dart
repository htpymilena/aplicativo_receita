import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_receitas/model/repositorios/banco_dados.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';
import 'package:app_receitas/model/servicos/gerenciador_fotos.dart';
import 'package:app_receitas/model/servicos/rascunho_receita.dart';

class SeletorMock implements SeletorGaleria {
  String? caminhoRetorno;
  @override
  Future<String?> escolherFoto() async => caminhoRetorno;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  final banco = BancoDados.instancia;
  late RepositorioReceitas repo;
  late GerenciadorFotos gerenciadorFotos;
  late SeletorMock seletorMock;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('receitas_repo_test_');
    dbPath = '${tempDir.path}/test_receitas.db';
    banco.customFactory = databaseFactoryFfi;
    await banco.inicializar(customPath: dbPath);
    repo = RepositorioReceitas(bancoDados: banco);
    seletorMock = SeletorMock();
    gerenciadorFotos = GerenciadorFotos(
      seletor: seletorMock,
      pastaBaseTeste: tempDir.path,
    );
  });

  tearDown(() async {
    await banco.fechar();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('2.1 a 2.4 RepositorioReceitas e 3.1 a 3.3 GerenciadorFotos', () {
    test('2.1 Criação transacional de receita própria com versão 1, itens e etapas', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      const rascunho = RascunhoReceita(
        titulo: 'Panqueca de Banana',
        itens: [
          RascunhoItemReceita(nomeIngrediente: 'Banana', medida: '2 unidades'),
          RascunhoItemReceita(nomeIngrediente: 'Ovo', medida: '1 unidade'),
        ],
        etapas: [
          'Amasse as bananas.',
          'Misture com o ovo e asse.',
        ],
      );

      final completa = await repo.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: rascunho,
      );

      expect(completa.receita.idAutor, equals(autor.idUsuario));
      expect(completa.receita.origem, equals('usuario'));
      expect(completa.receita.visibilidade, equals('privada'));
      expect(completa.versao.numeroVersao, equals(1));
      expect(completa.versao.titulo, equals('Panqueca de Banana'));
      expect(completa.versao.categoria, equals('Sem categoria'));
      expect(completa.itens.length, equals(2));
      expect(completa.etapas.length, equals(2));
    });

    test('2.2 Listagem filtrada por autor e leitura detalhada da versão mais recente', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      // Criar receita para o autor
      await repo.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Bolo de Milho',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Milho', medida: '1 lata')],
          etapas: ['Bata no liquidificador e asse.'],
        ),
      );

      // Criar outro usuário no banco
      await banco.database!.insert('usuario', {
        'id_usuario': 'outro-autor',
        'nome_exibicao': 'Outro Chefe',
        'email': 'outro@teste.com',
        'perfil': 'usuario',
      });

      // Criar receita para outro autor
      await repo.criarReceitaPropria(
        idAutor: 'outro-autor',
        rascunho: const RascunhoReceita(
          titulo: 'Torta de Limão',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Limão', medida: '3 unidades')],
          etapas: ['Esprema os limões.'],
        ),
      );

      // Listar receitas do autor ativo
      final lista = await repo.listarReceitasProprias(autor.idUsuario);
      expect(lista.length, equals(1));
      expect(lista.first.titulo, equals('Bolo de Milho'));

      // Leitura completa por ID
      final completa = await repo.obterReceitaPorId(
        idReceita: lista.first.idReceita,
        idAutor: autor.idUsuario,
      );
      expect(completa, isNotNull);
      expect(completa!.itens.first.nomeIngrediente, equals('Milho'));
      expect(completa.etapas.first.instrucao, equals('Bata no liquidificador e asse.'));
    });

    test('2.3 Edição cria nova versão (v2) preservando a anterior', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      final v1 = await repo.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Suco Natural',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Laranja', medida: '2 unidades')],
          etapas: ['Esprema as laranjas.'],
        ),
      );

      // Criar nova versão (v2) alterando ingrediente e etapa
      final v2 = await repo.criarNovaVersao(
        idReceita: v1.receita.idReceita,
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Suco Natural com Hortelã',
          itens: [
            RascunhoItemReceita(nomeIngrediente: 'Laranja', medida: '3 unidades'),
            RascunhoItemReceita(nomeIngrediente: 'Hortelã', medida: 'a gosto'),
          ],
          etapas: [
            'Esprema as laranjas.',
            'Adicione as folhas de hortelã e gelo.',
          ],
        ),
      );

      expect(v2.versao.numeroVersao, equals(2));
      expect(v2.versao.titulo, equals('Suco Natural com Hortelã'));
      expect(v2.itens.length, equals(2));

      // Versão mais recente lida pelo repositório é v2
      final atual = await repo.obterReceitaPorId(
        idReceita: v1.receita.idReceita,
        idAutor: autor.idUsuario,
      );
      expect(atual!.versao.numeroVersao, equals(2));

      // A versão 1 ainda existe no banco
      final versoesNoBanco = await banco.database!.query(
        'versao_receita',
        where: 'id_receita = ?',
        whereArgs: [v1.receita.idReceita],
      );
      expect(versoesNoBanco.length, equals(2));
    });

    test('2.4 Exclusão lógica oculta das listas e preenche excluida_em', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      final r = await repo.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Receita para Excluir',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Café', medida: '1 colher')],
          etapas: ['Passe o café.'],
        ),
      );

      final excluiu = await repo.excluirReceitaLogica(
        idReceita: r.receita.idReceita,
        idAutor: autor.idUsuario,
      );
      expect(excluiu, isTrue);

      // Não aparece na listagem
      final lista = await repo.listarReceitasProprias(autor.idUsuario);
      expect(lista.isEmpty, isTrue);

      // Não abre pela leitura comum
      final lida = await repo.obterReceitaPorId(
        idReceita: r.receita.idReceita,
        idAutor: autor.idUsuario,
      );
      expect(lida, isNull);

      // No banco de dados, o registro existe com excluida_em preenchido
      final noBanco = await banco.database!.query(
        'receita',
        where: 'id_receita = ?',
        whereArgs: [r.receita.idReceita],
      );
      expect(noBanco.first['excluida_em'], isNotNull);
    });

    test('3.1, 3.2 e 3.3 GerenciadorFotos copia para pasta do app e resolve caminho', () async {
      // Criar arquivo temporário simulando imagem da galeria
      final tempImg = File('${tempDir.path}/foto_teste.png');
      tempImg.writeAsStringSync('dummy image data');

      final caminhoRelativo = await gerenciadorFotos.copiarParaApp(tempImg.path);
      expect(caminhoRelativo, startsWith('fotos_receitas/'));

      final caminhoCompleto = await gerenciadorFotos.resolverCaminhoCompleto(caminhoRelativo);
      expect(caminhoCompleto, isNotNull);
      expect(File(caminhoCompleto!).existsSync(), isTrue);

      // Limpeza de cópia recente
      await gerenciadorFotos.limparCopiaRecente(caminhoRelativo);
      expect(File(caminhoCompleto).existsSync(), isFalse);
    });

    test('2.5 RepositorioReceitas fallback em memória quando banco não está aberto (Web)', () async {
      // Repositório forçado em memória simulando ambiente Web
      final repoWeb = RepositorioReceitas(forcarMemoria: true);
      RepositorioReceitas.limparMemoriaWeb();

      const rascunho = RascunhoReceita(
        titulo: 'Torta de Morango Web',
        itens: [RascunhoItemReceita(nomeIngrediente: 'Morango', medida: '1 caixa')],
        etapas: ['Lave os morangos.'],
      );

      final criada = await repoWeb.criarReceitaPropria(
        idAutor: 'usuario-web-provisorio',
        rascunho: rascunho,
        caminhoFotoRelativo: 'https://exemplo.com/morango.jpg',
      );

      expect(criada.versao.titulo, equals('Torta de Morango Web'));
      expect(criada.versao.fotoLocal, equals('https://exemplo.com/morango.jpg'));

      final lista = await repoWeb.listarReceitasProprias('usuario-web-provisorio');
      expect(lista.length, equals(1));
      expect(lista.first.titulo, equals('Torta de Morango Web'));

      final obtida = await repoWeb.obterReceitaPorId(
        idReceita: criada.receita.idReceita,
        idAutor: 'usuario-web-provisorio',
      );
      expect(obtida, isNotNull);

      // Nova versão em memória
      final v2 = await repoWeb.criarNovaVersao(
        idReceita: criada.receita.idReceita,
        idAutor: 'usuario-web-provisorio',
        rascunho: const RascunhoReceita(
          titulo: 'Torta de Morango com Chantilly',
          itens: [
            RascunhoItemReceita(nomeIngrediente: 'Morango', medida: '1 caixa'),
            RascunhoItemReceita(nomeIngrediente: 'Chantilly', medida: '1 xícara'),
          ],
          etapas: ['Lave os morangos.', 'Cubra com chantilly.'],
        ),
      );
      expect(v2.versao.numeroVersao, equals(2));

      // Exclusão em memória
      final excluiu = await repoWeb.excluirReceitaLogica(
        idReceita: criada.receita.idReceita,
        idAutor: 'usuario-web-provisorio',
      );
      expect(excluiu, isTrue);

      final listaAposExcluir = await repoWeb.listarReceitasProprias('usuario-web-provisorio');
      expect(listaAposExcluir.isEmpty, isTrue);
    });
  });
}
