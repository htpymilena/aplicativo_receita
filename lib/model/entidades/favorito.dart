class Favorito {
  final String idUsuario;
  final String idReceita;
  final DateTime salvoEm;

  const Favorito({
    required this.idUsuario,
    required this.idReceita,
    required this.salvoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'id_receita': idReceita,
      'salvo_em': salvoEm.toUtc().toIso8601String(),
    };
  }

  factory Favorito.fromMap(Map<String, dynamic> map) {
    return Favorito(
      idUsuario: map['id_usuario'] as String,
      idReceita: map['id_receita'] as String,
      salvoEm: DateTime.parse(map['salvo_em'] as String).toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Favorito &&
          runtimeType == other.runtimeType &&
          idUsuario == other.idUsuario &&
          idReceita == other.idReceita &&
          salvoEm == other.salvoEm;

  @override
  int get hashCode =>
      idUsuario.hashCode ^
      idReceita.hashCode ^
      salvoEm.hashCode;
}
