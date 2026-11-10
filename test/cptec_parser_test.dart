import 'package:atividade2_previsao_tempo/services/cptec_exception.dart';
import 'package:atividade2_previsao_tempo/services/cptec_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  const parser = CptecParser();

  group('parseCidades', () {
    test('lê nome, UF e código da localidade', () {
      final cidades = parser.parseCidades(xmlCidadesJacarei);
      expect(cidades, hasLength(1));
      expect(cidades.first.nome, 'Jacareí');
      expect(cidades.first.uf, 'SP');
      expect(cidades.first.id, 2680);
      expect(cidades.first.nomeComUf, 'Jacareí - SP');
    });

    test('lê várias cidades', () {
      final cidades = parser.parseCidades(xmlCidadesSaoJose);
      expect(cidades.map((c) => c.id), [4909, 4963]);
    });

    test('lista vazia quando nenhuma cidade é encontrada', () {
      expect(parser.parseCidades(xmlCidadesVazio), isEmpty);
    });

    test('ignora cidades sem código ou sem nome e aceita UF ausente', () {
      final cidades = parser.parseCidades(
        '<cidades>'
        '<cidade><nome>Sem id</nome><uf>SP</uf></cidade>'
        '<cidade><nome>null</nome><uf>SP</uf><id>1</id></cidade>'
        '<cidade><nome>Id ruim</nome><id>abc</id></cidade>'
        '<cidade><nome>Sem UF</nome><id>7</id></cidade>'
        '</cidades>',
      );
      expect(cidades, hasLength(1));
      expect(cidades.single.nome, 'Sem UF');
      expect(cidades.single.uf, '');
      expect(cidades.single.nomeComUf, 'Sem UF');
    });

    test('XML malformado gera respostaInvalida', () {
      expect(
        () => parser.parseCidades('<cidades><cidade>'),
        throwsA(
          isA<CptecException>().having(
            (e) => e.tipo,
            'tipo',
            TipoFalha.respostaInvalida,
          ),
        ),
      );
    });

    test('HTML no lugar do XML gera respostaInvalida', () {
      expect(
        () => parser.parseCidades('<html><body>Erro</body></html>'),
        throwsA(isA<CptecException>()),
      );
      expect(() => parser.parseCidades(''), throwsA(isA<CptecException>()));
    });
  });

  group('parsePrevisao', () {
    test('lê os 4 dias, temperaturas, sigla, IUV e atualização', () {
      final p = parser.parsePrevisao(xmlPrevisaoJacarei);
      expect(p.nome, 'Jacareí');
      expect(p.uf, 'SP');
      expect(p.atualizacao, DateTime(2026, 11, 9));
      expect(p.dias, hasLength(4));
      expect(p.vazia, isFalse);

      final primeiro = p.dias.first;
      expect(primeiro.data, DateTime(2026, 11, 10));
      expect(primeiro.sigla, 'pn');
      expect(primeiro.descricao, 'Parcialmente Nublado');
      expect(primeiro.minima, 14);
      expect(primeiro.maxima, 19);
      expect(primeiro.iuv, 0.0);
      expect(primeiro.iuvDisponivel, isFalse);

      expect(p.dias.last.iuv, 7.5);
      expect(p.dias.last.iuvDisponivel, isTrue);
      expect(p.dias[2].descricao, 'Chuva');
    });

    test(
      'código inexistente ("null" em todos os campos) => previsão vazia',
      () {
        final p = parser.parsePrevisao(xmlPrevisaoNula);
        expect(p.vazia, isTrue);
        expect(p.nome, isNull);
        expect(p.uf, isNull);
        expect(p.atualizacao, isNull);
      },
    );

    test('campos ausentes ou inválidos viram null sem erro', () {
      final p = parser.parsePrevisao(xmlPrevisaoIncompleta);
      expect(p.nome, 'Teste');
      expect(p.uf, isNull);
      expect(p.atualizacao, isNull);
      expect(p.dias, hasLength(2)); // o <previsao> vazio é descartado
      expect(p.dias[0].data, DateTime(2026, 11, 10));
      expect(p.dias[0].maxima, isNull);
      expect(p.dias[0].sigla, isNull);
      expect(p.dias[0].descricao, 'Condição não informada');
      expect(p.dias[1].data, isNull);
      expect(p.dias[1].minima, 10);
      expect(p.dias[1].descricao, 'Condição não informada (xx)');
      expect(p.diasComTemperatura, isEmpty);
    });

    test('datas inválidas viram null e decimais com vírgula são aceitos', () {
      final p = parser.parsePrevisao(
        '<cidade><atualizacao>2026-13-01</atualizacao>'
        '<previsao><dia>10/11/2026</dia><maxima>20,5</maxima></previsao>'
        '<previsao><dia>2026-11-xx</dia><minima>1</minima></previsao>'
        '<previsao><dia>2026-11-00</dia><minima>2</minima></previsao>'
        '</cidade>',
      );
      expect(p.atualizacao, isNull);
      expect(p.dias.map((d) => d.data), everyElement(isNull));
      expect(p.dias.first.maxima, 20.5);
    });

    test('raiz diferente de <cidade> gera respostaInvalida', () {
      expect(
        () => parser.parsePrevisao(xmlCidadesJacarei),
        throwsA(
          isA<CptecException>().having(
            (e) => e.tipo,
            'tipo',
            TipoFalha.respostaInvalida,
          ),
        ),
      );
    });

    test('XML malformado gera respostaInvalida', () {
      expect(
        () => parser.parsePrevisao('isto não é xml'),
        throwsA(isA<CptecException>()),
      );
    });
  });
}
