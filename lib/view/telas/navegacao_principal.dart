import 'package:flutter/material.dart';
import '../../controller/controller_favoritos.dart';
import '../../controller/controller_historico.dart';
import '../../controller/controller_preparo.dart';
import '../../controller/controller_receitas.dart';
import 'comunidade_tela.dart';
import 'favoritos_tela.dart';
import 'historico_tela.dart';
import 'inicio_tela.dart';
import 'perfil_tela.dart';

/// Contêiner principal com NavigationBar de 5 destinos acessíveis (Início, Comunidade, Favoritos, Histórico, Perfil).
class NavegacaoPrincipal extends StatefulWidget {
  final int indiceInicial;
  final ControllerHistorico? controllerHistorico;
  final ControllerPreparo? controllerPreparo;
  final ControllerReceitas? controllerReceitas;
  final ControllerFavoritos? controllerFavoritos;

  const NavegacaoPrincipal({
    super.key,
    this.indiceInicial = 0,
    this.controllerHistorico,
    this.controllerPreparo,
    this.controllerReceitas,
    this.controllerFavoritos,
  });

  @override
  State<NavegacaoPrincipal> createState() => _NavegacaoPrincipalState();
}

class _NavegacaoPrincipalState extends State<NavegacaoPrincipal> {
  late int _indiceSelecionado;
  late final ControllerHistorico _controllerHistorico;
  late final ControllerPreparo _controllerPreparo;
  late final ControllerReceitas _controllerReceitas;
  late final ControllerFavoritos _controllerFavoritos;

  @override
  void initState() {
    super.initState();
    _indiceSelecionado = widget.indiceInicial;
    _controllerHistorico = widget.controllerHistorico ?? ControllerHistorico();
    _controllerPreparo = widget.controllerPreparo ?? ControllerPreparo();
    _controllerReceitas = widget.controllerReceitas ?? ControllerReceitas();
    _controllerFavoritos = widget.controllerFavoritos ?? ControllerFavoritos();
  }

  void _onItemTapped(int index) {
    setState(() {
      _indiceSelecionado = index;
    });

    // Atualiza automaticamente Início, Favoritos ou Histórico ao selecionar a aba
    if (index == 0) {
      _controllerHistorico.carregarTudo();
      _controllerReceitas.carregarMinhasReceitas();
      _controllerFavoritos.carregarFavoritos();
    }
    if (index == 2) {
      _controllerFavoritos.carregarFavoritos();
    }
    if (index == 3) {
      _controllerHistorico.carregarTudo();
      _controllerReceitas.carregarMinhasReceitas();
    }
    if (index == 4) {
      _controllerReceitas.carregarMinhasReceitas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final telas = [
      InicioTela(
        controllerHistorico: _controllerHistorico,
        controllerPreparo: _controllerPreparo,
        controllerReceitas: _controllerReceitas,
        controllerFavoritos: _controllerFavoritos,
      ),
      const ComunidadeTela(),
      FavoritosTela(
        controller: _controllerFavoritos,
        controllerReceitas: _controllerReceitas,
        controllerPreparo: _controllerPreparo,
      ),
      HistoricoTela(
        controller: _controllerHistorico,
      ),
      PerfilTela(
        controller: _controllerReceitas,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _indiceSelecionado,
        children: telas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceSelecionado,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Comunidade',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
