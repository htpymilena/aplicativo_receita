import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_receitas/model/entidades/entidades.dart';
import 'package:app_receitas/model/repositorios/banco_dados.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';
import 'package:app_receitas/model/repositorios/repositorio_preparos.dart';
import 'package:app_receitas/model/repositorios/repositorio_favoritos.dart';
import 'package:app_receitas/model/servicos/rascunho_receita.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  final banco = BancoDados.instancia;
  late RepositorioReceitas repoReceitas;
  late RepositorioPreparos repoPreparos;
  late RepositorioFavoritos repoFavoritos;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('favoritos_repo_test_');
    dbPath = '${tempDir.path}/test_favoritos.db';
    banco.customFactory = databaseFactoryFfi;
    await banco.inicializar(customPath: dbPath);
    repoReceitas = RepositorioReceitas(bancoDados: banco);
    repoPreparos = RepositorioPreparos(bancoDados: banco);
    repoFavoritos = RepositorioFavoritos(bancoDados: banco);
    RepositorioFavoritos.limparMemoria();
  });

  tearDown(() async {
    await banco.fechar();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('1.1 a 1.3 Persistência e regras de favoritos', () {
    test('1.1 Adição idempotente, consulta, remoção e validação de acesso no SQLite', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      // Cria receita própria
      final rec = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Waffle Caseiro',
          categoria: 'Café',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Farinha', medida: '1 xícara')],
          etapas: ['Misture tudo e asse na máquina.'],
        ),
      );

      // Inicialmente não é favorito
      expect(
        await repoFavoritos.ehFavorito(
          idUsuario: autor.idUsuario,
          idReceita: rec.receita.idReceita,
        ),
        isFalse,
      );

      // Adiciona favorito
      await repoFavoritos.adicionarFavorito(
        idUsuario: autor.idUsuario,
        idReceita: rec.receita.idReceita,
      );

      expect(
        await repoFavoritos.ehFavorito(
          idUsuario: autor.idUsuario,
          idReceita: rec.receita.idReceita,
        ),
        isTrue,
      );

      // Adição idempotente: adicionar novamente não falha nem duplica
      await repoFavoritos.adicionarFavorito(
        idUsuario: autor.idUsuario,
        idReceita: rec.receita.idReceita,
      );

      final listaAposDuplicata = await repoFavoritos.listarFavoritos(autor.idUsuario);
      expect(listaAposDuplicata.length, 1);
      expect(listaAposDuplicata.first.idReceita, rec.receita.idReceita);

      // Tentativa de favoritar por outro usuário que não é autor da receita deve falhar
      await expectLater(
        repoFavoritos.adicionarFavorito(
          idUsuario: 'outro_usuario_invalido',
          idReceita: rec.receita.idReceita,
        ),
        throwsA(isA<StateError>()),
      );

      // Remoção
      await repoFavoritos.removerFavorito(
        idUsuario: autor.idUsuario,
        idReceita: rec.receita.idReceita,
      );

      expect(
        await repoFavoritos.ehFavorito(
          idUsuario: autor.idUsuario,
          idReceita: rec.receita.idReceita,
        ),
        isFalse,
      );
      final listaAposRemover = await repoFavoritos.listarFavoritos(autor.idUsuario);
      expect(listaAposRemover.isEmpty, isTrue);
    });

    test('1.2 Listagem de favoritos com versão mais recente, ordenação e isolamento', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      // Cria duas receitas
      final rec1 = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Panqueca Americana',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Ovo', medida: '1')],
          etapas: ['Frite na frigideira.'],
        ),
      );

      final rec2 = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Suco de Laranja',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Laranja', medida: '3')],
          etapas: ['Esprema.'],
        ),
      );

      final agora = DateTime.now().toUtc();
      // rec1 salva primeiro, rec2 salva depois
      await repoFavoritos.adicionarFavorito(
        idUsuario: autor.idUsuario,
        idReceita: rec1.receita.idReceita,
        salvoEm: agora.subtract(const Duration(minutes: 5)),
      );
      await repoFavoritos.adicionarFavorito(
        idUsuario: autor.idUsuario,
        idReceita: rec2.receita.idReceita,
        salvoEm: agora,
      );

      // Listagem ordenada por salvo_em DESC: rec2 vem antes de rec1
      var favoritos = await repoFavoritos.listarFavoritos(autor.idUsuario);
      expect(favoritos.length, 2);
      expect(favoritos[0].idReceita, rec2.receita.idReceita);
      expect(favoritos[1].idReceita, rec1.receita.idReceita);

      // Edita rec1 criando nova versão (v2)
      await repoReceitas.criarNovaVersao(
        idReceita: rec1.receita.idReceita,
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Panqueca Americana Gourmet',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Ovo', medida: '2')],
          etapas: ['Frite com manteiga.'],
        ),
      );

      // A listagem deve refletir os dados da versão 2 de rec1
      favoritos = await repoFavoritos.listarFavoritos(autor.idUsuario);
      final fav1 = favoritos.firstWhere((f) => f.idReceita == rec1.receita.idReceita);
      expect(fav1.titulo, 'Panqueca Americana Gourmet');
      expect(fav1.numeroVersao, 2);

      // Isolamento: outro usuário não tem esses favoritos
      final outroUsuarioFavs = await repoFavoritos.listarFavoritos('outro_usuario_id');
      expect(outroUsuarioFavs.isEmpty, isTrue);
    });

    test('1.3 Fallback Web em memória para favoritos da sessão', () async {
      final repoMemoria = RepositorioFavoritos(forcarMemoria: true);

      // Limpa dados web e inicializa
      RepositorioReceitas.receitasWeb.clear();
      final recMemoria = const ReceitaCompleta(
        receita: Receita(
          idReceita: 'rec_web_teste',
          idAutor: 'usuario-web-provisorio',
          origem: 'usuario',
          visibilidade: 'privada',
          estadoModeracao: 'liberada',
        ),
        versao: VersaoReceita(
          idVersao: 'versao_web_v1',
          idReceita: 'rec_web_teste',
          numeroVersao: 1,
          titulo: 'Tapioca de Queijo',
          categoria: 'Lanche',
        ),
        itens: [],
        etapas: [],
      );
      RepositorioReceitas.receitasWeb.add(recMemoria);

      expect(
        await repoMemoria.ehFavorito(
          idUsuario: 'usuario-web-provisorio',
          idReceita: 'rec_web_teste',
        ),
        isFalse,
      );

      // Adiciona em memória
      await repoMemoria.adicionarFavorito(
        idUsuario: 'usuario-web-provisorio',
        idReceita: 'rec_web_teste',
      );

      expect(
        await repoMemoria.ehFavorito(
          idUsuario: 'usuario-web-provisorio',
          idReceita: 'rec_web_teste',
        ),
        isTrue,
      );

      // Idempotência em memória
      await repoMemoria.adicionarFavorito(
        idUsuario: 'usuario-web-provisorio',
        idReceita: 'rec_web_teste',
      );

      final lista = await repoMemoria.listarFavoritos('usuario-web-provisorio');
      expect(lista.length, 1);
      expect(lista.first.titulo, 'Tapioca de Queijo');

      // Remoção em memória
      await repoMemoria.removerFavorito(
        idUsuario: 'usuario-web-provisorio',
        idReceita: 'rec_web_teste',
      );
      expect(
        await repoMemoria.ehFavorito(
          idUsuario: 'usuario-web-provisorio',
          idReceita: 'rec_web_teste',
        ),
        isFalse,
      );
    });
  });

  group('2.1 e 2.2 Exclusão lógica e integridade histórica', () {
    test('2.1 Exclusão lógica remove favorito e preserva preparo e nota no Histórico (SQLite)', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      // 1. Cria receita
      final rec = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Torta de Frango',
          categoria: 'Almoço',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Frango', medida: '500g')],
          etapas: ['Cozinhe o frango e asse a massa.'],
        ),
      );

      // 2. Favorita receita
      await repoFavoritos.adicionarFavorito(
        idUsuario: autor.idUsuario,
        idReceita: rec.receita.idReceita,
      );
      expect(
        await repoFavoritos.ehFavorito(
          idUsuario: autor.idUsuario,
          idReceita: rec.receita.idReceita,
        ),
        isTrue,
      );

      // 3. Inicia preparo, conclui e avalia
      final preparo = await repoPreparos.iniciarPreparo(
        idUsuario: autor.idUsuario,
        idReceita: rec.receita.idReceita,
      );
      await repoPreparos.concluirPreparo(
        idPreparo: preparo.preparo.idPreparo,
        idUsuario: autor.idUsuario,
      );
      await repoPreparos.salvarAvaliacao(
        idPreparo: preparo.preparo.idPreparo,
        idUsuario: autor.idUsuario,
        estrelas: 5,
      );

      // 4. Exclui a receita logicamente
      final excluiu = await repoReceitas.excluirReceitaLogica(
        idReceita: rec.receita.idReceita,
        idAutor: autor.idUsuario,
      );
      expect(excluiu, isTrue);

      // 5. Verifica que receita saiu de Favoritos
      expect(
        await repoFavoritos.ehFavorito(
          idUsuario: autor.idUsuario,
          idReceita: rec.receita.idReceita,
        ),
        isFalse,
      );
      final favoritos = await repoFavoritos.listarFavoritos(autor.idUsuario);
      expect(favoritos.any((f) => f.idReceita == rec.receita.idReceita), isFalse);

      // 6. Verifica que preparo e nota anteriores continuam no Histórico
      final historico = await repoPreparos.listarPreparosConcluidos(
        idUsuario: autor.idUsuario,
      );
      expect(historico.length, 1);
      expect(historico.first.idPreparo, preparo.preparo.idPreparo);
      expect(historico.first.tituloReceita, 'Torta de Frango');
      expect(historico.first.estrelas, 5);
      expect(historico.first.receitaExcluida, isTrue);
    });

    test('2.2 Rejeição de novo favorito para receita excluída e integridade de versões', () async {
      final autor = await banco.obterOuCriarUsuarioProvisorio();

      final rec = await repoReceitas.criarReceitaPropria(
        idAutor: autor.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Mousse de Maracujá',
          itens: [RascunhoItemReceita(nomeIngrediente: 'Maracujá', medida: '2')],
          etapas: ['Bata tudo.'],
        ),
      );

      // Exclui
      await repoReceitas.excluirReceitaLogica(
        idReceita: rec.receita.idReceita,
        idAutor: autor.idUsuario,
      );

      // Tentar favoritar receita excluída deve falhar com StateError
      await expectLater(
        repoFavoritos.adicionarFavorito(
          idUsuario: autor.idUsuario,
          idReceita: rec.receita.idReceita,
        ),
        throwsA(isA<StateError>()),
      );

      // A lista continua vazia
      final lista = await repoFavoritos.listarFavoritos(autor.idUsuario);
      expect(lista.isEmpty, isTrue);
    });
  });
}
