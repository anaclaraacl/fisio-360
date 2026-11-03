// Tela de responsabilidade de Felipe Frade.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../state/app_state.dart';

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({this.patient, super.key});

  final Patient? patient;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _conditionController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // APRESENTAÇÃO: o mesmo formulário atende cadastro e edição com dados preenchidos.
    final patient = widget.patient;
    if (patient == null) return;
    _nameController.text = patient.name;
    final dateParts = patient.birthDate.split('-');
    if (dateParts.length == 3) {
      _birthDateController.text =
          '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}';
    }
    _phoneController.text = patient.phone;
    _conditionController.text = patient.condition;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // APRESENTAÇÃO: valida campos e data antes de enviar cadastro ou atualização.
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final parts = _birthDateController.text.trim().split('/');
      final birthDate = '${parts[2]}-${parts[1]}-${parts[0]}';
      if (widget.patient == null) {
        await context.read<AppState>().addPatient(
              name: _nameController.text.trim(),
              birthDate: birthDate,
              phone: _phoneController.text.trim(),
              condition: _conditionController.text.trim(),
            );
      } else {
        await context.read<AppState>().updatePatient(
              patient: widget.patient!,
              name: _nameController.text.trim(),
              birthDate: birthDate,
              phone: _phoneController.text.trim(),
              condition: _conditionController.text.trim(),
            );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.patient == null
            ? 'Paciente cadastrado no servidor local.'
            : 'Paciente atualizado.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (widget.patient == null) {
      Navigator.pop(context);
    } else {
      Navigator.pop(context, true);
    }
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Informe $label.' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.patient == null
              ? 'Cadastrar paciente'
              : 'Editar paciente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Dados do paciente',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D3352),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Os dados serão salvos no servidor local após a confirmação.',
              style: TextStyle(color: Color(0xFF64758F)),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => _required(value, 'o nome'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _birthDateController,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'Data de nascimento',
                hintText: 'dd/mm/aaaa',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
              validator: (value) {
                final requiredError = _required(value, 'a data de nascimento');
                if (requiredError != null) return requiredError;
                final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$')
                    .firstMatch(value!.trim());
                if (match == null) return 'Use dd/mm/aaaa.';
                final day = int.parse(match.group(1)!);
                final month = int.parse(match.group(2)!);
                final year = int.parse(match.group(3)!);
                final date = DateTime(year, month, day);
                if (date.day != day ||
                    date.month != month ||
                    date.year != year ||
                    date.isAfter(DateTime.now()) ||
                    year < 1900) {
                  return 'Informe uma data válida.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) => _required(value, 'o telefone'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _conditionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Queixa ou objetivo do tratamento',
                prefixIcon: Icon(Icons.accessibility_new_rounded),
              ),
              validator: (value) => _required(value, 'a queixa ou objetivo'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: Icon(widget.patient == null
                  ? Icons.check_rounded
                  : Icons.save_rounded),
              label: Text(_saving
                  ? 'Salvando...'
                  : widget.patient == null
                      ? 'Cadastrar paciente'
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
