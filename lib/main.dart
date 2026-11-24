import 'package:flutter/material.dart';
import 'app/app.dart';
import 'model/repositorios/banco_dados.dart';
import 'view/telas/navegacao_principal.dart';
import 'view/telas/tela_erro_banco.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const RaizApp());
}

class RaizApp extends StatefulWidget {
  final Future<void> Function()? inicializadorBanco;

  const RaizApp({
    super.key,
    this.inicializadorBanco,
  });

  @override
  State<RaizApp> createState() => _RaizAppState();
}

class _RaizAppState extends State<RaizApp> {
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _iniciarBanco();
  }

  Future<void> _iniciarBanco() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      if (widget.inicializadorBanco != null) {
        await widget.inicializadorBanco!();
      } else {
        await BancoDados.instancia.inicializar();
      }
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    BancoDados.instancia.fechar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_erro != null) {
      return AppReceitas(
        telaInicial: TelaErroBanco(
          mensagemErro: _erro!,
          onTentarNovamente: _iniciarBanco,
        ),
      );
    }

    return const AppReceitas(
      telaInicial: NavegacaoPrincipal(),
    );
  }
}
