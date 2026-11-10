import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/cidade.dart';
import '../models/previsao.dart';
import '../utils/formatacao.dart';
import '../widgets/comuns.dart';

/// Gráfico de linhas com as temperaturas mínima e máxima de cada dia.
class GraficoScreen extends StatelessWidget {
  const GraficoScreen({
    super.key,
    required this.cidade,
    required this.previsao,
  });

  final Cidade cidade;
  final PrevisaoCidade previsao;

  static const Color corMaxima = Colors.red;
  static const Color corMinima = Colors.blue;

  @override
  Widget build(BuildContext context) {
    final dias = previsao.diasComTemperatura;
    return Scaffold(
      appBar: AppBar(title: Text('Temperaturas - ${cidade.nome}')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _conteudo(context, dias)),
            const FonteDados(),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context, List<PrevisaoDia> dias) {
    if (dias.isEmpty) {
      return const MensagemEstado(
        icone: Icons.insert_chart_outlined,
        mensagem: 'Não há temperaturas disponíveis para montar o gráfico.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Temperaturas mínima e máxima (°C)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 16,
          children: [
            _Legenda(cor: corMaxima, texto: 'Máxima'),
            _Legenda(cor: corMinima, texto: 'Mínima'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 16),
            child: _GraficoTemperaturas(dias: dias),
          ),
        ),
        const SizedBox(height: 16),
        _TabelaTemperaturas(dias: dias),
      ],
    );
  }
}

class _GraficoTemperaturas extends StatelessWidget {
  const _GraficoTemperaturas({required this.dias});

  final List<PrevisaoDia> dias;

  @override
  Widget build(BuildContext context) {
    final minimas = [
      for (var i = 0; i < dias.length; i++)
        FlSpot(i.toDouble(), dias[i].minima!),
    ];
    final maximas = [
      for (var i = 0; i < dias.length; i++)
        FlSpot(i.toDouble(), dias[i].maxima!),
    ];
    final menor = dias.map((d) => d.minima!).reduce(math.min);
    final maior = dias.map((d) => d.maxima!).reduce(math.max);
    final minY = (menor / 5).floor() * 5.0 - 5;
    final maxY = (maior / 5).ceil() * 5.0 + 5;

    LineChartBarData linha(List<FlSpot> pontos, Color cor) => LineChartBarData(
      spots: pontos,
      color: cor,
      barWidth: 3,
      isCurved: true,
      preventCurveOverShooting: true,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: cor.withAlpha(25)),
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(1, dias.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          linha(maximas, GraficoScreen.corMaxima),
          linha(minimas, GraficoScreen.corMinima),
        ],
        gridData: const FlGridData(show: true, horizontalInterval: 5),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              reservedSize: 40,
              getTitlesWidget: (valor, meta) =>
                  SideTitleWidget(meta: meta, child: Text('${valor.toInt()}°')),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 32,
              getTitlesWidget: (valor, meta) {
                final i = valor.toInt();
                if (i < 0 || i >= dias.length || valor != i.toDouble()) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(formatarDiaMes(dias[i].data)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (pontos) => pontos
                .map(
                  (p) => LineTooltipItem(
                    '${p.y.round()} °C',
                    TextStyle(color: p.bar.color, fontWeight: FontWeight.bold),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _TabelaTemperaturas extends StatelessWidget {
  const _TabelaTemperaturas({required this.dias});

  final List<PrevisaoDia> dias;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final d in dias)
              ListTile(
                dense: true,
                title: Text(
                  '${diaDaSemana(d.data)}, ${formatarDiaMes(d.data)}',
                ),
                trailing: Text(
                  'Mín. ${formatarTemperatura(d.minima)}  •  '
                  'Máx. ${formatarTemperatura(d.maxima)}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.cor, required this.texto});

  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 4, color: cor),
        const SizedBox(width: 6),
        Text(texto),
      ],
    );
  }
}
