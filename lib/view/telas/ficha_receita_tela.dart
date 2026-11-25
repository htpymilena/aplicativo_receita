import 'package:flutter/material.dart';
import '../../controller/controller_favoritos.dart';
import '../../controller/controller_preparo.dart';
import '../../controller/controller_receitas.dart';
import '../../model/entidades/entidades.dart';
import '../../model/repositorios/repositorio_receitas.dart';
import '../../model/servicos/quebrador_instrucoes.dart';
import '../../model/servicos/servico_traducao.dart';
import '../componentes/botoes.dart';
import '../componentes/imagem_receita.dart';
import '../componentes/selo_estado.dart';
import '../theme/cores.dart';
import 'checklist_preparo_tela.dart';
import 'formulario_receita_tela.dart';

class FichaReceitaTela extends StatefulWidget {
  final String idReceita;
  final ControllerReceitas controller;
  final ControllerPreparo? controllerPreparo;
  final ControllerFavoritos? controllerFavoritos;

  const FichaReceitaTela({
    super.key,
    required this.idReceita,
    required this.controller,
    this.controllerPreparo,
    this.controllerFavoritos,
  });

  @override
  State<FichaReceitaTela> createState() => _FichaReceitaTelaState();
}

class _FichaReceitaTelaState extends State<FichaReceitaTela> {
  String? _caminhoFotoResolvido;
  List<Etapa>? _etapasTraduzidasDinamicas;
  late final ControllerPreparo _controllerPreparo;
  late final ControllerFavoritos _controllerFavoritos;

