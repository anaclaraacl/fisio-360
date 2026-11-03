// Tela de responsabilidade de Pedro Cunha Silva.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment_summary.dart';
import '../models/patient.dart';
import '../state/app_state.dart';
import '../widgets/section_heading.dart';
import 'appointment_form_screen.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // APRESENTAÇÃO: a Home carrega pacientes e atendimentos após abrir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().loadPatients();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // APRESENTAÇÃO: a saudação usa a primeira parte do e-mail da conta ativa.
    final patientList = state.patients;
    final appointmentList = state.appointments;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fisio 360'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: state.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Olá, ${state.professionalName} 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D3352),
                ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Aqui está um resumo da sua rotina.',
            style: TextStyle(color: Color(0xFF64758F)),
          ),
          const SizedBox(height: 20),
          _SummaryCard(
              patientCount: patientList.length,
              sentCount: appointmentList.length),
          const SizedBox(height: 24),
          SectionHeading(
            title: 'Atendimentos',
            actionLabel: 'Novo',
            onAction: () => _openAppointmentForm(context),
          ),
          const SizedBox(height: 8),
          if (state.appointmentsError != null) Text(state.appointmentsError!),
          if (!state.isLoadingPatients &&
              appointmentList.isEmpty &&
              state.appointmentsError == null)
            const Text('Nenhum atendimento cadastrado.'),
          ...appointmentList.map((appointment) => _AppointmentTile(
                appointment: appointment,
                onTap: () => _openAppointmentForm(context, appointment),
              )),
          const SizedBox(height: 20),
          SectionHeading(
            title: 'Pacientes',
            actionLabel: 'Cadastrar',
            onAction: () => _openPatientForm(context),
          ),
          const SizedBox(height: 8),
          if (state.isLoadingPatients)
            const Center(child: CircularProgressIndicator()),
          if (state.patientsError != null) ...[
            Text(state.patientsError!),
            TextButton.icon(
              onPressed: state.loadPatients,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
          if (!state.isLoadingPatients &&
              patientList.isEmpty &&
              state.patientsError == null)
            const Text('Nenhum paciente encontrado.'),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: patientList.length,
            itemBuilder: (context, index) {
              final patient = patientList[index];
              return _PatientTile(
                patient: patient,
                onTap: () async {
                  await context.read<AppState>().selectPatient(patient);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PatientDetailScreen(patient: patient),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAppointmentForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Atendimento'),
      ),
    );
  }

  void _openPatientForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const PatientFormScreen()),
    );
  }

  void _openAppointmentForm(BuildContext context,
      [AppointmentSummary? appointment]) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AppointmentFormScreen(appointment: appointment),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.patientCount, required this.sentCount});

  final int patientCount;
  final int sentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1769C2), Color(0xFF3B8EE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumo',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  '$sentCount atendimentos cadastrados',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$patientCount pacientes disponíveis',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.calendar_month_rounded,
                color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment, required this.onTap});

  final AppointmentSummary appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // APRESENTAÇÃO: a cor ajuda a identificar a situação, que continua escrita
    // no item para não depender apenas da percepção de vermelho ou verde.
    final (cardColor, timeBackground, timeForeground) =
        switch (appointment.status) {
      'completed' => (
          const Color(0xFFE8F5E9),
          const Color(0xFFC8E6C9),
          const Color(0xFF1B5E20),
        ),
      'cancelled' => (
          const Color(0xFFFFEBEE),
          const Color(0xFFFFCDD2),
          const Color(0xFFB71C1C),
        ),
      _ => (null, const Color(0xFFE5F1FF), const Color(0xFF1769C2)),
    };
    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: timeBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            appointment.time,
            style: TextStyle(
              color: timeForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(appointment.patientName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(appointment.kind),
        trailing: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Color(patient.colorValue),
          child: Text(
            patient.name.split(' ').map((part) => part[0]).take(2).join(),
            style: const TextStyle(
              color: Color(0xFF1D3352),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(patient.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(patient.subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
