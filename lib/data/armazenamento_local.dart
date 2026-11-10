import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cidade.dart';
import '../models/previsao.dart';

/// Previsão guardada no dispositivo, com o momento em que foi salva.
class PrevisaoSalva {
  const PrevisaoSalva({required this.previsao, required this.salvaEm});

  final PrevisaoCidade previsao;
  final DateTime salvaEm;
}

/// Persistência local usando `shared_preferences` (pares chave/valor),
/// com os objetos serializados em JSON.
///
/// * `cidades_recentes`: lista (JSON) das últimas cidades consultadas,
///   da mais recente para a mais antiga, sem repetição, até [limiteRecentes].
/// * `previsao_<codigo>`: última previsão obtida com sucesso para cada
///   cidade, usada para exibir os dados sem internet.
class ArmazenamentoLocal {
  ArmazenamentoLocal(this._prefs);

  static const String chaveRecentes = 'cidades_recentes';
  static const String prefixoPrevisao = 'previsao_';
  static const int limiteRecentes = 10;

  final SharedPreferences _prefs;

  static Future<ArmazenamentoLocal> abrir() async =>
      ArmazenamentoLocal(await SharedPreferences.getInstance());

  // ---------------------------------------------------------------- Cidades

  List<Cidade> cidadesRecentes() {
    final json = _prefs.getString(chaveRecentes);
    if (json == null) return [];
    try {
      final lista = jsonDecode(json);
      if (lista is! List) return [];
      return lista
          .whereType<Map<String, dynamic>>()
          .map(Cidade.fromJson)
          .whereType<Cidade>()
          .toList();
    } on FormatException {
      return [];
    }
  }

  /// Coloca [cidade] no topo da lista de recentes.
  Future<void> registrarCidade(Cidade cidade) async {
    final lista = cidadesRecentes()
      ..removeWhere((c) => c.id == cidade.id)
      ..insert(0, cidade);
    final limitada = lista.take(limiteRecentes).map((c) => c.toJson()).toList();
    await _prefs.setString(chaveRecentes, jsonEncode(limitada));
  }

  Future<void> removerCidade(Cidade cidade) async {
    final lista = cidadesRecentes()..removeWhere((c) => c.id == cidade.id);
    await _prefs.setString(
      chaveRecentes,
      jsonEncode(lista.map((c) => c.toJson()).toList()),
    );
    await _prefs.remove('$prefixoPrevisao${cidade.id}');
  }

  /// Apaga as cidades recentes e todas as previsões salvas.
  Future<void> limparTudo() async {
    for (final chave in _prefs.getKeys().toList()) {
      if (chave == chaveRecentes || chave.startsWith(prefixoPrevisao)) {
        await _prefs.remove(chave);
      }
    }
  }

  // --------------------------------------------------------------- Previsão

  Future<void> salvarPrevisao(
    int codigo,
    PrevisaoCidade previsao, {
    DateTime? agora,
  }) async {
    final dados = {
      'salvaEm': (agora ?? DateTime.now()).toIso8601String(),
      'previsao': previsao.toJson(),
    };
    await _prefs.setString('$prefixoPrevisao$codigo', jsonEncode(dados));
  }

  /// Última previsão salva da cidade, ou `null` se não houver/estiver
  /// corrompida.
  PrevisaoSalva? previsaoSalva(int codigo) {
    final json = _prefs.getString('$prefixoPrevisao$codigo');
    if (json == null) return null;
    try {
      final dados = jsonDecode(json);
      if (dados is! Map<String, dynamic>) return null;
      final salvaEm = DateTime.tryParse(dados['salvaEm'] as String? ?? '');
      final previsao = dados['previsao'];
      if (salvaEm == null || previsao is! Map<String, dynamic>) return null;
      return PrevisaoSalva(
        previsao: PrevisaoCidade.fromJson(previsao),
        salvaEm: salvaEm,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
