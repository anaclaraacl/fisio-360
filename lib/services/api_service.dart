import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/appointment_summary.dart';
import '../models/patient.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthException extends ApiException {
  const AuthException() : super('Sessão expirada. Entre novamente.');
}

// APRESENTAÇÃO: concentra as chamadas HTTPS; as telas não acessam o banco diretamente.
class ApiService {
  ApiService._(this._client, this._storage);
  final http.Client _client;
  final FlutterSecureStorage _storage;
  String? _accessToken;
  static const _baseUrl = String.fromEnvironment(
    'FISIO_API_BASE_URL',
    defaultValue: 'https://10.0.2.2:8443',
  );
  static const _timeout = Duration(seconds: 12);
  static const _refreshKey = 'fisio_refresh_token';

  static Future<ApiService> create() async {
    // APRESENTAÇÃO: o app confia no certificado local incluído no projeto.
    // Erros de certificado não são ignorados para liberar a conexão.
    final cert = await rootBundle.load('assets/certs/local-api.pem');
    final security = SecurityContext(withTrustedRoots: false);
    security.setTrustedCertificatesBytes(Uint8List.sublistView(cert));
    final httpClient = HttpClient(context: security);
    return ApiService._(IOClient(httpClient), const FlutterSecureStorage());
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<bool> restoreSession() async {
    try {
      await _refresh();
      return true;
    } on AuthException {
      return false;
    } on ApiException {
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    final response = await _post('/v1/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    final data = _json(response);
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw ApiException(_message(response, 'Falha no login.'));
    }
    await _saveTokens(data);
  }

  Future<void> register(String email, String password) async {
    final response = await _post('/v1/auth/register', {
      'email': email.trim(),
      'password': password,
    });
    final data = _json(response);
    if (response.statusCode != 201 || data is! Map<String, dynamic>) {
      throw ApiException(_message(response, 'Não foi possível criar a conta.'));
    }
    await _saveTokens(data);
  }

  Future<void> logout() async {
    final refresh = await _storage.read(key: _refreshKey);
    try {
      if (refresh != null) {
        await _post('/v1/auth/logout', {'refreshToken': refresh});
      }
    } catch (_) {
      // A sessão local é encerrada mesmo se o servidor estiver indisponível.
    } finally {
      _accessToken = null;
      await _storage.delete(key: _refreshKey);
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    // APRESENTAÇÃO: o token de renovação fica no armazenamento seguro do Android.
    final access = data['accessToken'];
    final refresh = data['refreshToken'];
    if (access is! String || refresh is! String) {
      throw const ApiException('Resposta de autenticação inválida.');
    }
    await _storage.write(key: _refreshKey, value: refresh);
    _accessToken = access;
  }

  Future<void> _refresh() async {
    // APRESENTAÇÃO: renova a sessão sem pedir a senha a cada abertura do app.
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null) throw const AuthException();
    final response = await _post('/v1/auth/refresh', {'refreshToken': refresh});
    if (response.statusCode == 401) {
      await _storage.delete(key: _refreshKey);
      _accessToken = null;
      throw const AuthException();
    }
    final data = _json(response);
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw ApiException(
          _message(response, 'Não foi possível renovar a sessão.'));
    }
    await _saveTokens(data);
  }

  Future<http.Response> _authorized(
    Future<http.Response> Function(String token) operation,
  ) async {
    // APRESENTAÇÃO: toda leitura ou alteração protegida envia um token válido.
    if (_accessToken == null) await _refresh();
    var response = await operation(_accessToken!);
    if (response.statusCode == 401) {
      await _refresh();
      response = await operation(_accessToken!);
    }
    if (response.statusCode == 401) throw const AuthException();
    return response;
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body,
          {String? token}) =>
      _call(() => _client.post(
            _uri(path),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          ));

  Future<http.Response> _patch(
          String path, Map<String, dynamic> body, String token) =>
      _call(() => _client.patch(
            _uri(path),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          ));

  Future<http.Response> _get(String path, String token) => _call(() =>
      _client.get(_uri(path), headers: {'Authorization': 'Bearer $token'}));

  Future<http.Response> _call(Future<http.Response> Function() action) async {
    try {
      return await action().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
          'Tempo de conexão esgotado. Verifique se o servidor está aberto.');
    } on SocketException {
      throw const ApiException('Não foi possível conectar ao servidor local.');
    } on http.ClientException {
      throw const ApiException('Falha na conexão HTTPS com o servidor local.');
    } on HandshakeException {
      throw const ApiException(
          'Certificado HTTPS do servidor não é confiável.');
    }
  }

