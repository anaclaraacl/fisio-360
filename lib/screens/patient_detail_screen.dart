// Tela de responsabilidade de Pedro Cunha Silva.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../state/app_state.dart';
import 'patient_form_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({required this.patient, super.key});

  final Patient patient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late Future<Patient> _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  void _loadDetail() {
    // APRESENTAÇÃO: o detalhe busca os dados atualizados no servidor local.
    _detail = context.read<AppState>().fetchPatient(widget.patient.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhe do paciente')),
      body: FutureBuilder<Patient>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  TextButton.icon(
                    onPressed: () => setState(_loadDetail),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }
          return _buildContent(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Patient patient) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Color(patient.colorValue),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white.withValues(alpha: 0.75),
                child: const Icon(Icons.person_rounded,
                    size: 48, color: Color(0xFF1769C2)),
              ),
              const SizedBox(height: 14),
              Text(
                patient.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1D3352),
                    ),
              ),
              const SizedBox(height: 6),
              Text(patient.subtitle,
                  style: const TextStyle(color: Color(0xFF3D5574))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            // APRESENTAÇÃO: depois de editar, recarrega o detalhe exibido.
            final updated = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => PatientFormScreen(patient: patient),
              ),
            );
            if (!context.mounted || updated != true) return;
            setState(_loadDetail);
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar paciente'),
        ),
        const SizedBox(height: 22),
        _DetailRow(label: 'Idade', value: '${patient.age} anos'),
        _DetailRow(label: 'Nascimento', value: patient.birthDate),
        if (patient.phone.isNotEmpty)
          _DetailRow(label: 'Telefone', value: patient.phone),
        if (patient.condition.isNotEmpty)
          _DetailRow(label: 'Objetivo', value: patient.condition),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF64758F))),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D3352),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
