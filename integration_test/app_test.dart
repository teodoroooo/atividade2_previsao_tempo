// Teste de integração contra o serviço REAL do CPTEC/INPE.
//
// Executar (Windows/Android/iOS):
//   flutter test integration_test -d windows \
//     --dart-define=SCREENSHOTS=<pasta absoluta>/docs/screenshots
//
// Sem SCREENSHOTS, o teste roda normalmente sem salvar imagens.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:atividade2_previsao_tempo/data/armazenamento_local.dart';
import 'package:atividade2_previsao_tempo/main.dart' as app;
import 'package:atividade2_previsao_tempo/services/cptec_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';

const String pastaCapturas = String.fromEnvironment('SCREENSHOTS');

/// Tamanho lógico de um celular comum (ex.: Pixel 7).
const Size tamanhoCelular = Size(412, 892);

final GlobalKey _chaveTela = GlobalKey();

/// Envolve o app em uma "tela de celular" que é redimensionada para caber
/// na janela e pode ser capturada como imagem.
Widget _celular(Widget filho) => ColoredBox(
  color: Colors.black,
  child: Center(
    child: FittedBox(
      child: RepaintBoundary(
        key: _chaveTela,
        child: SizedBox.fromSize(
          size: tamanhoCelular,
          child: MediaQuery(
            data: const MediaQueryData(
              size: tamanhoCelular,
              devicePixelRatio: 2.625,
            ),
            child: filho,
          ),
        ),
      ),
    ),
  ),
);

Future<void> _capturar(WidgetTester tester, String nome) async {
  await tester.pumpAndSettle();
  if (pastaCapturas.isEmpty) return;
  final boundary =
      _chaveTela.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final imagem = await boundary.toImage(pixelRatio: 2.625);
  final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
  final arquivo = File('$pastaCapturas/$nome.png');
  await arquivo.parent.create(recursive: true);
  await arquivo.writeAsBytes(png!.buffer.asUint8List());
}

/// Aguarda a resposta da rede (até [limite]) até [finder] aparecer.
Future<void> _esperar(
  WidgetTester tester,
  Finder finder, {
  Duration limite = const Duration(seconds: 30),
}) async {
  final fim = DateTime.now().add(limite);
  while (DateTime.now().isBefore(fim)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Tempo esgotado aguardando $finder');
}

Future<void> _pesquisar(WidgetTester tester, String termo) async {
  await tester.enterText(find.byKey(const Key('campoBusca')), termo);
  await tester.tap(find.byKey(const Key('botaoPesquisar')));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fluxo completo com o serviço real do CPTEC/INPE', (
    tester,
  ) async {
    final armazenamento = await ArmazenamentoLocal.abrir();
    await armazenamento.limparTudo();

    await tester.pumpWidget(
      _celular(
        app.PrevisaoTempoApp(
          service: CptecService(),
          armazenamento: armazenamento,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Fonte dos dados: CPTEC/INPE'), findsOneWidget);
    await _capturar(tester, '01_inicio');

    // Pesquisa de cidades (com acento).
    await _pesquisar(tester, 'são josé dos');
    expect(find.text('Pesquisando cidades...'), findsOneWidget);
    await _esperar(tester, find.textContaining('encontrada'));
    expect(find.text('São José dos Campos'), findsOneWidget);
    await _capturar(tester, '02_pesquisa');

    // Previsão para 4 dias da cidade selecionada.
    await tester.tap(find.text('São José dos Campos'));
    await tester.pump();
    await _esperar(tester, find.textContaining('Previsão para'));
    expect(find.textContaining('Atualização do CPTEC/INPE:'), findsOneWidget);
    expect(find.text('Previsão para 4 dias'), findsOneWidget);
    expect(find.textContaining('Mín. '), findsNWidgets(4));
    expect(find.textContaining('Máx. '), findsNWidgets(4));
    expect(find.textContaining('Condição não informada'), findsNothing);
    final salva = armazenamento.previsaoSalva(
      armazenamento.cidadesRecentes().first.id,
    );
    expect(salva!.previsao.dias, hasLength(4));
    await _capturar(tester, '03_previsao');

    // Atualizar.
    await tester.tap(find.byKey(const Key('botaoAtualizar')));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final fim = DateTime.now().add(const Duration(seconds: 30));
    while (find.byType(LinearProgressIndicator).evaluate().isNotEmpty &&
        DateTime.now().isBefore(fim)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Previsão para 4 dias'), findsOneWidget);

    // Gráfico de temperaturas.
    await tester.tap(find.byKey(const Key('botaoGrafico')));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
    await _capturar(tester, '04_grafico');

    // Volta para a tela inicial e mostra as consultas recentes.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Limpar pesquisa'));
    await tester.pumpAndSettle();
    expect(find.text('São José dos Campos - SP'), findsOneWidget);
    await _capturar(tester, '05_recentes');

    // Nenhuma cidade encontrada.
    await _pesquisar(tester, 'xyzqwe');
    await _esperar(tester, find.textContaining('Nenhuma cidade encontrada'));
    await _capturar(tester, '06_nenhuma_cidade');

    // Sem conexão: abre a cidade salva usando um cliente que sempre falha.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _celular(
        app.PrevisaoTempoApp(
          service: CptecService(
            client: MockClient(
              (_) async => throw http.ClientException('Failed host lookup'),
            ),
          ),
          armazenamento: armazenamento,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('São José dos Campos - SP'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Exibindo previsão salva'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await _capturar(tester, '07_offline_previsao_salva');

    // Erro de conexão na pesquisa.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _pesquisar(tester, 'jacareí');
    await tester.pumpAndSettle();
    expect(find.textContaining('Falha de conexão'), findsOneWidget);
    await _capturar(tester, '08_erro_conexao');

    await armazenamento.limparTudo();
  });
}
