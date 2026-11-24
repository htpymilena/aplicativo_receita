import 'package:flutter/material.dart';
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

  const NavegacaoPrincipal({
    super.key,
    this.indiceInicial = 0,
    this.controllerHistorico,
    this.controllerPreparo,
    this.controllerReceitas,
  });

  @override
  State<NavegacaoPrincipal> createState() => _NavegacaoPrincipalState();
}

class _NavegacaoPrincipalState extends State<NavegacaoPrincipal> {
  late int _indiceSelecionado;
  late final ControllerHistorico _controllerHistorico;
  late final ControllerPreparo _controllerPreparo;
  late final ControllerReceitas _controllerReceitas;

  @override
  void initState() {
    super.initState();
    _indiceSelecionado = widget.indiceInicial;
    _controllerHistorico = widget.controllerHistorico ?? ControllerHistorico();
    _controllerPreparo = widget.controllerPreparo ?? ControllerPreparo();
    _controllerReceitas = widget.controllerReceitas ?? ControllerReceitas();
  }

  void _onItemTapped(int index) {
    setState(() {
      _indiceSelecionado = index;
    });

    // Atualiza automaticamente Início ou Histórico ao selecionar a aba
    if (index == 0 || index == 3) {
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
      ),
      const ComunidadeTela(),
      const FavoritosTela(),
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
