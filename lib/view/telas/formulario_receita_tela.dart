import 'package:flutter/material.dart';
import '../../controller/controller_receitas.dart';
import '../../model/repositorios/repositorio_receitas.dart';
import '../../model/servicos/rascunho_receita.dart';
import '../componentes/botoes.dart';
import '../componentes/campo_texto.dart';
import '../componentes/imagem_receita.dart';
import '../theme/cores.dart';

class FormularioReceitaTela extends StatefulWidget {
  final ControllerReceitas controller;
  final ReceitaCompleta? receitaParaEditar;

  const FormularioReceitaTela({
    super.key,
    required this.controller,
    this.receitaParaEditar,
  });

  @override
  State<FormularioReceitaTela> createState() => _FormularioReceitaTelaState();
}

class _FormularioReceitaTelaState extends State<FormularioReceitaTela> {
  static const List<String> categoriasSugeridas = [
    'Sem categoria',
    'Café da manhã',
    'Almoço',
    'Jantar',
    'Lanche',
    'Sobremesa',
    'Bebida',
    'Massa',
    'Sopa / Caldo',
    'Pão / Confeitaria',
    'Outra...',
  ];

  late TextEditingController _tituloController;
  late TextEditingController _urlFotoController;
  late TextEditingController _categoriaPersonalizadaController;
  String _categoriaSelecionada = 'Sem categoria';
  bool _mostrarCampoPersonalizado = false;

  final List<TextEditingController> _ingredientesControllers = [];
  final List<TextEditingController> _medidasControllers = [];
  final List<TextEditingController> _etapasControllers = [];

  String? _fotoAtual;
  String? _novaFotoCaminho;
  bool _removerFoto = false;
  ResultadoValidacao? _validacao;

  @override
  void initState() {
    super.initState();
    final edicao = widget.receitaParaEditar;
    if (edicao != null) {
      _tituloController = TextEditingController(text: edicao.versao.titulo);
      final cat = edicao.versao.categoria;
      if (categoriasSugeridas.contains(cat)) {
        _categoriaSelecionada = cat;
        _mostrarCampoPersonalizado = false;
        _categoriaPersonalizadaController = TextEditingController();
      } else {
        _categoriaSelecionada = 'Outra...';
        _mostrarCampoPersonalizado = true;
        _categoriaPersonalizadaController = TextEditingController(text: cat);
      }
      _fotoAtual = edicao.versao.fotoLocal;
      _urlFotoController = TextEditingController(text: _fotoAtual ?? '');
      for (final item in edicao.itens) {
        _ingredientesControllers.add(TextEditingController(text: item.nomeIngrediente));
        _medidasControllers.add(TextEditingController(text: item.medida));
      }
      for (final etapa in edicao.etapas) {
        _etapasControllers.add(TextEditingController(text: etapa.instrucao));
      }
    } else {
      _tituloController = TextEditingController();
      _urlFotoController = TextEditingController();
      _categoriaPersonalizadaController = TextEditingController();
      _categoriaSelecionada = 'Sem categoria';
      _mostrarCampoPersonalizado = false;
      _ingredientesControllers.add(TextEditingController());
      _medidasControllers.add(TextEditingController());
      _etapasControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _urlFotoController.dispose();
    _categoriaPersonalizadaController.dispose();
    for (final c in _ingredientesControllers) {
      c.dispose();
    }
    for (final c in _medidasControllers) {
      c.dispose();
    }
    for (final c in _etapasControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _adicionarIngrediente() {
    setState(() {
      _ingredientesControllers.add(TextEditingController());
      _medidasControllers.add(TextEditingController());
    });
  }

  void _removerIngrediente(int index) {
    if (_ingredientesControllers.length > 1) {
      setState(() {
        _ingredientesControllers.removeAt(index).dispose();
        _medidasControllers.removeAt(index).dispose();
      });
    }
  }

  void _adicionarEtapa() {
    setState(() {
      _etapasControllers.add(TextEditingController());
    });
  }

  void _removerEtapa(int index) {
    if (_etapasControllers.length > 1) {
      setState(() {
        _etapasControllers.removeAt(index).dispose();
      });
    }
  }

  Future<void> _escolherFoto() async {
    final caminho = await widget.controller.escolherFotoGaleria();
    if (caminho != null && mounted) {
      setState(() {
        _novaFotoCaminho = caminho;
        _urlFotoController.text = caminho;
        _removerFoto = false;
      });
    }
  }

  void _solicitarRemocaoFoto() {
    setState(() {
      _removerFoto = true;
      _novaFotoCaminho = null;
      _urlFotoController.clear();
    });
  }

  RascunhoReceita _montarRascunho() {
    final itens = <RascunhoItemReceita>[];
    for (int i = 0; i < _ingredientesControllers.length; i++) {
      itens.add(RascunhoItemReceita(
        nomeIngrediente: _ingredientesControllers[i].text,
        medida: _medidasControllers[i].text,
      ));
    }

    final etapas = _etapasControllers.map((c) => c.text).toList();
    final categoriaFinal = _mostrarCampoPersonalizado
        ? (_categoriaPersonalizadaController.text.trim().isNotEmpty
            ? _categoriaPersonalizadaController.text.trim()
            : 'Sem categoria')
        : _categoriaSelecionada;

    return RascunhoReceita(
      idReceita: widget.receitaParaEditar?.receita.idReceita,
      titulo: _tituloController.text,
      categoria: categoriaFinal,
      itens: itens,
      etapas: etapas,
      fotoAtual: _fotoAtual,
      novaFotoCaminho: _novaFotoCaminho,
      removerFoto: _removerFoto,
    );
  }

  Future<void> _salvar() async {
    final rascunho = _montarRascunho();
    final res = ValidadorReceita.validar(rascunho);
    setState(() {
      _validacao = res;
    });

    if (!res.valido) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.erroGeral ?? 'Corrija os campos destacados.'),
          backgroundColor: CoresApp.error,
        ),
      );
      return;
    }