  dynamic _json(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('Resposta inválida do servidor.');
    }
  }

  String _message(http.Response response, String fallback) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic> && data['error'] is String) {
        return data['error'] as String;
      }
    } catch (_) {}
    return fallback;
  }

  Future<List<Patient>> fetchPatients() async {
    final response = await _authorized((token) => _get('/v1/patients', token));
    if (response.statusCode != 200) {
      throw ApiException(
          _message(response, 'Não foi possível carregar pacientes.'));
    }
    final data = _json(response);
    if (data is! List) throw const ApiException('Lista de pacientes inválida.');
    return data
        .map((item) => Patient.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<Patient> fetchPatient(String id) async {
    final response =
        await _authorized((token) => _get('/v1/patients/$id', token));
    if (response.statusCode != 200) {
      throw ApiException(
          _message(response, 'Não foi possível carregar o paciente.'));
    }
    return Patient.fromApi(_json(response) as Map<String, dynamic>);
  }

  Future<Patient> addPatient({
    required String name,
    required String birthDate,
    required String phone,
    required String condition,
  }) async {
    final response = await _authorized((token) => _post(
        '/v1/patients',
        {
          'name': name,
          'birthDate': birthDate,
          'phone': phone,
          'condition': condition,
        },
        token: token));
    if (response.statusCode != 201) {
      throw ApiException(
          _message(response, 'Não foi possível cadastrar o paciente.'));
    }
    return Patient.fromApi(_json(response) as Map<String, dynamic>);
  }

  Future<Patient> updatePatient({
    required String id,
    required String name,
    required String birthDate,
    required String phone,
    required String condition,
  }) async {
    final response = await _authorized((token) => _patch(
        '/v1/patients/$id',
        {
          'name': name,
          'birthDate': birthDate,
          'phone': phone,
          'condition': condition,
        },
        token));
    if (response.statusCode != 200) {
      throw ApiException(
          _message(response, 'Não foi possível atualizar o paciente.'));
    }
    return Patient.fromApi(_json(response) as Map<String, dynamic>);
  }

  Future<List<AppointmentSummary>> fetchAppointments() async {
    final response =
        await _authorized((token) => _get('/v1/appointments', token));
    if (response.statusCode != 200) {
      throw ApiException(
          _message(response, 'Não foi possível carregar atendimentos.'));
    }
    final data = _json(response);
    if (data is! List) {
      throw const ApiException('Lista de atendimentos inválida.');
    }
    return data
        .map((item) => AppointmentSummary.fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> postAppointment({
    required Patient patient,
    required DateTime startsAt,
    required String notes,
  }) async {
    final response = await _authorized((token) => _post(
        '/v1/appointments',
        {
          'patientId': patient.id,
          'startsAt': startsAt.toUtc().toIso8601String(),
          'notes': notes,
        },
        token: token));
    if (response.statusCode != 201) {
      throw ApiException(
          _message(response, 'Não foi possível salvar o atendimento.'));
    }
    final data = _json(response) as Map<String, dynamic>;
    return data['id'] as String;
  }

  Future<void> updateAppointment({
    required String id,
    required DateTime startsAt,
    required String status,
    required String notes,
  }) async {
    final response = await _authorized((token) => _patch(
        '/v1/appointments/$id',
        {
          'startsAt': startsAt.toUtc().toIso8601String(),
          'status': status,
          'notes': notes,
        },
        token));
    if (response.statusCode != 200) {
      throw ApiException(
          _message(response, 'Não foi possível atualizar o atendimento.'));
    }
  }

  void dispose() => _client.close();
}
