import 'package:atividade2_previsao_tempo/models/previsao.dart';
import 'package:atividade2_previsao_tempo/services/condicoes_tempo.dart';
import 'package:atividade2_previsao_tempo/utils/formatacao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CondicoesTempo', () {
    test('tabela contém as 40 siglas da documentação do CPTEC', () {
      expect(CondicoesTempo.descricoes, hasLength(40));
    });

    test('converte siglas em descrições', () {
      expect(CondicoesTempo.descricao('cl'), 'Céu Claro');
      expect(CondicoesTempo.descricao('ps'), 'Predomínio de Sol');
      expect(CondicoesTempo.descricao('t'), 'Tempestade');
      expect(CondicoesTempo.descricao(' PN '), 'Parcialmente Nublado');
      expect(
        CondicoesTempo.descricao('ppm'),
        'Poss. de Panc. de Chuva pela Manhã',
      );
    });

    test('sigla ausente ou desconhecida não gera erro', () {
      expect(CondicoesTempo.descricao(null), 'Condição não informada');
      expect(CondicoesTempo.descricao(''), 'Condição não informada');
      expect(CondicoesTempo.descricao('zz'), 'Condição não informada (zz)');
      expect(CondicoesTempo.icone('zz'), Icons.help_outline);
      expect(CondicoesTempo.cor(null), Colors.grey);
    });

    test('todas as siglas têm ícone e cor definidos', () {
      for (final sigla in CondicoesTempo.descricoes.keys) {
        if (sigla == 'nd') continue; // "Não Definido" usa o ícone padrão
        expect(
          CondicoesTempo.icone(sigla),
          isNot(Icons.help_outline),
          reason: sigla,
        );
        expect(CondicoesTempo.cor(sigla), isA<Color>());
      }
    });

    test('ícones e cores representativos', () {
      expect(CondicoesTempo.icone('cl'), Icons.wb_sunny);
      expect(CondicoesTempo.cor('cl'), Colors.orange);
      expect(CondicoesTempo.icone('t'), Icons.thunderstorm);
      expect(CondicoesTempo.cor('t'), Colors.deepPurple);
      expect(CondicoesTempo.icone('c'), Icons.umbrella);
      expect(CondicoesTempo.cor('c'), Colors.blue);
      expect(CondicoesTempo.icone('g'), Icons.ac_unit);
      expect(CondicoesTempo.cor('g'), Colors.lightBlue);
      expect(CondicoesTempo.icone('n'), Icons.cloud);
      expect(CondicoesTempo.cor('n'), Colors.blueGrey);
      expect(CondicoesTempo.icone('nv'), Icons.foggy);
    });
  });

  group('formatação', () {
    final terca = DateTime(2026, 11, 10, 9, 5);

    test('datas', () {
      expect(formatarData(terca), '10/11/2026');
      expect(formatarData(null), 'Data não informada');
      expect(formatarDiaMes(terca), '10/11');
      expect(formatarDiaMes(null), '--');
      expect(diaDaSemana(terca), 'Terça-feira');
      expect(diaDaSemana(DateTime(2026, 11, 15)), 'Domingo');
      expect(diaDaSemana(null), '');
      expect(formatarDataHora(terca), '10/11/2026 às 09:05');
    });

    test('temperatura', () {
      expect(formatarTemperatura(19), '19 °C');
      expect(formatarTemperatura(19.6), '20 °C');
      expect(formatarTemperatura(null), '--');
    });

    test('índice UV', () {
      expect(formatarIuv(2), 'IUV 2 (Baixo)');
      expect(formatarIuv(5.5), 'IUV 5.5 (Moderado)');
      expect(formatarIuv(7), 'IUV 7 (Alto)');
      expect(formatarIuv(9), 'IUV 9 (Muito alto)');
      expect(formatarIuv(12.3), 'IUV 12.3 (Extremo)');
    });
  });

  group('modelos JSON', () {
    test('PrevisaoDia ignora valores de tipo errado', () {
      final d = PrevisaoDia.fromJson({
        'data': 123,
        'sigla': 5,
        'minima': 'x',
        'maxima': 20,
        'iuv': null,
      });
      expect(d.data, isNull);
      expect(d.sigla, isNull);
      expect(d.minima, isNull);
      expect(d.maxima, 20);
      expect(d.iuvDisponivel, isFalse);
    });

    test('PrevisaoCidade sem lista de dias', () {
      final p = PrevisaoCidade.fromJson({'nome': 1, 'dias': 'x'});
      expect(p.nome, isNull);
      expect(p.vazia, isTrue);
    });
  });
}
