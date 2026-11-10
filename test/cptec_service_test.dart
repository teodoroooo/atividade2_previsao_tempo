import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:atividade2_previsao_tempo/services/cptec_exception.dart';
import 'package:atividade2_previsao_tempo/services/cptec_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

Matcher falha(TipoFalha tipo) =>
    throwsA(isA<CptecException>().having((e) => e.tipo, 'tipo', tipo));

void main() {
  group('URLs', () {
    test('busca usa o parâmetro city codificado', () {
      final url = CptecService.urlCidades('são josé');
      expect(url.host, 'servicos.cptec.inpe.br');
      expect(url.path, '/XML/listaCidades');
      expect(url.queryParameters['city'], 'são josé');
      expect(url.toString(), contains('city=s%C3%A3o+jos%C3%A9'));
    });

    test('previsão usa o código da localidade', () {
      expect(
        CptecService.urlPrevisao(2680).toString(),
        'https://servicos.cptec.inpe.br/XML/cidade/2680/previsao.xml',
      );
    });
  });

  group('buscarCidades', () {
    test('faz a requisição e decodifica ISO-8859-1 (acentos)', () async {
      final chamadas = <Uri>[];
      final service = CptecService(client: clienteSimulado(chamadas: chamadas));
      final cidades = await service.buscarCidades('  jacarei ');
      expect(cidades.single.nome, 'Jacareí');
      expect(chamadas.single.queryParameters['city'], 'jacarei');
    });

    test('termo vazio não faz requisição', () async {
      final chamadas = <Uri>[];
      final service = CptecService(client: clienteSimulado(chamadas: chamadas));
      expect(await service.buscarCidades('   '), isEmpty);
      expect(chamadas, isEmpty);
    });

    test('nenhuma cidade encontrada => lista vazia', () async {
      final service = CptecService(
        client: clienteSimulado(cidades: xmlCidadesVazio),
      );
      expect(await service.buscarCidades('xyz'), isEmpty);
    });
  });

  group('buscarPrevisao', () {
    test('retorna os dias da previsão', () async {
      final chamadas = <Uri>[];
      final service = CptecService(client: clienteSimulado(chamadas: chamadas));
      final p = await service.buscarPrevisao(2680);
      expect(p.dias, hasLength(4));
      expect(p.nome, 'Jacareí');
      expect(chamadas.single.path, '/XML/cidade/2680/previsao.xml');
    });
  });

  group('tratamento de erros', () {
    test('HTTP 500/503 => serviço indisponível', () async {
      for (final status in [500, 503, 404]) {
        final service = CptecService(
          client: MockClient((_) async => http.Response('erro', status)),
        );
        await expectLater(
          service.buscarPrevisao(1),
          falha(TipoFalha.servicoIndisponivel),
        );
      }
    });

    test('falha de rede => sem conexão', () async {
      final service = CptecService(
        client: MockClient(
          (_) async => throw http.ClientException('Failed host lookup'),
        ),
      );
      await expectLater(
        service.buscarCidades('x'),
        falha(TipoFalha.semConexao),
      );
    });

    test('SocketException => sem conexão', () async {
      final service = CptecService(
        client: MockClient(
          (_) async => throw const SocketException('Network is unreachable'),
        ),
      );
      await expectLater(
        service.buscarCidades('x'),
        falha(TipoFalha.semConexao),
      );
    });

    test('demora excessiva => tempo esgotado', () async {
      final service = CptecService(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) => Completer<http.Response>().future),
      );
      await expectLater(
        service.buscarPrevisao(1),
        falha(TipoFalha.tempoEsgotado),
      );
    });

    test('resposta que não é XML => resposta inválida', () async {
      final service = CptecService(
        client: MockClient((_) async => http.Response('<html>oops', 200)),
      );
      await expectLater(
        service.buscarCidades('x'),
        falha(TipoFalha.respostaInvalida),
      );
    });

    test('todas as falhas têm mensagem para o usuário', () {
      for (final tipo in TipoFalha.values) {
        final e = CptecException(tipo, 'detalhe');
        expect(e.mensagem, isNotEmpty);
        expect(e.toString(), contains('detalhe'));
      }
      expect(
        const CptecException(TipoFalha.semConexao).toString(),
        isNot(contains(':')),
      );
    });
  });

  group('decodificar', () {
    test('latin1 por padrão', () {
      expect(
        CptecService.decodificar(latin1.encode('<a>Jacareí</a>')),
        '<a>Jacareí</a>',
      );
    });

    test('UTF-8 quando declarado no XML', () {
      const xml = "<?xml version='1.0' encoding='UTF-8'?><a>São Paulo</a>";
      expect(CptecService.decodificar(utf8.encode(xml)), xml);
    });
  });

  test('fechar encerra o cliente', () {
    var fechado = false;
    final cliente = _ClienteFechavel(() => fechado = true);
    CptecService(client: cliente).fechar();
    expect(fechado, isTrue);
  });
}

class _ClienteFechavel extends http.BaseClient {
  _ClienteFechavel(this.aoFechar);

  final void Function() aoFechar;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() => aoFechar();
}
