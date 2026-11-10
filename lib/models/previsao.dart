import '../services/condicoes_tempo.dart';

/// Previsão de um único dia (elemento `<previsao>` do XML).
///
/// Todos os campos são opcionais porque o serviço pode omiti-los ou
/// devolver o texto "null".
class PrevisaoDia {
  const PrevisaoDia({
    this.data,
    this.sigla,
    this.minima,
    this.maxima,
    this.iuv,
  });

  final DateTime? data;
  final String? sigla;
  final double? minima;
  final double? maxima;
  final double? iuv;

  /// Descrição legível da condição do tempo (ex.: "Chuva").
  String get descricao => CondicoesTempo.descricao(sigla);

  /// O índice UV só é considerado disponível quando é maior que zero
  /// (o CPTEC devolve "0.0" quando ainda não calculou o índice).
  bool get iuvDisponivel => iuv != null && iuv! > 0;

  /// Indica se o dia tem alguma informação útil para exibir.
  bool get possuiDados =>
      data != null || sigla != null || minima != null || maxima != null;

  Map<String, dynamic> toJson() => {
    'data': data?.toIso8601String(),
    'sigla': sigla,
    'minima': minima,
    'maxima': maxima,
    'iuv': iuv,
  };

  factory PrevisaoDia.fromJson(Map<String, dynamic> json) => PrevisaoDia(
    data: _data(json['data']),
    sigla: json['sigla'] is String ? json['sigla'] as String : null,
    minima: _numero(json['minima']),
    maxima: _numero(json['maxima']),
    iuv: _numero(json['iuv']),
  );
}

/// Previsão completa de uma cidade (elemento raiz `<cidade>` do XML).
class PrevisaoCidade {
  const PrevisaoCidade({
    this.nome,
    this.uf,
    this.atualizacao,
    this.dias = const [],
  });

  final String? nome;
  final String? uf;

  /// Data de atualização informada pelo serviço.
  final DateTime? atualizacao;
  final List<PrevisaoDia> dias;

  /// Verdadeiro quando o serviço não devolveu nenhum dia com dados.
  bool get vazia => dias.isEmpty;

  /// Dias que possuem mínima e máxima, usados no gráfico.
  List<PrevisaoDia> get diasComTemperatura =>
      dias.where((d) => d.minima != null && d.maxima != null).toList();

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'uf': uf,
    'atualizacao': atualizacao?.toIso8601String(),
    'dias': dias.map((d) => d.toJson()).toList(),
  };

  factory PrevisaoCidade.fromJson(Map<String, dynamic> json) {
    final dias = json['dias'];
    return PrevisaoCidade(
      nome: json['nome'] is String ? json['nome'] as String : null,
      uf: json['uf'] is String ? json['uf'] as String : null,
      atualizacao: _data(json['atualizacao']),
      dias: dias is List
          ? dias
                .whereType<Map<String, dynamic>>()
                .map(PrevisaoDia.fromJson)
                .toList()
          : const [],
    );
  }
}

DateTime? _data(Object? valor) =>
    valor is String ? DateTime.tryParse(valor) : null;

double? _numero(Object? valor) => valor is num ? valor.toDouble() : null;
