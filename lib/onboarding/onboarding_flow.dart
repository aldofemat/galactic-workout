import 'package:flutter/material.dart';
import '../home_screen.dart';
import '../main.dart';
import 'onboarding_answers.dart';
import 'onboarding_steps.dart';

enum _Step {
  p1,
  p2,
  p3a,
  p3b,
  p4,
  p5a,
  p5b,
  p6a,
  p6b,
  p7a,
  p7b,
  p8a,
  p8b,
  p9a,
  p9b,
  finishing,
}

/// Cuestionario de onboarding: 9 preguntas con ramificaciones (lesión,
/// reps de habilidad) y una pregunta final (P9) condicional a que las
/// tres pruebas base den un nivel avanzado. Al terminar guarda el
/// perfil completo en Supabase y navega a la pantalla de cámara.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  _Step _step = _Step.p1;
  int _totalQuestions = 9;
  String? _finishError;
  final OnboardingAnswers answers = OnboardingAnswers();

  void _goTo(_Step step) => setState(() => _step = step);

  void _advanceFrom(_Step current) {
    switch (current) {
      case _Step.p1:
        _goTo(_Step.p2);
        break;
      case _Step.p2:
        _goTo(_Step.p3a);
        break;
      case _Step.p3a:
        _goTo(answers.tieneLesion == true ? _Step.p3b : _Step.p4);
        break;
      case _Step.p3b:
        _goTo(_Step.p4);
        break;
      case _Step.p4:
        _goTo(_Step.p5a);
        break;
      case _Step.p5a:
        _goTo(answers.sentadillasPuede == true ? _Step.p5b : _Step.p6a);
        break;
      case _Step.p5b:
        _goTo(_Step.p6a);
        break;
      case _Step.p6a:
        _goTo(answers.lagartijasPuede == true ? _Step.p6b : _Step.p7a);
        break;
      case _Step.p6b:
        _goTo(_Step.p7a);
        break;
      case _Step.p7a:
        if (answers.dominadasPuede == true) {
          _goTo(_Step.p7b);
        } else {
          _afterP7();
        }
        break;
      case _Step.p7b:
        _afterP7();
        break;
      case _Step.p8a:
        if (answers.corre == true) {
          _goTo(_Step.p8b);
        } else {
          _afterP8();
        }
        break;
      case _Step.p8b:
        _afterP8();
        break;
      case _Step.p9a:
        if (answers.paradaManos == true) {
          _goTo(_Step.p9b);
        } else {
          _finish();
        }
        break;
      case _Step.p9b:
        _finish();
        break;
      case _Step.finishing:
        break;
    }
  }

  void _afterP7() {
    // Ya sabemos las tres reps base: fija el total real de preguntas
    // para que la barra de progreso llegue a 100% en el paso correcto.
    _totalQuestions = answers.calificaParaP9 ? 9 : 8;
    _goTo(_Step.p8a);
  }

  void _afterP8() {
    if (answers.calificaParaP9) {
      _goTo(_Step.p9a);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() {
      _step = _Step.finishing;
      _finishError = null;
    });
    final userId = supabase.auth.currentUser!.id;
    try {
      await Future.wait([
        supabase.from('profiles').upsert(answers.toProfileMap(userId)),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishError = 'No se pudo guardar tu perfil: $e');
    }
  }

  int _questionNumber(_Step step) {
    switch (step) {
      case _Step.p1:
        return 1;
      case _Step.p2:
        return 2;
      case _Step.p3a:
      case _Step.p3b:
        return 3;
      case _Step.p4:
        return 4;
      case _Step.p5a:
      case _Step.p5b:
        return 5;
      case _Step.p6a:
      case _Step.p6b:
        return 6;
      case _Step.p7a:
      case _Step.p7b:
        return 7;
      case _Step.p8a:
      case _Step.p8b:
        return 8;
      case _Step.p9a:
      case _Step.p9b:
        return 9;
      case _Step.finishing:
        return _totalQuestions;
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.p1:
        return OnboardingP1(
            answers: answers, onNext: () => _advanceFrom(_Step.p1));
      case _Step.p2:
        return OnboardingP2(
            answers: answers, onNext: () => _advanceFrom(_Step.p2));
      case _Step.p3a:
        return OnboardingP3a(
            answers: answers, onNext: () => _advanceFrom(_Step.p3a));
      case _Step.p3b:
        return OnboardingP3b(
            answers: answers, onNext: () => _advanceFrom(_Step.p3b));
      case _Step.p4:
        return OnboardingP4(
            answers: answers, onNext: () => _advanceFrom(_Step.p4));
      case _Step.p5a:
        return OnboardingSkillYesNo(
          pregunta:
              '¿Puedes hacer sentadillas completas tú solo, sin apoyarte de nada?',
          onYes: () {
            answers.sentadillasPuede = true;
            _advanceFrom(_Step.p5a);
          },
          onNo: () {
            answers.sentadillasPuede = false;
            answers.sentadillasReps = null;
            _advanceFrom(_Step.p5a);
          },
        );
      case _Step.p5b:
        return OnboardingRepsInput(
          pregunta: '¿Cuántas seguidas puedes hacer hoy, sin parar?',
          initialValue: answers.sentadillasReps,
          onSubmit: (v) {
            answers.sentadillasReps = v;
            _advanceFrom(_Step.p5b);
          },
        );
      case _Step.p6a:
        return OnboardingSkillYesNo(
          pregunta:
              '¿Puedes hacer lagartijas completas, con el pecho casi al piso?',
          onYes: () {
            answers.lagartijasPuede = true;
            _advanceFrom(_Step.p6a);
          },
          onNo: () {
            answers.lagartijasPuede = false;
            answers.lagartijasReps = null;
            _advanceFrom(_Step.p6a);
          },
        );
      case _Step.p6b:
        return OnboardingRepsInput(
          pregunta: '¿Cuántas seguidas puedes hacer hoy, sin parar?',
          initialValue: answers.lagartijasReps,
          onSubmit: (v) {
            answers.lagartijasReps = v;
            _advanceFrom(_Step.p6b);
          },
        );
      case _Step.p7a:
        return OnboardingSkillYesNo(
          pregunta:
              '¿Puedes hacer dominadas completas, subiendo la barbilla arriba de la barra?',
          onYes: () {
            answers.dominadasPuede = true;
            _advanceFrom(_Step.p7a);
          },
          onNo: () {
            answers.dominadasPuede = false;
            answers.dominadasReps = null;
            _advanceFrom(_Step.p7a);
          },
        );
      case _Step.p7b:
        return OnboardingRepsInput(
          pregunta: '¿Cuántas seguidas puedes hacer hoy, sin parar?',
          initialValue: answers.dominadasReps,
          onSubmit: (v) {
            answers.dominadasReps = v;
            _advanceFrom(_Step.p7b);
          },
        );
      case _Step.p8a:
        return OnboardingSkillYesNo(
          pregunta: '¿Actualmente sales a correr o trotar?',
          onYes: () {
            answers.corre = true;
            _advanceFrom(_Step.p8a);
          },
          onNo: () {
            answers.corre = false;
            answers.correTiempo = null;
            _advanceFrom(_Step.p8a);
          },
        );
      case _Step.p8b:
        return OnboardingChoiceButtons(
          pregunta: '¿Cuánto tiempo aguantas trotando sin parar?',
          options: const [
            MapEntry('menos_10', 'Menos de 10 min'),
            MapEntry('10_20', '10 a 20 min'),
            MapEntry('20_40', '20 a 40 min'),
            MapEntry('mas_40', 'Más de 40 min'),
          ],
          onSelected: (v) {
            answers.correTiempo = v;
            _advanceFrom(_Step.p8b);
          },
        );
      case _Step.p9a:
        return OnboardingSkillYesNo(
          pregunta: 'Última: ¿puedes pararte de manos?',
          onYes: () {
            answers.paradaManos = true;
            _advanceFrom(_Step.p9a);
          },
          onNo: () {
            answers.paradaManos = false;
            answers.paradaManosTiempo = null;
            _advanceFrom(_Step.p9a);
          },
        );
      case _Step.p9b:
        return OnboardingChoiceButtons(
          pregunta: '¿Cuánto tiempo aguantas?',
          options: const [
            MapEntry('menos_1min', 'Menos de 1 min'),
            MapEntry('1_3min', '1 a 3 min'),
            MapEntry('3_10min', '3 a 10 min'),
            MapEntry('mas_10min', 'Más de 10 min / Camino de manos 😎'),
          ],
          onSelected: (v) {
            answers.paradaManosTiempo = v;
            _advanceFrom(_Step.p9b);
          },
        );
      case _Step.finishing:
        return _FinishingView(error: _finishError, onRetry: _finish);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_step != _Step.finishing)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _questionNumber(_step) / _totalQuestions,
                    minHeight: 8,
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishingView extends StatelessWidget {
  const _FinishingView({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final err = error;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: err == null
            ? const [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text('Listo. Armando tu rutina...',
                    style: TextStyle(fontSize: 20)),
              ]
            : [
                Text(err, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: onRetry, child: const Text('Reintentar')),
              ],
      ),
    );
  }
}
