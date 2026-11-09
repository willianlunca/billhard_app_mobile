import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NextcloudConfig {
  final String url;
  final String usuario;
  final String senha;
  final int? quadroId;
  final String? quadroNome;

  const NextcloudConfig({
    required this.url,
    required this.usuario,
    required this.senha,
    this.quadroId,
    this.quadroNome,
  });

  NextcloudConfig copyWith({int? quadroId, String? quadroNome}) {
    return NextcloudConfig(
      url: url,
      usuario: usuario,
      senha: senha,
      quadroId: quadroId ?? this.quadroId,
      quadroNome: quadroNome ?? this.quadroNome,
    );
  }
}

class NextcloudConfigService {
  static const _storage = FlutterSecureStorage();

  String get _prefixo {
    final usuario = Supabase.instance.client.auth.currentUser;
    if (usuario == null) {
      throw StateError('Usuário não autenticado no Billhard.');
    }
    return 'billhard_nextcloud_${usuario.id}';
  }

  Future<NextcloudConfig?> carregar() async {
    final p = _prefixo;

    final url = await _storage.read(key: '${p}_url');
    final usuario = await _storage.read(key: '${p}_usuario');
    final senha = await _storage.read(key: '${p}_senha');
    final quadroId = await _storage.read(key: '${p}_quadro_id');
    final quadroNome = await _storage.read(key: '${p}_quadro_nome');

    if (url == null ||
        url.isEmpty ||
        usuario == null ||
        usuario.isEmpty ||
        senha == null ||
        senha.isEmpty) {
      return null;
    }

    return NextcloudConfig(
      url: url,
      usuario: usuario,
      senha: senha,
      quadroId: int.tryParse(quadroId ?? ''),
      quadroNome: quadroNome,
    );
  }

  Future<void> salvar(NextcloudConfig config) async {
    final p = _prefixo;

    await _storage.write(key: '${p}_url', value: config.url.trim());
    await _storage.write(key: '${p}_usuario', value: config.usuario.trim());
    await _storage.write(key: '${p}_senha', value: config.senha);

    if (config.quadroId != null) {
      await _storage.write(
        key: '${p}_quadro_id',
        value: config.quadroId.toString(),
      );
    } else {
      await _storage.delete(key: '${p}_quadro_id');
    }

    if (config.quadroNome != null) {
      await _storage.write(key: '${p}_quadro_nome', value: config.quadroNome);
    } else {
      await _storage.delete(key: '${p}_quadro_nome');
    }
  }

  Future<void> excluir() async {
    final p = _prefixo;
    for (final campo in [
      'url',
      'usuario',
      'senha',
      'quadro_id',
      'quadro_nome',
    ]) {
      await _storage.delete(key: '${p}_$campo');
    }
  }
}
