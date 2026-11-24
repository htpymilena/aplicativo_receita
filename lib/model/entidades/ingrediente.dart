class Ingrediente {
  final String idIngrediente;
  final String nome;
  final String nomeNormalizado;

  const Ingrediente({
    required this.idIngrediente,
    required this.nome,
    required this.nomeNormalizado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_ingrediente': idIngrediente,
      'nome': nome,
      'nome_normalizado': nomeNormalizado,
    };
  }

  factory Ingrediente.fromMap(Map<String, dynamic> map) {
    return Ingrediente(
      idIngrediente: map['id_ingrediente'] as String,
      nome: map['nome'] as String,
      nomeNormalizado: map['nome_normalizado'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ingrediente &&
          runtimeType == other.runtimeType &&
          idIngrediente == other.idIngrediente &&
          nome == other.nome &&
          nomeNormalizado == other.nomeNormalizado;

  @override
  int get hashCode =>
      idIngrediente.hashCode ^
      nome.hashCode ^
      nomeNormalizado.hashCode;
}
