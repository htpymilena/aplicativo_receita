import 'package:flutter/material.dart';
import 'inicio_tela.dart';
import 'comunidade_tela.dart';
import 'favoritos_tela.dart';
import 'historico_tela.dart';
import 'perfil_tela.dart';

/// Contêiner principal com NavigationBar de 5 destinos acessíveis (Início, Comunidade, Favoritos, Histórico, Perfil).
class NavegacaoPrincipal extends StatefulWidget {
  final int indiceInicial;

  const NavegacaoPrincipal({
    super.key,
    this.indiceInicial = 0,
  });

  @override
  State<NavegacaoPrincipal> createState() => _NavegacaoPrincipalState();
}

class _NavegacaoPrincipalState extends State<NavegacaoPrincipal> {
  late int _indiceSelecionado;

  static const List<Widget> _telas = [
    InicioTela(),
    ComunidadeTela(),
    FavoritosTela(),
    HistoricoTela(),
    PerfilTela(),
  ];

  @override
  void initState() {
    super.initState();
    _indiceSelecionado = widget.indiceInicial;
  }

  void _onItemTapped(int index) {
    setState(() {
      _indiceSelecionado = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceSelecionado,
        children: _telas,
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
