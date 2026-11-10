import 'package:flutter/material.dart';

import '../data/armazenamento_local.dart';
import '../models/cidade.dart';
import '../services/cptec_exception.dart';
import '../services/cptec_service.dart';
import '../widgets/comuns.dart';
import 'previsao_screen.dart';

/// Tela inicial: pesquisa de cidades no CPTEC/INPE e lista das cidades
/// consultadas recentemente (salvas no dispositivo).
class BuscaCidadesScreen extends StatefulWidget {
  const BuscaCidadesScreen({
    super.key,
    required this.service,
    required this.armazenamento,
  });

  final CptecService service;
  final ArmazenamentoLocal armazenamento;

  @override
  State<BuscaCidadesScreen> createState() => _BuscaCidadesScreenState();
}

class _BuscaCidadesScreenState extends State<BuscaCidadesScreen> {
  final _controller = TextEditingController();

  bool _carregando = false;
  String? _erro;
  String? _termoPesquisado;
  List<Cidade>? _resultados;
  List<Cidade> _recentes = [];

  /// Evita que uma resposta antiga sobrescreva uma pesquisa mais nova.
  int _pesquisaAtual = 0;

  @override
  void initState() {
    super.initState();
    _recentes = widget.armazenamento.cidadesRecentes();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pesquisar() async {
    final termo = _controller.text.trim();
    FocusScope.of(context).unfocus();
    if (termo.isEmpty) {
      setState(() {
        _resultados = null;
        _erro = 'Informe o nome de uma cidade.';
      });
      return;
    }

    final id = ++_pesquisaAtual;
    setState(() {
      _carregando = true;
      _erro = null;
      _resultados = null;
      _termoPesquisado = termo;
    });

    try {
      final cidades = await widget.service.buscarCidades(termo);
      if (!mounted || id != _pesquisaAtual) return;
      setState(() => _resultados = cidades);
    } on CptecException catch (e) {
      if (!mounted || id != _pesquisaAtual) return;
      setState(() => _erro = e.mensagem);
    } catch (_) {
      if (!mounted || id != _pesquisaAtual) return;
      setState(() => _erro = 'Erro inesperado ao pesquisar a cidade.');
    } finally {
      if (mounted && id == _pesquisaAtual) {
        setState(() => _carregando = false);
      }
    }
  }

  void _limparPesquisa() {
    _pesquisaAtual++;
    _controller.clear();
    setState(() {
      _carregando = false;
      _erro = null;
      _resultados = null;
      _termoPesquisado = null;
    });
  }

  Future<void> _abrirPrevisao(Cidade cidade) async {
    await widget.armazenamento.registrarCidade(cidade);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrevisaoScreen(
          cidade: cidade,
          service: widget.service,
          armazenamento: widget.armazenamento,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _recentes = widget.armazenamento.cidadesRecentes());
  }

  Future<void> _removerRecente(Cidade cidade) async {
    await widget.armazenamento.removerCidade(cidade);
    setState(() => _recentes = widget.armazenamento.cidadesRecentes());
  }

  Future<void> _limparRecentes() async {
    await widget.armazenamento.limparTudo();
    setState(() => _recentes = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Previsão do Tempo')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const Key('campoBusca'),
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _pesquisar(),
                decoration: InputDecoration(
                  labelText: 'Nome da cidade',
                  hintText: 'Ex.: Jacareí',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_city),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_termoPesquisado != null)
                        IconButton(
                          tooltip: 'Limpar pesquisa',
                          icon: const Icon(Icons.clear),
                          onPressed: _limparPesquisa,
                        ),
                      IconButton(
                        key: const Key('botaoPesquisar'),
                        tooltip: 'Pesquisar',
                        icon: const Icon(Icons.search),
                        onPressed: _carregando ? null : _pesquisar,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: _conteudo()),
            const FonteDados(),
          ],
        ),
      ),
    );
  }

  Widget _conteudo() {
    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Pesquisando cidades...'),
          ],
        ),
      );
    }
    if (_erro != null) {
      return MensagemEstado(
        icone: Icons.cloud_off,
        mensagem: _erro!,
        textoAcao: _termoPesquisado == null ? null : 'Tentar novamente',
        onAcao: _termoPesquisado == null ? null : _pesquisar,
      );
    }
    final resultados = _resultados;
    if (resultados != null) {
      if (resultados.isEmpty) {
        return MensagemEstado(
          icone: Icons.search_off,
          mensagem: 'Nenhuma cidade encontrada para "$_termoPesquisado".',
        );
      }
      return _listaResultados(resultados);
    }
    return _listaRecentes();
  }

  Widget _listaResultados(List<Cidade> cidades) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            '${cidades.length} ${cidades.length == 1 ? 'localidade encontrada' : 'localidades encontradas'}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: cidades.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final cidade = cidades[i];
              return ListTile(
                leading: CircleAvatar(child: Text(cidade.uf)),
                title: Text(cidade.nome),
                subtitle: Text('UF: ${cidade.uf} • Código CPTEC: ${cidade.id}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _abrirPrevisao(cidade),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _listaRecentes() {
    if (_recentes.isEmpty) {
      return const MensagemEstado(
        icone: Icons.travel_explore,
        mensagem:
            'Pesquise uma cidade para ver a previsão do tempo '
            'dos próximos 4 dias.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Consultas recentes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: _limparRecentes,
                child: const Text('Limpar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentes.length,
            itemBuilder: (_, i) {
              final cidade = _recentes[i];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(cidade.nomeComUf),
                trailing: IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.close),
                  onPressed: () => _removerRecente(cidade),
                ),
                onTap: () => _abrirPrevisao(cidade),
              );
            },
          ),
        ),
      ],
    );
  }
}
