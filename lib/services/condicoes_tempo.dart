import 'package:flutter/material.dart';

/// Conversão das siglas de condição do tempo do CPTEC/INPE em descrições
/// e ícones.
///
/// Tabela oficial: https://servicos.cptec.inpe.br/XML/#condicoes-tempo
class CondicoesTempo {
  CondicoesTempo._();

  static const String descricaoDesconhecida = 'Condição não informada';

  /// Siglas e descrições conforme a documentação do CPTEC/INPE.
  static const Map<String, String> descricoes = {
    'ec': 'Encoberto com Chuvas Isoladas',
    'ci': 'Chuvas Isoladas',
    'c': 'Chuva',
    'in': 'Instável',
    'pp': 'Poss. de Pancadas de Chuva',
    'cm': 'Chuva pela Manhã',
    'cn': 'Chuva a Noite',
    'pt': 'Pancadas de Chuva a Tarde',
    'pm': 'Pancadas de Chuva pela Manhã',
    'np': 'Nublado e Pancadas de Chuva',
    'pc': 'Pancadas de Chuva',
    'pn': 'Parcialmente Nublado',
    'cv': 'Chuvisco',
    'ch': 'Chuvoso',
    't': 'Tempestade',
    'ps': 'Predomínio de Sol',
    'e': 'Encoberto',
    'n': 'Nublado',
    'cl': 'Céu Claro',
    'nv': 'Nevoeiro',
    'g': 'Geada',
    'ne': 'Neve',
    'nd': 'Não Definido',
    'pnt': 'Pancadas de Chuva a Noite',
    'psc': 'Possibilidade de Chuva',
    'pcm': 'Possibilidade de Chuva pela Manhã',
    'pct': 'Possibilidade de Chuva a Tarde',
    'pcn': 'Possibilidade de Chuva a Noite',
    'npt': 'Nublado com Pancadas a Tarde',
    'npn': 'Nublado com Pancadas a Noite',
    'ncn': 'Nublado com Poss. de Chuva a Noite',
    'nct': 'Nublado com Poss. de Chuva a Tarde',
    'ncm': 'Nubl. c/ Poss. de Chuva pela Manhã',
    'npm': 'Nublado com Pancadas pela Manhã',
    'npp': 'Nublado com Possibilidade de Chuva',
    'vn': 'Variação de Nebulosidade',
    'ct': 'Chuva a Tarde',
    'ppn': 'Poss. de Panc. de Chuva a Noite',
    'ppt': 'Poss. de Panc. de Chuva a Tarde',
    'ppm': 'Poss. de Panc. de Chuva pela Manhã',
  };

  static String? _normalizar(String? sigla) => sigla?.trim().toLowerCase();

  /// Descrição da sigla; se a sigla for desconhecida ou ausente, devolve
  /// um texto padrão em vez de lançar erro.
  static String descricao(String? sigla) {
    final s = _normalizar(sigla);
    if (s == null || s.isEmpty) return descricaoDesconhecida;
    return descricoes[s] ?? '$descricaoDesconhecida ($s)';
  }

  /// Ícone representativo da condição do tempo.
  static IconData icone(String? sigla) {
    switch (_normalizar(sigla)) {
      case 'cl':
        return Icons.wb_sunny;
      case 'ps':
        return Icons.wb_sunny_outlined;
      case 'pn':
      case 'vn':
        return Icons.filter_drama;
      case 'n':
      case 'e':
        return Icons.cloud;
      case 't':
        return Icons.thunderstorm;
      case 'in':
        return Icons.bolt;
      case 'cv':
        return Icons.grain;
      case 'nv':
        return Icons.foggy;
      case 'g':
      case 'ne':
        return Icons.ac_unit;
      case 'c':
      case 'ch':
      case 'cm':
      case 'cn':
      case 'ct':
        return Icons.umbrella;
      case 'ec':
      case 'ci':
      case 'pp':
      case 'pt':
      case 'pm':
      case 'np':
      case 'pc':
      case 'pnt':
      case 'psc':
      case 'pcm':
      case 'pct':
      case 'pcn':
      case 'npt':
      case 'npn':
      case 'ncn':
      case 'nct':
      case 'ncm':
      case 'npm':
      case 'npp':
      case 'ppn':
      case 'ppt':
      case 'ppm':
        return Icons.water_drop;
      default:
        return Icons.help_outline;
    }
  }

  /// Cor de destaque do ícone.
  static Color cor(String? sigla) {
    final icone = CondicoesTempo.icone(sigla);
    if (icone == Icons.wb_sunny || icone == Icons.wb_sunny_outlined) {
      return Colors.orange;
    }
    if (icone == Icons.thunderstorm || icone == Icons.bolt) {
      return Colors.deepPurple;
    }
    if (icone == Icons.umbrella ||
        icone == Icons.water_drop ||
        icone == Icons.grain) {
      return Colors.blue;
    }
    if (icone == Icons.ac_unit) return Colors.lightBlue;
    if (icone == Icons.help_outline) return Colors.grey;
    return Colors.blueGrey;
  }
}
