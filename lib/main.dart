import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'state/app_state.dart';

// APRESENTAÇÃO: o app cria a conexão com a API e compartilha o AppState entre as telas.
// A interface aparece antes da tentativa de recuperar uma sessão anterior.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(api: await ApiService.create());
  runApp(
      ChangeNotifierProvider.value(value: state, child: const Fisio360App()));
  unawaited(state.initialize());
}

class Fisio360App extends StatelessWidget {
  const Fisio360App({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1769C2);

    return MaterialApp(
      title: 'Fisio 360',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF4F8FE),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8E4F2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8E4F2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: seed, width: 1.5),
          ),
        ),
      ),
      home: const _AppGate(),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    // APRESENTAÇÃO: esta escolha mostra carregamento, Login ou Home conforme a sessão.
    final state = context.watch<AppState>();
    if (state.isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Abrindo Fisio 360...'),
            ],
          ),
        ),
      );
    }
    return state.isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}
