import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Respostas reais do CPTEC/INPE (capturadas em 09/11/2026).
const String xmlCidadesJacarei =
    "<?xml version='1.0' encoding='ISO-8859-1'?><cidades><cidade>"
    '<nome>Jacareí</nome><uf>SP</uf><id>2680</id></cidade></cidades>';

const String xmlCidadesSaoJose =
    "<?xml version='1.0' encoding='ISO-8859-1'?><cidades>"
    '<cidade><nome>São José</nome><uf>SC</uf><id>4909</id></cidade>'
    '<cidade><nome>São José dos Campos</nome><uf>SP</uf><id>4963</id></cidade>'
    '</cidades>';

const String xmlCidadesVazio =
    "<?xml version='1.0' encoding='ISO-8859-1'?><cidades></cidades>";

const String xmlPrevisaoJacarei =
    "<?xml version='1.0' encoding='ISO-8859-1'?><cidade><nome>Jacareí</nome>"
    '<uf>SP</uf><atualizacao>2026-11-09</atualizacao>'
    '<previsao><dia>2026-11-10</dia><tempo>pn</tempo><maxima>19</maxima>'
    '<minima>14</minima><iuv>0.0</iuv></previsao>'
    '<previsao><dia>2026-11-11</dia><tempo>pn</tempo><maxima>23</maxima>'
    '<minima>15</minima><iuv>0.0</iuv></previsao>'
    '<previsao><dia>2026-11-12</dia><tempo>c</tempo><maxima>24</maxima>'
    '<minima>14</minima><iuv>0.0</iuv></previsao>'
    '<previsao><dia>2026-11-13</dia><tempo>ci</tempo><maxima>26</maxima>'
    '<minima>17</minima><iuv>7.5</iuv></previsao></cidade>';

/// Resposta do CPTEC para um código inexistente: todos os campos "null".
const String xmlPrevisaoNula =
    "<?xml version='1.0' encoding='ISO-8859-1'?><cidade><nome>null</nome>"
    '<uf>null</uf><atualizacao>null</atualizacao>'
    '<previsao><dia>null</dia><tempo>null</tempo><maxima>null</maxima>'
    '<minima>null</minima><iuv>0.0</iuv></previsao>'
    '<previsao><dia>null</dia><tempo>null</tempo><maxima>null</maxima>'
    '<minima>null</minima><iuv>0.0</iuv></previsao></cidade>';

/// Resposta com campos ausentes / inválidos.
const String xmlPrevisaoIncompleta =
    "<?xml version='1.0' encoding='ISO-8859-1'?><cidade><nome>Teste</nome>"
    '<previsao><dia>2026-11-10</dia><maxima>abc</maxima></previsao>'
    '<previsao><tempo>xx</tempo><minima>10</minima></previsao>'
    '<previsao></previsao></cidade>';

/// Resposta HTTP no mesmo formato do servidor (ISO-8859-1).
http.Response respostaLatin1(String xml, [int status = 200]) =>
    http.Response.bytes(
      latin1.encode(xml),
      status,
      headers: {'content-type': 'text/xml;charset=ISO-8859-1'},
    );

/// Cliente HTTP simulado que responde conforme o caminho da URL.
MockClient clienteSimulado({
  String cidades = xmlCidadesJacarei,
  String previsao = xmlPrevisaoJacarei,
  List<Uri>? chamadas,
}) {
  return MockClient((request) async {
    chamadas?.add(request.url);
    if (request.url.path.endsWith('/listaCidades')) {
      return respostaLatin1(cidades);
    }
    if (request.url.path.endsWith('/previsao.xml')) {
      return respostaLatin1(previsao);
    }
    return http.Response('not found', 404);
  });
}
