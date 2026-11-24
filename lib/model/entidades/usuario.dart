class Usuario {
  final String idUsuario;
  final String nomeExibicao;
  final String? email;
  final String perfil; // 'usuario' | 'administrador'

  const Usuario({
    required this.idUsuario,
    required this.nomeExibicao,
    this.email,
    this.perfil = 'usuario',
  });

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nome_exibicao': nomeExibicao,
      'email': email,
      'perfil': perfil,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      idUsuario: map['id_usuario'] as String,
      nomeExibicao: map['nome_exibicao'] as String,
      email: map['email'] as String?,
      perfil: (map['perfil'] as String?) ?? 'usuario',
    );
  }

  Usuario copyWith({
    String? idUsuario,
    String? nomeExibicao,
    String? email,
    String? perfil,
  }) {
    return Usuario(
      idUsuario: idUsuario ?? this.idUsuario,
      nomeExibicao: nomeExibicao ?? this.nomeExibicao,
      email: email ?? this.email,
      perfil: perfil ?? this.perfil,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Usuario &&
          runtimeType == other.runtimeType &&
          idUsuario == other.idUsuario &&
          nomeExibicao == other.nomeExibicao &&
          email == other.email &&
          perfil == other.perfil;

  @override
  int get hashCode =>
      idUsuario.hashCode ^
      nomeExibicao.hashCode ^
      email.hashCode ^
      perfil.hashCode;
}
