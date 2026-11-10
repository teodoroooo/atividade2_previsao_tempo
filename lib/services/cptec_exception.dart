/// Tipos de falha tratados pelo aplicativo.
enum TipoFalha {
  /// Sem internet / não foi possível conectar ao servidor.
  semConexao,

  /// O servidor demorou demais para responder.
  tempoEsgotado,

  /// O servidor respondeu com erro (HTTP diferente de 200).
  servicoIndisponivel,

  /// O servidor respondeu, mas o conteúdo não é um XML válido/esperado.
  respostaInvalida,
}

/// Erro de comunicação com o serviço do CPTEC/INPE, já com uma mensagem
/// adequada para mostrar ao usuário.
class CptecException implements Exception {
  const CptecException(this.tipo, [this.detalhe]);

  final TipoFalha tipo;

  /// Informação técnica (status HTTP, mensagem do parser...).
  final String? detalhe;

  String get mensagem {
    switch (tipo) {
      case TipoFalha.semConexao:
        return 'Falha de conexão. Verifique sua internet e tente novamente.';
      case TipoFalha.tempoEsgotado:
        return 'O serviço do CPTEC/INPE demorou para responder. '
            'Tente novamente.';
      case TipoFalha.servicoIndisponivel:
        return 'O serviço do CPTEC/INPE está indisponível no momento. '
            'Tente novamente mais tarde.';
      case TipoFalha.respostaInvalida:
        return 'O serviço do CPTEC/INPE retornou uma resposta inválida.';
    }
  }

  @override
  String toString() =>
      'CptecException($tipo${detalhe == null ? '' : ': $detalhe'})';
}
