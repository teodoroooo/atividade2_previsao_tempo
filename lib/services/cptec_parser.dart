import 'package:xml/xml.dart';

import '../models/cidade.dart';
import '../models/previsao.dart';
import 'cptec_exception.dart';

/// Interpreta os XMLs devolvidos pelo CPTEC/INPE.
///
/// Campos ausentes, vazios ou com o texto "null" viram `null`, sem lançar
/// erro. Só é lançada [CptecException] quando o documento em si não é um
/// XML válido ou não tem o elemento raiz esperado.
class CptecParser {
  const CptecParser();

  /// Lê a resposta de `listaCidades?city=...`.
  ///
  /// ```xml
  /// <cidades><cidade><nome>Jacareí</nome><uf>SP</uf><id>2680</id></cidade></cidades>
  /// ```
  List<Cidade> parseCidades(String xml) {
    final raiz = _raiz(xml, 'cidades');
    final cidades = <Cidade>[];
    for (final el in raiz.findElements('cidade')) {
      final id = int.tryParse(_texto(el, 'id') ?? '');
      final nome = _texto(el, 'nome');
      // Sem código não é possível consultar a previsão: ignora o item.
      if (id == null || nome == null) continue;
      cidades.add(Cidade(id: id, nome: nome, uf: _texto(el, 'uf') ?? ''));
    }
    return cidades;
  }

  /// Lê a resposta de `cidade/{codigo}/previsao.xml` (4 dias).
  PrevisaoCidade parsePrevisao(String xml) {
    final raiz = _raiz(xml, 'cidade');
    final dias = raiz
        .findElements('previsao')
        .map(
          (el) => PrevisaoDia(
            data: _data(_texto(el, 'dia')),
            sigla: _texto(el, 'tempo'),
            maxima: _numero(_texto(el, 'maxima')),
            minima: _numero(_texto(el, 'minima')),
            iuv: _numero(_texto(el, 'iuv')),
          ),
        )
        .where((d) => d.possuiDados)
        .toList();

    return PrevisaoCidade(
      nome: _texto(raiz, 'nome'),
      uf: _texto(raiz, 'uf'),
      atualizacao: _data(_texto(raiz, 'atualizacao')),
      dias: dias,
    );
  }

  XmlElement _raiz(String xml, String nomeEsperado) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xml);
    } on XmlException catch (e) {
      throw CptecException(TipoFalha.respostaInvalida, e.message);
    }
    final raiz = doc.rootElement;
    if (raiz.name.local != nomeEsperado) {
      throw CptecException(
        TipoFalha.respostaInvalida,
        'Elemento raiz <${raiz.name.local}>, esperado <$nomeEsperado>',
      );
    }
    return raiz;
  }

  /// Texto do primeiro filho [nome]; `null` se ausente, vazio ou "null".
  String? _texto(XmlElement pai, String nome) {
    final el = pai.getElement(nome);
    if (el == null) return null;
    final texto = el.innerText.trim();
    if (texto.isEmpty || texto.toLowerCase() == 'null') return null;
    return texto;
  }

  double? _numero(String? texto) =>
      texto == null ? null : double.tryParse(texto.replaceAll(',', '.'));

  /// Datas no formato aaaa-mm-dd.
  DateTime? _data(String? texto) {
    if (texto == null) return null;
    final partes = texto.split('-');
    if (partes.length != 3) return null;
    final ano = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final dia = int.tryParse(partes[2]);
    if (ano == null || mes == null || dia == null) return null;
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
    return DateTime(ano, mes, dia);
  }
}
