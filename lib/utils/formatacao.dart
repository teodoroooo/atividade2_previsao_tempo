/// Funções de formatação de datas e números em português.
library;

const List<String> _diasSemana = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];

String _doisDigitos(int n) => n.toString().padLeft(2, '0');

/// 10/11/2026
String formatarData(DateTime? data) {
  if (data == null) return 'Data não informada';
  return '${_doisDigitos(data.day)}/${_doisDigitos(data.month)}/${data.year}';
}

/// 10/11
String formatarDiaMes(DateTime? data) {
  if (data == null) return '--';
  return '${_doisDigitos(data.day)}/${_doisDigitos(data.month)}';
}

/// Terça-feira
String diaDaSemana(DateTime? data) =>
    data == null ? '' : _diasSemana[data.weekday - 1];

/// 10/11/2026 às 14:05
String formatarDataHora(DateTime data) =>
    '${formatarData(data)} às ${_doisDigitos(data.hour)}:${_doisDigitos(data.minute)}';

/// 19 °C ou "--" quando ausente.
String formatarTemperatura(double? valor) =>
    valor == null ? '--' : '${valor.round()} °C';

/// Classificação do índice UV (OMS).
String classificarIuv(double iuv) {
  if (iuv < 3) return 'Baixo';
  if (iuv < 6) return 'Moderado';
  if (iuv < 8) return 'Alto';
  if (iuv < 11) return 'Muito alto';
  return 'Extremo';
}

/// "IUV 7.5 (Alto)"
String formatarIuv(double iuv) {
  final valor = iuv == iuv.roundToDouble()
      ? iuv.toStringAsFixed(0)
      : iuv.toStringAsFixed(1);
  return 'IUV $valor (${classificarIuv(iuv)})';
}
