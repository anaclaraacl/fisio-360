// Tela de responsabilidade de Ana Clara Camargos Lima.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _saving = false;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = context.read<AppState>().lastLogin ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    // APRESENTAÇÃO: o formulário valida os campos e a API confere a senha.
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context
          .read<AppState>()
          .login(_emailController.text.trim(), _passwordController.text);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 88,
                      width: 88,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F1FF),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        size: 48,
                        color: Color(0xFF1769C2),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Fisio 360',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1D3352),
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Organize seus atendimentos com mais tranquilidade.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF64758F),
                          ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Informe seu e-mail.'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      // APRESENTAÇÃO: o ícone de olho só muda a visualização da senha.
                      obscureText: !_passwordVisible,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible
                              ? 'Ocultar senha'
                              : 'Mostrar senha',
                          onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                          icon: Icon(_passwordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Informe sua senha.'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _continue,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(_saving ? 'Aguarde...' : 'Entrar'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Não tenho conta · Criar acesso'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Conecte-se ao servidor local para acessar seus pacientes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64758F)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
