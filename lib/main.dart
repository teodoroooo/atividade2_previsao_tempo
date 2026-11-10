import 'package:flutter/material.dart';

import 'data/armazenamento_local.dart';
import 'screens/busca_cidades_screen.dart';
import 'services/cptec_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final armazenamento = await ArmazenamentoLocal.abrir();
  runApp(
    PrevisaoTempoApp(service: CptecService(), armazenamento: armazenamento),
  );
}

/// Aplicativo de previsão do tempo com dados do CPTEC/INPE.
///
/// As dependências são recebidas pelo construtor para permitir testes
/// com serviço e armazenamento simulados.
class PrevisaoTempoApp extends StatelessWidget {
  const PrevisaoTempoApp({
    super.key,
    required this.service,
    required this.armazenamento,
  });

  final CptecService service;
  final ArmazenamentoLocal armazenamento;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Previsão do Tempo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: BuscaCidadesScreen(service: service, armazenamento: armazenamento),
    );
  }
}
