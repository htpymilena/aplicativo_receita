class Preparo {
  final String idPreparo;
  final String idUsuario;
  final String idVersao;
  final DateTime iniciadoEm;
  final DateTime? concluidoEm;
  final int ordemEtapaAtual;

  const Preparo({
    required this.idPreparo,
    required this.idUsuario,
    required this.idVersao,
    required this.iniciadoEm,
    this.concluidoEm,
    this.ordemEtapaAtual = 1,
  });

  bool get emAndamento => concluidoEm == null;

  Map<String, dynamic> toMap() {
    return {
      'id_preparo': idPreparo,
      'id_usuario': idUsuario,
      'id_versao': idVersao,
      'iniciado_em': iniciadoEm.toUtc().toIso8601String(),
      'concluido_em': concluidoEm?.toUtc().toIso8601String(),
      'ordem_etapa_atual': ordemEtapaAtual,
    };
  }

  factory Preparo.fromMap(Map<String, dynamic> map) {
    return Preparo(
      idPreparo: map['id_preparo'] as String,
      idUsuario: map['id_usuario'] as String,
      idVersao: map['id_versao'] as String,
      iniciadoEm: DateTime.parse(map['iniciado_em'] as String).toUtc(),
      concluidoEm: map['concluido_em'] != null
          ? DateTime.parse(map['concluido_em'] as String).toUtc()
          : null,
      ordemEtapaAtual: (map['ordem_etapa_atual'] as int?) ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preparo &&
          runtimeType == other.runtimeType &&
          idPreparo == other.idPreparo &&
          idUsuario == other.idUsuario &&
          idVersao == other.idVersao &&
          iniciadoEm == other.iniciadoEm &&
          concluidoEm == other.concluidoEm &&
          ordemEtapaAtual == other.ordemEtapaAtual;

  @override
  int get hashCode =>
      idPreparo.hashCode ^
      idUsuario.hashCode ^
      idVersao.hashCode ^
      iniciadoEm.hashCode ^
      concluidoEm.hashCode ^
      ordemEtapaAtual.hashCode;
}
