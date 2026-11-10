import 'dart:async';

import 'package:atividade2_previsao_tempo/data/armazenamento_local.dart';
import 'package:atividade2_previsao_tempo/main.dart';
import 'package:atividade2_previsao_tempo/models/cidade.dart';
import 'package:atividade2_previsao_tempo/models/previsao.dart';
import 'package:atividade2_previsao_tempo/screens/grafico_screen.dart';
import 'package:atividade2_previsao_tempo/services/cptec_parser.dart';
import 'package:atividade2_previsao_tempo/services/cptec_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

const jacarei = Cidade(id: 2680, nome: 'Jacareí', uf: 'SP');

Future<ArmazenamentoLocal> _armazenamento([
  Map<String, Object> inicial = const {},
]) async {
  SharedPreferences.setMockInitialValues(inicial);
  return ArmazenamentoLocal.abrir();
}

Future<void> _abrirApp(
  WidgetTester tester,
  http.Client client,
  ArmazenamentoLocal armazenamento,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    PrevisaoTempoApp(
      service: CptecService(client: client),
      armazenamento: armazenamento,
    ),
  );
}

Future<void> _pesquisar(WidgetTester tester, String termo) async {
  await tester.enterText(find.byKey(const Key('campoBusca')), termo);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tela inicial mostra dica e a fonte CPTEC/INPE', (tester) async {
    await _abrirApp(tester, clienteSimulado(), await _armazenamento());
    expect(find.text('Previsão do Tempo'), findsOneWidget);
    expect(find.textContaining('Pesquise uma cidade'), findsOneWidget);
    expect(find.textContaining('Fonte dos dados: CPTEC/INPE'), findsOneWidget);
  });

  testWidgets('fluxo completo: pesquisa, previsão e gráfico', (tester) async {
    final chamadas = <Uri>[];
    final armazenamento = await _armazenamento();
    await _abrirApp(
      tester,
      clienteSimulado(cidades: xmlCidadesSaoJose, chamadas: chamadas),
      armazenamento,
    );

    // 1. Pesquisa: nome e UF de cada localidade.
    await _pesquisar(tester, 'são josé');
    expect(chamadas.last.queryParameters['city'], 'são josé');
    expect(find.text('2 localidades encontradas'), findsOneWidget);
    expect(find.text('São José'), findsOneWidget);
    expect(find.text('São José dos Campos'), findsOneWidget);
    expect(find.text('SC'), findsOneWidget);
    expect(find.textContaining('UF: SP'), findsOneWidget);

    // 2. Seleciona a cidade => usa o código devolvido pelo serviço.
    await tester.tap(find.text('São José dos Campos'));
    await tester.pumpAndSettle();
    expect(chamadas.last.path, '/XML/cidade/4963/previsao.xml');

    // Previsão: data, mín/máx, descrição, ícone, IUV, atualização, fonte.
    expect(find.text('Atualização do CPTEC/INPE: 09/11/2026'), findsOneWidget);
    expect(find.text('Previsão para 4 dias'), findsOneWidget);
    expect(find.text('Terça-feira, 10/11/2026'), findsOneWidget);
    expect(find.text('Sexta-feira, 13/11/2026'), findsOneWidget);
    expect(find.text('Parcialmente Nublado'), findsNWidgets(2));
    expect(find.text('Chuva'), findsOneWidget);
    expect(find.text('Chuvas Isoladas'), findsOneWidget);
    expect(find.text('Mín. 14 °C'), findsNWidgets(2));
    expect(find.text('Máx. 26 °C'), findsOneWidget);
    expect(find.byIcon(Icons.umbrella), findsOneWidget);
    expect(find.byIcon(Icons.filter_drama), findsNWidgets(2));
    // IUV 0.0 = indisponível (oculto); 7.5 é exibido.
    expect(find.text('IUV 7.5 (Alto)'), findsOneWidget);
    expect(find.textContaining('IUV 0'), findsNothing);
    expect(find.textContaining('Fonte dos dados: CPTEC/INPE'), findsOneWidget);

    // Cidade e previsão foram salvas no dispositivo.
    expect(armazenamento.cidadesRecentes().first.id, 4963);
    expect(armazenamento.previsaoSalva(4963)!.previsao.dias, hasLength(4));

    // 3. Navega para o gráfico.
    await tester.tap(find.byKey(const Key('botaoGrafico')));
    await tester.pumpAndSettle();
    expect(find.text('Temperaturas - São José dos Campos'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final linhas = chart.data.lineBarsData;
    expect(linhas[0].spots.map((s) => s.y), [19, 23, 24, 26]); // máximas
    expect(linhas[1].spots.map((s) => s.y), [14, 15, 14, 17]); // mínimas
    expect(find.textContaining('Fonte dos dados: CPTEC/INPE'), findsOneWidget);

    // 4. Volta até a tela inicial: cidade aparece nas recentes.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Limpar pesquisa'));
    await tester.pumpAndSettle();
    expect(find.text('Consultas recentes'), findsOneWidget);
    expect(find.text('São José dos Campos - SP'), findsOneWidget);
  });

  testWidgets('informa quando nenhuma cidade é encontrada', (tester) async {
    await _abrirApp(
      tester,
      clienteSimulado(cidades: xmlCidadesVazio),
      await _armazenamento(),
    );
    await _pesquisar(tester, 'xyzqwe');
    expect(
      find.text('Nenhuma cidade encontrada para "xyzqwe".'),
      findsOneWidget,
    );
  });

  testWidgets('pede o nome quando a pesquisa está vazia', (tester) async {
    await _abrirApp(tester, clienteSimulado(), await _armazenamento());
    await _pesquisar(tester, '   ');
    expect(find.text('Informe o nome de uma cidade.'), findsOneWidget);
  });

  testWidgets('indicador de carregamento durante a pesquisa', (tester) async {
    final resposta = Completer<http.Response>();
    await _abrirApp(
      tester,
      MockClient((_) => resposta.future),
      await _armazenamento(),
    );
    await tester.enterText(find.byKey(const Key('campoBusca')), 'jacarei');
    await tester.tap(find.byKey(const Key('botaoPesquisar')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Pesquisando cidades...'), findsOneWidget);

    resposta.complete(respostaLatin1(xmlCidadesJacarei));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Jacareí'), findsOneWidget);
  });

  testWidgets('falha de conexão na pesquisa permite tentar novamente', (
    tester,
  ) async {
    var falhar = true;
    await _abrirApp(
      tester,
      MockClient((_) async {
        if (falhar) throw http.ClientException('Failed host lookup');
        return respostaLatin1(xmlCidadesJacarei);
      }),
      await _armazenamento(),
    );
    await _pesquisar(tester, 'jacarei');
    expect(find.textContaining('Falha de conexão'), findsOneWidget);

    falhar = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Jacareí'), findsOneWidget);
  });

  testWidgets('serviço indisponível e resposta inválida', (tester) async {
    var resposta = http.Response('erro', 503);
    await _abrirApp(
      tester,
      MockClient((_) async => resposta),
      await _armazenamento(),
    );
    await _pesquisar(tester, 'jacarei');
    expect(find.textContaining('indisponível'), findsOneWidget);

    resposta = http.Response('<html>', 200);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.textContaining('resposta inválida'), findsOneWidget);
  });

  testWidgets('mensagem quando não há previsão disponível', (tester) async {
    await _abrirApp(
      tester,
      clienteSimulado(previsao: xmlPrevisaoNula),
      await _armazenamento(),
    );
    await _pesquisar(tester, 'jacarei');
    await tester.tap(find.text('Jacareí'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhuma previsão disponível para Jacareí - SP no momento.'),
      findsOneWidget,
    );
    // Sem temperaturas, o botão do gráfico fica desabilitado.
    final botao = tester.widget<IconButton>(
      find.byKey(const Key('botaoGrafico')),
    );
    expect(botao.onPressed, isNull);
  });

  testWidgets('campos ausentes não encerram o app', (tester) async {
    await _abrirApp(
      tester,
      clienteSimulado(previsao: xmlPrevisaoIncompleta),
      await _armazenamento(),
    );
    await _pesquisar(tester, 'jacarei');
    await tester.tap(find.text('Jacareí'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Condição não informada'), findsOneWidget);
    expect(find.text('Data não informada'), findsOneWidget);
    expect(find.text('Máx. --'), findsNWidgets(2));
    expect(
      find.text('Atualização do CPTEC/INPE: Data não informada'),
      findsOneWidget,
    );
  });

  testWidgets('botão atualizar consulta novamente com indicador', (
    tester,
  ) async {
    var chamadas = 0;
    Completer<http.Response>? pendente;
    await _abrirApp(
      tester,
      MockClient((request) {
        if (request.url.path.endsWith('/listaCidades')) {
          return Future.value(respostaLatin1(xmlCidadesJacarei));
        }
        chamadas++;
        if (chamadas == 1) {
          return Future.value(respostaLatin1(xmlPrevisaoJacarei));
        }
        pendente = Completer<http.Response>();
        return pendente!.future;
      }),
      await _armazenamento(),
    );
    await _pesquisar(tester, 'jacarei');
    await tester.tap(find.text('Jacareí'));
    await tester.pumpAndSettle();
    expect(chamadas, 1);

    await tester.tap(find.byKey(const Key('botaoAtualizar')));
    await tester.pump();
    expect(chamadas, 2);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    pendente!.complete(respostaLatin1(xmlPrevisaoJacarei));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('sem internet: exibe a previsão salva no dispositivo', (
    tester,
  ) async {
    final armazenamento = await _armazenamento();
    await armazenamento.registrarCidade(jacarei);
    await armazenamento.salvarPrevisao(
      jacarei.id,
      const CptecParser().parsePrevisao(xmlPrevisaoJacarei),
      agora: DateTime(2026, 11, 9, 20, 15),
    );

    await _abrirApp(
      tester,
      MockClient((_) async => throw http.ClientException('offline')),
      armazenamento,
    );
    // A cidade aparece nas consultas recentes (persistência).
    expect(find.text('Consultas recentes'), findsOneWidget);
    await tester.tap(find.text('Jacareí - SP'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Exibindo previsão salva no dispositivo em 09/11/2026 às 20:15.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Falha de conexão'), findsWidgets);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Terça-feira, 10/11/2026'), findsOneWidget);

    // Ao voltar, o aviso de erro não fica sobre a tela inicial.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('erro sem previsão salva mostra tentar novamente', (
    tester,
  ) async {
    var falhar = true;
    await _abrirApp(
      tester,
      MockClient((request) async {
        if (request.url.path.endsWith('/listaCidades')) {
          return respostaLatin1(xmlCidadesJacarei);
        }
        if (falhar) return http.Response('erro', 500);
        return respostaLatin1(xmlPrevisaoJacarei);
      }),
      await _armazenamento(),
    );
    await _pesquisar(tester, 'jacarei');
    await tester.tap(find.text('Jacareí'));
    await tester.pumpAndSettle();
    expect(find.textContaining('indisponível'), findsOneWidget);

    falhar = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Previsão para 4 dias'), findsOneWidget);
  });

  testWidgets('remover e limpar consultas recentes', (tester) async {
    final armazenamento = await _armazenamento();
    await armazenamento.registrarCidade(jacarei);
    await armazenamento.registrarCidade(
      const Cidade(id: 244, nome: 'São Paulo', uf: 'SP'),
    );
    await _abrirApp(tester, clienteSimulado(), armazenamento);

    await tester.tap(find.byTooltip('Remover').first);
    await tester.pumpAndSettle();
    expect(find.text('São Paulo - SP'), findsNothing);
    expect(find.text('Jacareí - SP'), findsOneWidget);

    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pesquise uma cidade'), findsOneWidget);
    expect(armazenamento.cidadesRecentes(), isEmpty);
  });

  testWidgets('gráfico sem temperaturas mostra mensagem', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GraficoScreen(cidade: jacarei, previsao: PrevisaoCidade()),
      ),
    );
    expect(find.textContaining('Não há temperaturas'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('Fonte dos dados: CPTEC/INPE'), findsOneWidget);
  });
}
