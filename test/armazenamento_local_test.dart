import 'package:atividade2_previsao_tempo/data/armazenamento_local.dart';
import 'package:atividade2_previsao_tempo/models/cidade.dart';
import 'package:atividade2_previsao_tempo/services/cptec_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

void main() {
  const jacarei = Cidade(id: 2680, nome: 'Jacareí', uf: 'SP');
  const sp = Cidade(id: 244, nome: 'São Paulo', uf: 'SP');

  Future<ArmazenamentoLocal> abrir([Map<String, Object> inicial = const {}]) {
    SharedPreferences.setMockInitialValues(inicial);
    return ArmazenamentoLocal.abrir();
  }

  group('cidades recentes', () {
    test('começa vazio', () async {
      expect((await abrir()).cidadesRecentes(), isEmpty);
    });

    test('mais recente primeiro e sem repetição', () async {
      final a = await abrir();
      await a.registrarCidade(jacarei);
      await a.registrarCidade(sp);
      await a.registrarCidade(jacarei);
      expect(a.cidadesRecentes(), [jacarei, sp]);
    });

    test('limita a quantidade de recentes', () async {
      final a = await abrir();
      for (var i = 0; i < 15; i++) {
        await a.registrarCidade(Cidade(id: i, nome: 'C$i', uf: 'SP'));
      }
      final recentes = a.cidadesRecentes();
      expect(recentes, hasLength(ArmazenamentoLocal.limiteRecentes));
      expect(recentes.first.id, 14);
    });

    test('persiste entre instâncias (mesmo SharedPreferences)', () async {
      final a = await abrir();
      await a.registrarCidade(jacarei);
      final b = await ArmazenamentoLocal.abrir();
      expect(b.cidadesRecentes(), [jacarei]);
    });

    test('remover cidade também apaga a previsão salva', () async {
      final a = await abrir();
      await a.registrarCidade(jacarei);
      await a.registrarCidade(sp);
      await a.salvarPrevisao(
        jacarei.id,
        const CptecParser().parsePrevisao(xmlPrevisaoJacarei),
      );
      await a.removerCidade(jacarei);
      expect(a.cidadesRecentes(), [sp]);
      expect(a.previsaoSalva(jacarei.id), isNull);
    });

    test('limparTudo remove só as chaves do app', () async {
      final a = await abrir({'outra_chave': 'x'});
      await a.registrarCidade(jacarei);
      await a.salvarPrevisao(
        1,
        const CptecParser().parsePrevisao(xmlPrevisaoJacarei),
      );
      await a.limparTudo();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'outra_chave'});
    });

    test('dados corrompidos não quebram o app', () async {
      expect(
        (await abrir({ArmazenamentoLocal.chaveRecentes: '{{'}))
            .cidadesRecentes(),
        isEmpty,
      );
      expect(
        (await abrir({ArmazenamentoLocal.chaveRecentes: '{"a":1}'}))
            .cidadesRecentes(),
        isEmpty,
      );
      expect(
        (await abrir({
          ArmazenamentoLocal.chaveRecentes:
              '[{"id":"x","nome":"A"},{"id":1,"nome":"B"}]',
        })).cidadesRecentes(),
        [const Cidade(id: 1, nome: 'B', uf: '')],
      );
    });
  });

  group('previsão salva', () {
    test('salva e recupera a previsão com a data de gravação', () async {
      final a = await abrir();
      final previsao = const CptecParser().parsePrevisao(xmlPrevisaoJacarei);
      final agora = DateTime(2026, 11, 9, 21, 30);
      await a.salvarPrevisao(2680, previsao, agora: agora);

      final salva = a.previsaoSalva(2680)!;
      expect(salva.salvaEm, agora);
      expect(salva.previsao.nome, 'Jacareí');
      expect(salva.previsao.atualizacao, DateTime(2026, 11, 9));
      expect(salva.previsao.dias, hasLength(4));
      expect(salva.previsao.dias.first.descricao, 'Parcialmente Nublado');
      expect(salva.previsao.dias.last.iuv, 7.5);
      expect(salva.previsao.dias.first.minima, 14);
    });

    test('sem previsão salva => null', () async {
      expect((await abrir()).previsaoSalva(1), isNull);
    });

    test('previsão corrompida => null', () async {
      for (final valor in [
        'não é json',
        '[]',
        '{"salvaEm":"x","previsao":{}}',
        '{"salvaEm":"2026-11-09","previsao":[]}',
        '{"salvaEm":5,"previsao":{}}',
      ]) {
        final a = await abrir({
          '${ArmazenamentoLocal.prefixoPrevisao}1': valor,
        });
        expect(a.previsaoSalva(1), isNull, reason: valor);
      }
    });
  });
}
