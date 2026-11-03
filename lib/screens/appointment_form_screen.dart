// Tela de responsabilidade de Felipe Frade.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment_summary.dart';
import '../models/patient.dart';
import '../state/app_state.dart';

class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({this.appointment, super.key});

  final AppointmentSummary? appointment;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();
  Patient? _selectedPatient;
  String _status = 'scheduled';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // APRESENTAÇÃO: no modo edição, data, horário e notas vêm do atendimento.
    final appointment = widget.appointment;
    if (appointment != null) {
      final date = appointment.startsAt;
      _dateController.text =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      _timeController.text =
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      _notesController.text = appointment.notes;
      _status = appointment.status;
      return;
    }
    final state = context.read<AppState>();
    for (final patient in state.patients) {
      if (patient.id == state.lastPatientId) {
        _selectedPatient = patient;
        break;
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // APRESENTAÇÃO: converte o horário local para UTC antes de salvar na API.
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    String? postId;
    try {
      final dateParts =
          _dateController.text.trim().split('/').map(int.parse).toList();
      final timeParts =
          _timeController.text.trim().split(':').map(int.parse).toList();
      final startsAt = DateTime(
          dateParts[2], dateParts[1], dateParts[0], timeParts[0], timeParts[1]);
      if (widget.appointment == null) {
        postId = await context.read<AppState>().submitAppointment(
              patient: _selectedPatient!,
              startsAt: startsAt,
              notes: _notesController.text.trim(),
            );
      } else {
        await context.read<AppState>().updateAppointment(
              appointment: widget.appointment!,
              startsAt: startsAt,
              status: _status,
              notes: _notesController.text.trim(),
            );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.appointment == null
            ? 'Atendimento salvo (ID $postId).'
            : 'Atendimento atualizado.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Informe $label.' : null;

  @override
  Widget build(BuildContext context) {
    final patients = context.watch<AppState>().patients;

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.appointment == null
              ? 'Novo atendimento'
              : 'Editar atendimento')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.appointment == null
                  ? 'Agende uma sessão'
                  : 'Atualize o atendimento',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D3352),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'O atendimento será salvo no servidor local.',
              style: TextStyle(color: Color(0xFF64758F)),
            ),
            const SizedBox(height: 22),
            if (widget.appointment == null)
              DropdownButtonFormField<Patient>(
                initialValue: _selectedPatient,
                decoration: const InputDecoration(
                  labelText: 'Paciente',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: patients
                    .map((patient) => DropdownMenuItem(
                          value: patient,
                          child: Text(patient.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedPatient = value),
                validator: (value) =>
                    value == null ? 'Selecione um paciente.' : null,
              )
            else
              TextFormField(
                initialValue: widget.appointment!.patientName,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Paciente',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _dateController,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'Data',
                hintText: 'dd/mm/aaaa',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (value) {
                if (_required(value, 'a data') != null) {
                  return 'Informe a data.';
                }
                final parts = value!.trim().split('/');
                if (parts.length != 3) return 'Use dd/mm/aaaa.';
                final day = int.tryParse(parts[0]);
                final month = int.tryParse(parts[1]);
                final year = int.tryParse(parts[2]);
                if (day == null ||
                    month == null ||
                    year == null ||
                    year < 2000) {
                  return 'Informe uma data válida.';
                }
                final date = DateTime(year, month, day);
                if (date.day != day ||
                    date.month != month ||
                    date.year != year) {
                  return 'Informe uma data válida.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _timeController,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'Horário',
                hintText: 'hh:mm',
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              validator: (value) {
                if (_required(value, 'o horário') != null) {
                  return 'Informe o horário.';
                }
                return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                        .hasMatch(value!.trim())
                    ? null
                    : 'Use hh:mm (24 horas).';
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observações',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (widget.appointment != null) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Situação',
                  prefixIcon: Icon(Icons.event_note_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'scheduled', child: Text('Agendado')),
                  DropdownMenuItem(
                      value: 'completed', child: Text('Concluído')),
                  DropdownMenuItem(
                      value: 'cancelled', child: Text('Cancelado')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: Icon(widget.appointment == null
                  ? Icons.event_available_rounded
                  : Icons.save_rounded),
              label: Text(_sending
                  ? 'Salvando...'
                  : widget.appointment == null
                      ? 'Salvar atendimento'
                      : 'Salvar alterações'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
