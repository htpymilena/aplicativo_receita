class VersaoReceita {
  final String idVersao;
  final String idReceita;
  final int numeroVersao;
  final String titulo;
  final String categoria;
  final String? fotoLocal;
  final String? fotoRemota;

  const VersaoReceita({
    required this.idVersao,
    required this.idReceita,
    required this.numeroVersao,
    required this.titulo,
    required this.categoria,
    this.fotoLocal,
    this.fotoRemota,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_versao': idVersao,
      'id_receita': idReceita,
      'numero_versao': numeroVersao,
      'titulo': titulo,
      'categoria': categoria,
      'foto_local': fotoLocal,
      'foto_remota': fotoRemota,
    };
  }

  factory VersaoReceita.fromMap(Map<String, dynamic> map) {
    return VersaoReceita(
      idVersao: map['id_versao'] as String,
      idReceita: map['id_receita'] as String,
      numeroVersao: map['numero_versao'] as int,
      titulo: map['titulo'] as String,
      categoria: map['categoria'] as String,
      fotoLocal: map['foto_local'] as String?,
      fotoRemota: map['foto_remota'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VersaoReceita &&
          runtimeType == other.runtimeType &&
          idVersao == other.idVersao &&
          idReceita == other.idReceita &&
          numeroVersao == other.numeroVersao &&
          titulo == other.titulo &&
          categoria == other.categoria &&
          fotoLocal == other.fotoLocal &&
          fotoRemota == other.fotoRemota;

  @override
  int get hashCode =>
      idVersao.hashCode ^
      idReceita.hashCode ^
      numeroVersao.hashCode ^
      titulo.hashCode ^
      categoria.hashCode ^
      fotoLocal.hashCode ^
      fotoRemota.hashCode;
}
