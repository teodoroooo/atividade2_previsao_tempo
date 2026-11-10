import 'package:flutter/material.dart';

/// Identificação do CPTEC/INPE como fonte dos dados.
class FonteDados extends StatelessWidget {
  const FonteDados({super.key});

  static const String texto = 'Fonte dos dados: CPTEC/INPE';

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 14, color: estilo?.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$texto (servicos.cptec.inpe.br)',
              style: estilo,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mensagem centralizada com ícone e, opcionalmente, botão de ação.
/// Usada para erros, listas vazias e estados iniciais.
class MensagemEstado extends StatelessWidget {
  const MensagemEstado({
    super.key,
    required this.icone,
    required this.mensagem,
    this.textoAcao,
    this.onAcao,
  });

  final IconData icone;
  final String mensagem;
  final String? textoAcao;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56, color: cor),
            const SizedBox(height: 12),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (textoAcao != null && onAcao != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAcao,
                icon: const Icon(Icons.refresh),
                label: Text(textoAcao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
