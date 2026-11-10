/// Localidade retornada pelo serviço de busca de cidades do CPTEC/INPE.
class Cidade {
  const Cidade({required this.id, required this.nome, required this.uf});

  /// Código da localidade informado pelo próprio CPTEC (usado na previsão).
  final int id;
  final String nome;
  final String uf;

  /// Texto exibido nas listas: "Nome - UF".
  String get nomeComUf => uf.isEmpty ? nome : '$nome - $uf';

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome, 'uf': uf};

  /// Retorna `null` quando o JSON salvo estiver incompleto.
  static Cidade? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nome = json['nome'];
    if (id is! int || nome is! String) return null;
    final uf = json['uf'];
    return Cidade(id: id, nome: nome, uf: uf is String ? uf : '');
  }

  @override
  bool operator ==(Object other) =>
      other is Cidade && other.id == id && other.nome == nome && other.uf == uf;

  @override
  int get hashCode => Object.hash(id, nome, uf);

  @override
  String toString() => 'Cidade($id, $nomeComUf)';
}
