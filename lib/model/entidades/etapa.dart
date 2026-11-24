class Etapa {
  final String idEtapa;
  final String idVersao;
  final int ordem;
  final String instrucao;

  const Etapa({
    required this.idEtapa,
    required this.idVersao,
    required this.ordem,
    required this.instrucao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_etapa': idEtapa,
      'id_versao': idVersao,
      'ordem': ordem,
      'instrucao': instrucao,
    };
  }

  factory Etapa.fromMap(Map<String, dynamic> map) {
    return Etapa(
      idEtapa: map['id_etapa'] as String,
      idVersao: map['id_versao'] as String,
      ordem: map['ordem'] as int,
      instrucao: map['instrucao'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Etapa &&
          runtimeType == other.runtimeType &&
          idEtapa == other.idEtapa &&
          idVersao == other.idVersao &&
          ordem == other.ordem &&
          instrucao == other.instrucao;

  @override
  int get hashCode =>
      idEtapa.hashCode ^
      idVersao.hashCode ^
      ordem.hashCode ^
      instrucao.hashCode;
}
