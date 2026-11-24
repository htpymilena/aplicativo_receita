class ItemReceita {
  final String idItem;
  final String idVersao;
  final String idIngrediente;
  final int ordem;
  final String medida;

  const ItemReceita({
    required this.idItem,
    required this.idVersao,
    required this.idIngrediente,
    required this.ordem,
    required this.medida,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_item': idItem,
      'id_versao': idVersao,
      'id_ingrediente': idIngrediente,
      'ordem': ordem,
      'medida': medida,
    };
  }

  factory ItemReceita.fromMap(Map<String, dynamic> map) {
    return ItemReceita(
      idItem: map['id_item'] as String,
      idVersao: map['id_versao'] as String,
      idIngrediente: map['id_ingrediente'] as String,
      ordem: map['ordem'] as int,
      medida: map['medida'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemReceita &&
          runtimeType == other.runtimeType &&
          idItem == other.idItem &&
          idVersao == other.idVersao &&
          idIngrediente == other.idIngrediente &&
          ordem == other.ordem &&
          medida == other.medida;

  @override
  int get hashCode =>
      idItem.hashCode ^
      idVersao.hashCode ^
      idIngrediente.hashCode ^
      ordem.hashCode ^
      medida.hashCode;
}
