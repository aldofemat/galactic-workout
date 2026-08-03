import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'main.dart';
import 'onboarding/onboarding_flow.dart';

/// Primera pantalla que ve el usuario: decide entre login, el
/// cuestionario de onboarding o HOME, según haya sesión activa y si el
/// perfil ya tiene onboarding_completado = true.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? supabase.auth.currentSession;
        if (session == null) {
          return const AuthScreen();
        }
        // Key por user id: si cambia el usuario logueado, se reconstruye
        // y vuelve a checar el onboarding desde cero.
        return _OnboardingGate(key: ValueKey(session.user.id));
      },
    );
  }
}

class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate({super.key});

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  late final Future<bool> _onboardingCompletado;

  @override
  void initState() {
    super.initState();
    _onboardingCompletado = _checkOnboardingCompletado();
  }

  Future<bool> _checkOnboardingCompletado() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('profiles')
        .select('onboarding_completado')
        .eq('id', userId)
        .maybeSingle();
    return data?['onboarding_completado'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _onboardingCompletado,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('No se pudo verificar tu perfil: ${snapshot.error}'),
            ),
          );
        }
        if (snapshot.data == true) {
          return const HomeScreen();
        }
        return const OnboardingFlow();
      },
    );
  }
}
