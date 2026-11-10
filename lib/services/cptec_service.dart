import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cidade.dart';
import '../models/previsao.dart';
import 'cptec_exception.dart';
import 'cptec_parser.dart';

/// Acesso ao serviço XML de previsão do tempo do CPTEC/INPE.
///
/// Documentação: https://servicos.cptec.inpe.br/XML/
class CptecService {
  CptecService({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.parser = const CptecParser(),
  }) : _client = client ?? http.Client();

  static const String baseUrl = 'https://servicos.cptec.inpe.br/XML';

  final http.Client _client;
  final Duration timeout;
  final CptecParser parser;

  /// Endereço da busca de localidades (parâmetro `city`).
  static Uri urlCidades(String nome) =>
      Uri.parse('$baseUrl/listaCidades')
          .replace(queryParameters: {'city': nome});

  /// Endereço da previsão para 4 dias, usando o código da localidade.
  static Uri urlPrevisao(int codigo) =>
      Uri.parse('$baseUrl/cidade/$codigo/previsao.xml');

  /// Pesquisa localidades pelo nome. Lista vazia = nenhuma encontrada.
  Future<List<Cidade>> buscarCidades(String nome) async {
    final termo = nome.trim();
    if (termo.isEmpty) return const [];
    final xml = await _get(urlCidades(termo));
    return parser.parseCidades(xml);
  }

  /// Consulta a previsão para 4 dias da localidade [codigo].
  Future<PrevisaoCidade> buscarPrevisao(int codigo) async {
    final xml = await _get(urlPrevisao(codigo));
    return parser.parsePrevisao(xml);
  }

  Future<String> _get(Uri url) async {
    final http.Response resposta;
    try {
      resposta = await _client.get(url).timeout(timeout);
    } on TimeoutException {
      throw const CptecException(TipoFalha.tempoEsgotado);
    } on http.ClientException catch (e) {
      // Inclui SocketException/HandshakeException encapsuladas pelo http.
      throw CptecException(TipoFalha.semConexao, e.message);
    } catch (e) {
      throw CptecException(TipoFalha.semConexao, e.toString());
    }

    if (resposta.statusCode != 200) {
      throw CptecException(
        TipoFalha.servicoIndisponivel,
        'HTTP ${resposta.statusCode}',
      );
    }
    return decodificar(resposta.bodyBytes);
  }

  /// O CPTEC envia os XMLs em ISO-8859-1 (latin1). Se a declaração do
  /// XML indicar UTF-8, decodifica como UTF-8.
  static String decodificar(List<int> bytes) {
    final inicio = latin1
        .decode(bytes.take(100).toList(), allowInvalid: true)
        .toLowerCase();
    if (inicio.contains('utf-8')) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    return latin1.decode(bytes, allowInvalid: true);
  }

  void fechar() => _client.close();
}
