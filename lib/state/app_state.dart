import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment_summary.dart';
import '../models/patient.dart';
import '../services/api_service.dart';

// APRESENTAÇÃO: reúne sessão, pacientes e atendimentos para atualizar a interface.
// As preferências locais guardam só o último e-mail e paciente, não dados clínicos.
class AppState extends ChangeNotifier {
  AppState({required ApiService api, SharedPreferencesAsync? preferences})
      : _api = api,
        _preferences = preferences ?? SharedPreferencesAsync();

  final ApiService _api;
  final SharedPreferencesAsync _preferences;
  final List<Patient> _patients = [];
  final List<AppointmentSummary> _appointments = [];

  String? lastLogin;
  String? lastPatientId;
  bool isAuthenticated = false;
  bool isInitializing = true;
  bool isLoadingPatients = false;
  String? patientsError;
  String? appointmentsError;

  List<Patient> get patients => List.unmodifiable(_patients);
  List<AppointmentSummary> get appointments => List.unmodifiable(_appointments);
  String get professionalName {
    final emailName = (lastLogin ?? '').split('@').first.trim();
    final firstPart = emailName
        .split(RegExp(r'[._+\-]'))
        .firstWhere((part) => part.isNotEmpty, orElse: () => '');
    if (firstPart.isEmpty) return 'profissional';
    return '${firstPart[0].toUpperCase()}${firstPart.substring(1).toLowerCase()}';
  }

  Future<void> initialize() async {
    // APRESENTAÇÃO: ao abrir, recupera preferências e tenta restaurar a sessão.
    try {
      lastLogin = await _preferences.getString('last_login');
      lastPatientId = await _preferences.getString('last_patient_id');
    } catch (_) {
      // A interface continua disponível se a preferência local não responder.
    }
    try {
      isAuthenticated = await _api.restoreSession();
    } catch (_) {
      isAuthenticated = false;
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    await _api.login(email, password);
    lastLogin = email.trim();
    isAuthenticated = true;
    notifyListeners();
    try {
      await _preferences.setString('last_login', lastLogin!);
    } catch (_) {}
  }

  Future<void> register(String email, String password) async {
    await _api.register(email, password);
    lastLogin = email.trim();
    isAuthenticated = true;
    notifyListeners();
    try {
      await _preferences.setString('last_login', lastLogin!);
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } finally {
      _expireLocalSession();
    }
  }

  void _expireLocalSession() {
    isAuthenticated = false;
    _patients.clear();
    _appointments.clear();
    notifyListeners();
  }

  void _handleAuthError(Object error) {
    if (error is AuthException) _expireLocalSession();
  }

  Future<void> selectPatient(Patient patient) async {
    lastPatientId = patient.id;
    notifyListeners();
    try {
      await _preferences.setString('last_patient_id', patient.id);
    } catch (_) {}
  }

  Future<void> loadPatients() async {
    // APRESENTAÇÃO: a Home pede as listas à API e mostra carregamento ou erro.
    if (isLoadingPatients) return;
    isLoadingPatients = true;
    patientsError = null;
    appointmentsError = null;
    notifyListeners();
    try {
      final result = await _api.fetchPatients();
      _patients
        ..clear()
        ..addAll(result);
    } catch (error) {
      patientsError = error.toString();
      _handleAuthError(error);
      if (!isAuthenticated) {
        isLoadingPatients = false;
        notifyListeners();
        return;
      }
    }
    try {
      final result = await _api.fetchAppointments();
      _appointments
        ..clear()
        ..addAll(result);
    } catch (error) {
      appointmentsError = error.toString();
      _handleAuthError(error);
    }
    isLoadingPatients = false;
    notifyListeners();
  }

  Future<Patient> fetchPatient(String id) async {
    try {
      return await _api.fetchPatient(id);
    } catch (error) {
      _handleAuthError(error);
      rethrow;
    }
  }

  Future<void> addPatient({
    required String name,
    required String birthDate,
    required String phone,
    required String condition,
  }) async {
    late Patient patient;
    try {
      patient = await _api.addPatient(
        name: name,
        birthDate: birthDate,
        phone: phone,
        condition: condition,
      );
    } catch (error) {
      _handleAuthError(error);
      rethrow;
    }
    _patients.insert(0, patient);
    notifyListeners();
    await selectPatient(patient);
  }

  Future<Patient> updatePatient({
    required Patient patient,
    required String name,
    required String birthDate,
    required String phone,
    required String condition,
  }) async {
    // APRESENTAÇÃO: após salvar, atualiza a lista e os nomes nos atendimentos.
    late Patient updated;
    try {
      updated = await _api.updatePatient(
        id: patient.id,
        name: name,
        birthDate: birthDate,
        phone: phone,
        condition: condition,
      );
    } catch (error) {
      _handleAuthError(error);
      rethrow;
    }
    final index = _patients.indexWhere((item) => item.id == patient.id);
    if (index >= 0) _patients[index] = updated;
    notifyListeners();
    await _refreshAppointments();
    return updated;
  }

  Future<String> submitAppointment({
    required Patient patient,
    required DateTime startsAt,
    required String notes,
  }) async {
    late String id;
    try {
      id = await _api.postAppointment(
        patient: patient,
        startsAt: startsAt,
        notes: notes,
      );
    } catch (error) {
      _handleAuthError(error);
      rethrow;
    }
    await selectPatient(patient);
    try {
      final result = await _api.fetchAppointments();
      _appointments
        ..clear()
        ..addAll(result);
      notifyListeners();
    } catch (error) {
      appointmentsError = error.toString();
      _handleAuthError(error);
      notifyListeners();
    }
    return id;
  }

  Future<void> updateAppointment({
    required AppointmentSummary appointment,
    required DateTime startsAt,
    required String status,
    required String notes,
  }) async {
    // APRESENTAÇÃO: mantém o paciente vinculado e atualiza data, situação e notas.
    try {
      await _api.updateAppointment(
        id: appointment.id,
        startsAt: startsAt,
        status: status,
        notes: notes,
      );
    } catch (error) {
      _handleAuthError(error);
      rethrow;
    }
    final index = _appointments.indexWhere((item) => item.id == appointment.id);
    if (index >= 0) {
      _appointments[index] = AppointmentSummary(
        id: appointment.id,
        patientId: appointment.patientId,
        startsAt: startsAt,
        patientName: appointment.patientName,
        status: status,
        notes: notes,
      );
      notifyListeners();
    }
    await _refreshAppointments();
  }

  Future<void> _refreshAppointments() async {
    try {
      final result = await _api.fetchAppointments();
      _appointments
        ..clear()
        ..addAll(result);
      appointmentsError = null;
    } catch (error) {
      appointmentsError = error.toString();
      _handleAuthError(error);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