  @override
  void initState() {
    super.initState();
    _controllerPreparo = widget.controllerPreparo ?? ControllerPreparo();
    _controllerFavoritos = widget.controllerFavoritos ?? ControllerFavoritos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controllerFavoritos.carregarFavoritos();
      }
    });
    _carregar();
  }

  Future<void> _carregar() async {
    if (widget.controller.receitaSelecionada == null ||
        widget.controller.receitaSelecionada!.receita.idReceita != widget.idReceita) {
      await widget.controller.carregarDetalhes(widget.idReceita);
    }
    final detalhes = widget.controller.receitaSelecionada;
    if (detalhes?.versao.fotoLocal != null) {
      final path = await widget.controller.gerenciadorFotos.resolverCaminhoCompleto(
        detalhes!.versao.fotoLocal,
      );
      if (mounted) {
        setState(() {
          _caminhoFotoResolvido = path;
        });
      }
    } else if (detalhes?.versao.fotoRemota != null) {
      if (mounted) {
        setState(() {
          _caminhoFotoResolvido = detalhes!.versao.fotoRemota;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _caminhoFotoResolvido = null;
        });
      }
    }

    if (detalhes != null && detalhes.receita.origem == 'themealdb') {
      _verificarETraduzirEtapasIngles(detalhes);
    }
  }

  Future<void> _verificarETraduzirEtapasIngles(ReceitaCompleta detalhes) async {
    final servicoTraducao = ServicoTraducao();
    bool temIngles = false;
    for (final etapa in detalhes.etapas) {
      if (servicoTraducao.pareceIngles(etapa.instrucao)) {
        temIngles = true;
        break;
      }
    }
    if (!temIngles) return;

    final novasEtapas = await Future.wait<Etapa>(
      detalhes.etapas.map((etapa) async {
        if (servicoTraducao.pareceIngles(etapa.instrucao)) {
          final traduzido = await servicoTraducao.textoParaPortugues(etapa.instrucao);
          return Etapa(
            idEtapa: etapa.idEtapa,
            idVersao: etapa.idVersao,
            ordem: etapa.ordem,
            instrucao: traduzido,
          );
        }
        return etapa;
      }),
    );

    if (mounted) {
      setState(() {
        _etapasTraduzidasDinamicas = novasEtapas;
      });
    }
  }

  void _iniciarReceita() async {
    final prep = await _controllerPreparo.iniciarReceita(widget.idReceita);
    if (prep != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChecklistPreparoTela(
            controller: _controllerPreparo,
          ),
        ),
      );
    }
  }

  void _abrirEdicao() async {
    final detalhes = widget.controller.receitaSelecionada;
    if (detalhes == null) return;

    final atualizou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormularioReceitaTela(
          controller: widget.controller,
          receitaParaEditar: detalhes,
        ),
      ),
    );

    if (atualizou == true) {
      await widget.controller.carregarDetalhes(widget.idReceita);
      _carregar();
    }
  }

  void _confirmarExclusao() {
    final detalhes = widget.controller.receitaSelecionada;
    if (detalhes == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Excluir receita?'),
          content: Text(
            'Tem certeza de que deseja excluir "${detalhes.versao.titulo}"? A receita será removida das suas listas, mas o histórico de preparos anteriores será preservado.',
            style: const TextStyle(color: CoresApp.inkSoft, fontSize: 15),
          ),
          actions: [
            BotaoTerciario(
              texto: 'Cancelar',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final sucesso = await widget.controller.excluirReceita(widget.idReceita);
                if (sucesso && mounted) {
                  Navigator.of(context).pop(); // Retorna para Minhas receitas
                }
              },
              child: const Text(
                'Excluir',
                style: TextStyle(
                  color: CoresApp.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _construirFotoOuPlaceholder() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ImagemReceita(
          caminhoOuUrl: _caminhoFotoResolvido,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final detalhes = widget.controller.receitaSelecionada;

        if (widget.controller.carregando && detalhes == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (detalhes == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Receita')),
            body: Center(
              child: Text(widget.controller.erro ?? 'Receita não encontrada'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(detalhes.versao.titulo),
            actions: [
              ListenableBuilder(
                listenable: _controllerFavoritos,
                builder: (context, _) {
                  final ehFavorito = _controllerFavoritos.isFavorito(widget.idReceita);
                  return IconButton(
                    iconSize: 24,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    tooltip: ehFavorito ? 'Remover dos favoritos' : 'Favoritar',
                    icon: Icon(
                      ehFavorito ? Icons.favorite : Icons.favorite_border,
                      color: ehFavorito ? CoresApp.orange700 : null,
                    ),
                    onPressed: () async {
                      final sucesso = await _controllerFavoritos.alternarFavorito(widget.idReceita);
                      if (!sucesso && context.mounted && _controllerFavoritos.erro != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_controllerFavoritos.erro!)),
                        );
                      }
                    },
                  );
                },
              ),
              if (detalhes.receita.origem == 'usuario') ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar receita',
                  onPressed: _abrirEdicao,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: CoresApp.error),
                  tooltip: 'Excluir receita',
                  onPressed: _confirmarExclusao,
                ),
              ],
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _construirFotoOuPlaceholder(),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (detalhes.receita.origem == 'themealdb')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: CoresApp.orange100,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Fonte: TheMealDB',
                            style: TextStyle(
                              color: CoresApp.orange800,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        const SeloEstado(
                          tipo: TipoSelo.privada,
                          textoCustomizado: 'Privada',
                        ),
                      const SeloEstado(
                        tipo: TipoSelo.tenho,
                        textoCustomizado: 'Salvo no aparelho',
                      ),
                      if (detalhes.versao.categoria.isNotEmpty &&
                          detalhes.versao.categoria != 'Sem categoria')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: CoresApp.orange100,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            detalhes.versao.categoria,
                            style: const TextStyle(
                              color: CoresApp.orange800,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: CoresApp.orange50,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Versão ${detalhes.versao.numeroVersao}',
                          style: const TextStyle(
                            color: CoresApp.orange800,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    detalhes.versao.titulo,
                    style: const TextStyle(
                      color: CoresApp.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ingredientes',
                    style: TextStyle(
                      color: CoresApp.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: detalhes.itens.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 8, color: CoresApp.orange700),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.nomeIngrediente,
                                    style: const TextStyle(
                                      color: CoresApp.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (item.medida.trim().isNotEmpty)
                                  Text(
                                    item.medida,
                                    style: const TextStyle(
                                      color: CoresApp.inkSoft,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (context) {
                      final etapasBase = _etapasTraduzidasDinamicas ?? detalhes.etapas;
                      final etapasExibicao = (etapasBase.length == 1 &&
                              (etapasBase.first.instrucao.contains('\n') ||
                                  etapasBase.first.instrucao.contains('STEP') ||
                                  etapasBase.first.instrucao.contains('Passo')))
                          ? QuebradorInstrucoes.dividirEmEtapas(etapasBase.first.instrucao)
                              .asMap()
                              .entries
                              .map((entry) => Etapa(
                                    idEtapa: 'temp_${entry.key}',
                                    idVersao: detalhes.versao.idVersao,
                                    ordem: entry.key + 1,
                                    instrucao: entry.value,
                                  ))
                              .toList()
                          : etapasBase;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Modo de Preparo',
                                style: TextStyle(
                                  color: CoresApp.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: CoresApp.orange50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: CoresApp.orange100),
                                ),
                                child: Text(
                                  '${etapasExibicao.length} ${etapasExibicao.length == 1 ? 'etapa' : 'etapas'}',
                                  style: const TextStyle(
                                    color: CoresApp.orange800,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...etapasExibicao.map((etapa) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: CoresApp.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: CoresApp.line, width: 1.2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x06000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: CoresApp.orange100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Passo ${etapa.ordem}',
                                      style: const TextStyle(
                                        color: CoresApp.orange800,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      etapa.instrucao,
                                      style: const TextStyle(
                                        color: CoresApp.ink,
                                        fontSize: 15,
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: BotaoPrimario(
                      texto: 'Iniciar receita',
                      icone: const Icon(Icons.play_arrow_rounded, size: 24),
                      onPressed: _controllerPreparo.iniciando ? null : _iniciarReceita,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: BotaoSecundario(
                      texto: 'Editar receita',
                      icone: const Icon(Icons.edit, size: 20),
                      onPressed: _abrirEdicao,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
