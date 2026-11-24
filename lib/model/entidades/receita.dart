class Receita {
  final String idReceita;
  final String? idAutor;
  final String origem; // 'usuario' | 'themealdb'
  final String? idThemealdb;
  final String visibilidade; // 'privada' | 'publica'
  final String estadoModeracao; // 'liberada' | 'oculta' | 'pendente'
  final DateTime? excluidaEm;

  const Receita({
    required this.idReceita,
    this.idAutor,
    required this.origem,
    this.idThemealdb,
    this.visibilidade = 'privada',
    this.estadoModeracao = 'liberada',
    this.excluidaEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_receita': idReceita,
      'id_autor': idAutor,
      'origem': origem,
      'id_themealdb': idThemealdb,
      'visibilidade': visibilidade,
      'estado_moderacao': estadoModeracao,
      'excluida_em': excluidaEm?.toUtc().toIso8601String(),
    };
  }

  factory Receita.fromMap(Map<String, dynamic> map) {
    return Receita(
      idReceita: map['id_receita'] as String,
      idAutor: map['id_autor'] as String?,
      origem: map['origem'] as String,
      idThemealdb: map['id_themealdb'] as String?,
      visibilidade: (map['visibilidade'] as String?) ?? 'privada',
      estadoModeracao: (map['estado_moderacao'] as String?) ?? 'liberada',
      excluidaEm: map['excluida_em'] != null
          ? DateTime.parse(map['excluida_em'] as String).toUtc()
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Receita &&
          runtimeType == other.runtimeType &&
          idReceita == other.idReceita &&
          idAutor == other.idAutor &&
          origem == other.origem &&
          idThemealdb == other.idThemealdb &&
          visibilidade == other.visibilidade &&
          estadoModeracao == other.estadoModeracao &&
          excluidaEm == other.excluidaEm;

  @override
  int get hashCode =>
      idReceita.hashCode ^
      idAutor.hashCode ^
      origem.hashCode ^
      idThemealdb.hashCode ^
      visibilidade.hashCode ^
      estadoModeracao.hashCode ^
      excluidaEm.hashCode;
}
