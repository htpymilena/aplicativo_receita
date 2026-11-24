class Conferencia {
  final String idPreparo;
  final String idItem;
  final String estado; // 'nao_conferido' | 'tenho' | 'falta'

  const Conferencia({
    required this.idPreparo,
    required this.idItem,
    this.estado = 'nao_conferido',
  });

  Map<String, dynamic> toMap() {
    return {
      'id_preparo': idPreparo,
      'id_item': idItem,
      'estado': estado,
    };
  }

  factory Conferencia.fromMap(Map<String, dynamic> map) {
    return Conferencia(
      idPreparo: map['id_preparo'] as String,
      idItem: map['id_item'] as String,
      estado: (map['estado'] as String?) ?? 'nao_conferido',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conferencia &&
          runtimeType == other.runtimeType &&
          idPreparo == other.idPreparo &&
          idItem == other.idItem &&
          estado == other.estado;

  @override
  int get hashCode =>
      idPreparo.hashCode ^
      idItem.hashCode ^
      estado.hashCode;
}