    final sucesso = await widget.controller.salvarReceita(rascunho);
    if (!sucesso && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.erro ?? 'Erro ao salvar a receita.'),
          backgroundColor: CoresApp.error,
        ),
      );
    } else if (sucesso && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receita salva com sucesso!'),
          backgroundColor: CoresApp.success,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Widget _construirPreviaFoto() {
    final fotoParaExibir = _novaFotoCaminho ?? (_removerFoto ? null : _fotoAtual);
    final temFoto = fotoParaExibir != null && fotoParaExibir.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CoresApp.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CoresApp.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Foto do Prato (opcional)',
            style: TextStyle(
              color: CoresApp.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (temFoto) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ImagemReceita(
                  caminhoOuUrl: fotoParaExibir,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: BotaoSecundario(
                    texto: 'Trocar foto',
                    icone: const Icon(Icons.photo_library, size: 20),
                    onPressed: _escolherFoto,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BotaoTerciario(
                    texto: 'Remover foto',
                    onPressed: _solicitarRemocaoFoto,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: CoresApp.orange50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 32, color: CoresApp.orange700),
                    SizedBox(height: 6),
                    Text(
                      'Nenhuma foto selecionada',
                      style: TextStyle(color: CoresApp.inkSoft, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            BotaoSecundario(
              texto: 'Escolher da galeria',
              icone: const Icon(Icons.photo_library, size: 20),
              onPressed: _escolherFoto,
            ),
          ],
          const SizedBox(height: 12),
          CampoTextoApp(
            controller: _urlFotoController,
            label: 'Ou cole o link da imagem (URL)',
            dica: 'https://exemplo.com/minha_foto.jpg',
            prefixo: const Icon(Icons.link),
            onChanged: (valor) {
              setState(() {
                final limpo = valor.trim();
                if (limpo.isNotEmpty) {
                  _novaFotoCaminho = limpo;
                  _removerFoto = false;
                } else {
                  _novaFotoCaminho = null;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ehEdicao = widget.receitaParaEditar != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(ehEdicao ? 'Editar Receita' : 'Nova Receita'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoTextoApp(
                label: 'Título da receita',
                dica: 'Ex: Panqueca de banana com aveia',
                controller: _tituloController,
                erro: _validacao?.erroTitulo,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _categoriaSelecionada,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                dropdownColor: CoresApp.surface,
                borderRadius: BorderRadius.circular(16),
                items: categoriasSugeridas.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Text(cat, style: const TextStyle(color: CoresApp.ink)),
                  );
                }).toList(),
                onChanged: (novo) {
                  if (novo == null) return;
                  setState(() {
                    _categoriaSelecionada = novo;
                    _mostrarCampoPersonalizado = (novo == 'Outra...');
                  });
                },
              ),
              if (_mostrarCampoPersonalizado) ...[
                const SizedBox(height: 12),
                CampoTextoApp(
                  controller: _categoriaPersonalizadaController,
                  label: 'Nome da categoria personalizada',
                  dica: 'Ex: Petiscos',
                ),
              ],
              const SizedBox(height: 20),
              _construirPreviaFoto(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ingredientes',
                    style: TextStyle(
                      color: CoresApp.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _adicionarIngrediente,
                    icon: const Icon(Icons.add, size: 20, color: CoresApp.orange700),
                    label: const Text(
                      'Adicionar',
                      style: TextStyle(color: CoresApp.orange700, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_ingredientesControllers.length, (index) {
                final erroIng = _validacao?.errosIngredientes[index];
                final erroMed = _validacao?.errosMedidas[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: CampoTextoApp(
                          label: 'Ingrediente ${index + 1}',
                          dica: 'Ex: Farinha de aveia',
                          controller: _ingredientesControllers[index],
                          erro: erroIng,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: CampoTextoApp(
                          label: 'Medida',
                          dica: 'Ex: 1 xícara / a gosto',
                          controller: _medidasControllers[index],
                          erro: erroMed,
                        ),
                      ),
                      if (_ingredientesControllers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: CoresApp.error),
                          tooltip: 'Remover ingrediente',
                          onPressed: () => _removerIngrediente(index),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
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
                  TextButton.icon(
                    onPressed: _adicionarEtapa,
                    icon: const Icon(Icons.add, size: 20, color: CoresApp.orange700),
                    label: const Text(
                      'Adicionar etapa',
                      style: TextStyle(color: CoresApp.orange700, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_etapasControllers.length, (index) {
                final erroEtapa = _validacao?.errosEtapas[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: CoresApp.orange100,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: CoresApp.orange800,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CampoTextoApp(
                          label: 'Etapa ${index + 1}',
                          dica: 'Descreva a instrução deste passo...',
                          controller: _etapasControllers[index],
                          erro: erroEtapa,
                        ),
                      ),
                      if (_etapasControllers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: CoresApp.error),
                          tooltip: 'Remover etapa',
                          onPressed: () => _removerEtapa(index),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 32),
              BotaoPrimario(
                texto: ehEdicao ? 'Salvar nova versão' : 'Salvar receita',
                onPressed: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
