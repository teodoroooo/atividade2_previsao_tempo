import 'package:flutter/material.dart';

import '../data/armazenamento_local.dart';
import '../models/cidade.dart';
import '../models/previsao.dart';
import '../services/condicoes_tempo.dart';
import '../services/cptec_exception.dart';
import '../services/cptec_service.dart';
import '../utils/formatacao.dart';
import '../widgets/comuns.dart';
import 'grafico_screen.dart';

/// Previsão para 4 dias da cidade selecionada.
///
/// Ao abrir, exibe imediatamente a última previsão salva (se houver) e
/// consulta o CPTEC/INPE. Se a consulta falhar, a previsão salva continua
/// visível com um aviso.
class PrevisaoScreen extends StatefulWidget {
  const PrevisaoScreen({
    super.key,
    required this.cidade,
    required this.service,
    required this.armazenamento,
  });

  final Cidade cidade;
  final CptecService service;
  final ArmazenamentoLocal armazenamento;

  @override
  State<PrevisaoScreen> createState() => _PrevisaoScreenState();
}

class _PrevisaoScreenState extends State<PrevisaoScreen> {
  PrevisaoCidade? _previsao;
  DateTime? _salvaEm;
  bool _exibindoSalva = false;
  bool _carregando = false;
  String? _erro;
  ScaffoldMessengerState? _mensageiro;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mensageiro = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    // Não deixa o aviso de erro desta tela aparecer nas outras.
    _mensageiro?.hideCurrentSnackBar();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final salva = widget.armazenamento.previsaoSalva(widget.cidade.id);
    if (salva != null) {
      _previsao = salva.previsao;
      _salvaEm = salva.salvaEm;
      _exibindoSalva = true;
    }
    _atualizar();
  }

  Future<void> _atualizar() async {
    if (_carregando) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final previsao = await widget.service.buscarPrevisao(widget.cidade.id);
      if (!previsao.vazia) {
        final agora = DateTime.now();
        await widget.armazenamento.salvarPrevisao(
          widget.cidade.id,
          previsao,
          agora: agora,
        );
        _salvaEm = agora;
      }
      if (!mounted) return;
      setState(() {
        _previsao = previsao;
        _exibindoSalva = false;
      });
    } on CptecException catch (e) {
      _falha(e.mensagem);
    } catch (_) {
      _falha('Erro inesperado ao consultar a previsão.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _falha(String mensagem) {
    if (!mounted) return;
    setState(() => _erro = mensagem);
    if (_previsao != null && !_previsao!.vazia) {
      _mensageiro!
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(mensagem)));
    }
  }

  void _abrirGrafico() {
    final previsao = _previsao;
    if (previsao == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GraficoScreen(cidade: widget.cidade, previsao: previsao),
      ),
    );
  }

  bool get _temDados => _previsao != null && !_previsao!.vazia;

  @override
  Widget build(BuildContext context) {
    final podeVerGrafico =
        _previsao != null && _previsao!.diasComTemperatura.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cidade.nomeComUf),
        actions: [
          IconButton(
            key: const Key('botaoGrafico'),
            tooltip: 'Gráfico de temperatura',
            icon: const Icon(Icons.show_chart),
            onPressed: podeVerGrafico ? _abrirGrafico : null,
          ),
          IconButton(
            key: const Key('botaoAtualizar'),
            tooltip: 'Atualizar previsão',
            icon: const Icon(Icons.refresh),
            onPressed: _carregando ? null : _atualizar,
          ),
        ],
        bottom: _carregando && _temDados
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _conteudo(podeVerGrafico)),
            const FonteDados(),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(bool podeVerGrafico) {
    if (!_temDados) {
      if (_carregando) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Consultando previsão...'),
            ],
          ),
        );
      }
      if (_erro != null) {
        return MensagemEstado(
          icone: Icons.cloud_off,
          mensagem: _erro!,
          textoAcao: 'Tentar novamente',
          onAcao: _atualizar,
        );
      }
      return MensagemEstado(
        icone: Icons.event_busy,
        mensagem:
            'Nenhuma previsão disponível para '
            '${widget.cidade.nomeComUf} no momento.',
        textoAcao: 'Atualizar',
        onAcao: _atualizar,
      );
    }

    final previsao = _previsao!;
    return RefreshIndicator(
      onRefresh: _atualizar,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_exibindoSalva && _salvaEm != null)
            _AvisoPrevisaoSalva(salvaEm: _salvaEm!, erro: _erro),
          _Cabecalho(previsao: previsao, cidade: widget.cidade),
          const SizedBox(height: 4),
          for (final dia in previsao.dias) _CartaoDia(dia: dia),
          const SizedBox(height: 8),
          if (podeVerGrafico)
            OutlinedButton.icon(
              onPressed: _abrirGrafico,
              icon: const Icon(Icons.show_chart),
              label: const Text('Ver gráfico de temperatura'),
            ),
        ],
      ),
    );
  }
}

class _AvisoPrevisaoSalva extends StatelessWidget {
  const _AvisoPrevisaoSalva({required this.salvaEm, this.erro});

  final DateTime salvaEm;
  final String? erro;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      color: cores.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.save, color: cores.onTertiaryContainer),
        title: Text(
          'Exibindo previsão salva no dispositivo em ${formatarDataHora(salvaEm)}.',
          style: TextStyle(color: cores.onTertiaryContainer),
        ),
        subtitle: erro == null
            ? null
            : Text(erro!, style: TextStyle(color: cores.onTertiaryContainer)),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.previsao, required this.cidade});

  final PrevisaoCidade previsao;
  final Cidade cidade;

  @override
  Widget build(BuildContext context) {
    final nome = previsao.nome ?? cidade.nome;
    final uf = previsao.uf ?? cidade.uf;
    final tema = Theme.of(context);
    return Card(
      color: tema.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$nome - $uf', style: tema.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Previsão para ${previsao.dias.length} '
              '${previsao.dias.length == 1 ? 'dia' : 'dias'}',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.update, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Atualização do CPTEC/INPE: '
                    '${formatarData(previsao.atualizacao)}',
                    style: tema.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoDia extends StatelessWidget {
  const _CartaoDia({required this.dia});

  final PrevisaoDia dia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              CondicoesTempo.icone(dia.sigla),
              size: 44,
              color: CondicoesTempo.cor(dia.sigla),
              semanticLabel: dia.descricao,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${diaDaSemana(dia.data)}${dia.data == null ? '' : ', '}'
                    '${formatarData(dia.data)}',
                    style: tema.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(dia.descricao, style: tema.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _Info(
                        icone: Icons.arrow_downward,
                        cor: Colors.blue,
                        texto: 'Mín. ${formatarTemperatura(dia.minima)}',
                      ),
                      _Info(
                        icone: Icons.arrow_upward,
                        cor: Colors.red,
                        texto: 'Máx. ${formatarTemperatura(dia.maxima)}',
                      ),
                      if (dia.iuvDisponivel)
                        _Info(
                          icone: Icons.wb_sunny_outlined,
                          cor: Colors.orange,
                          texto: formatarIuv(dia.iuv!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icone, required this.cor, required this.texto});

  final IconData icone;
  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 16, color: cor),
        const SizedBox(width: 2),
        Text(texto),
      ],
    );
  }
}
