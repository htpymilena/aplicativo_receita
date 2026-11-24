class Avaliacao {
  final String idPreparo;
  final int estrelas; // 1 a 5
  final String visibilidade; // 'privada' | 'publica'
  final String estadoModeracao; // 'liberada' | 'oculta' | 'pendente'
  final DateTime avaliadaEm;

  const Avaliacao({
    required this.idPreparo,
    required this.estrelas,
    this.visibilidade = 'privada',
    this.estadoModeracao = 'liberada',
    required this.avaliadaEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_preparo': idPreparo,
      'estrelas': estrelas,
      'visibilidade': visibilidade,
      'estado_moderacao': estadoModeracao,
      'avaliada_em': avaliadaEm.toUtc().toIso8601String(),
    };
  }

  factory Avaliacao.fromMap(Map<String, dynamic> map) {
    return Avaliacao(
      idPreparo: map['id_preparo'] as String,
      estrelas: map['estrelas'] as int,
      visibilidade: (map['visibilidade'] as String?) ?? 'privada',
      estadoModeracao: (map['estado_moderacao'] as String?) ?? 'liberada',
      avaliadaEm: DateTime.parse(map['avaliada_em'] as String).toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Avaliacao &&
          runtimeType == other.runtimeType &&
          idPreparo == other.idPreparo &&
          estrelas == other.estrelas &&
          visibilidade == other.visibilidade &&
          estadoModeracao == other.estadoModeracao &&
          avaliadaEm == other.avaliadaEm;

  @override
  int get hashCode =>
      idPreparo.hashCode ^
      estrelas.hashCode ^
      visibilidade.hashCode ^
      estadoModeracao.hashCode ^
      avaliadaEm.hashCode;
}
