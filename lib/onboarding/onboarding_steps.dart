import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'onboarding_answers.dart';

class EquipmentOption {
  EquipmentOption(
      {required this.slug, required this.nombre, required this.orden});

  final String slug;
  final String nombre;
  final int orden;

  factory EquipmentOption.fromMap(Map<String, dynamic> map) {
    return EquipmentOption(
      slug: map['slug'] as String,
      nombre: map['nombre'] as String,
      orden: map['orden'] as int,
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold));
  }
}

class _YesNoButtons extends StatelessWidget {
  const _YesNoButtons({
    required this.onYes,
    required this.onNo,
    this.noLabel = 'No',
  });

  final VoidCallback onYes;
  final VoidCallback onNo;
  final String noLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: onNo,
            child: Text(noLabel),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: onYes,
            child: const Text('Sí'),
          ),
        ),
      ],
    );
  }
}

/// Pregunta de sí/no reutilizada por P5, P6, P7, P8 y P9.
class OnboardingSkillYesNo extends StatelessWidget {
  const OnboardingSkillYesNo({
    super.key,
    required this.pregunta,
    required this.onYes,
    required this.onNo,
  });

  final String pregunta;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepTitle(pregunta),
        const SizedBox(height: 32),
        _YesNoButtons(onYes: onYes, onNo: onNo),
      ],
    );
  }
}

/// Input numérico de reps, reutilizado por P5b, P6b y P7b.
class OnboardingRepsInput extends StatefulWidget {
  const OnboardingRepsInput({
    super.key,
    required this.pregunta,
    required this.initialValue,
    required this.onSubmit,
  });

  final String pregunta;
  final int? initialValue;
  final ValueChanged<int> onSubmit;

  @override
  State<OnboardingRepsInput> createState() => _OnboardingRepsInputState();
}

class _OnboardingRepsInputState extends State<OnboardingRepsInput> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialValue?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Ingresa un número válido');
      return;
    }
    widget.onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepTitle(widget.pregunta),
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixText: 'reps',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _submit, child: const Text('Continuar')),
      ],
    );
  }
}

/// Botones de opción múltiple (una sola respuesta), usados por P8b y P9b.
class OnboardingChoiceButtons extends StatelessWidget {
  const OnboardingChoiceButtons({
    super.key,
    required this.pregunta,
    required this.options,
    required this.onSelected,
  });

  final String pregunta;
  final List<MapEntry<String, String>> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepTitle(pregunta),
        const SizedBox(height: 32),
        for (final opt in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () => onSelected(opt.key),
              child: Text(opt.value),
            ),
          ),
      ],
    );
  }
}

class _GenderButton extends StatelessWidget {
  const _GenderButton(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor:
            selected ? Theme.of(context).colorScheme.primaryContainer : null,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(label),
    );
  }
}

class _WheelPicker extends StatelessWidget {
  const _WheelPicker({
    required this.label,
    required this.suffix,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String suffix;
  final int min;
  final int max;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = max - min + 1;
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 120,
          child: CupertinoPicker(
            scrollController:
                FixedExtentScrollController(initialItem: value - min),
            itemExtent: 36,
            onSelectedItemChanged: (index) => onChanged(min + index),
            children: [
              for (var i = 0; i < count; i++) Center(child: Text('${min + i}'))
            ],
          ),
        ),
        Text(suffix, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

/// P1: género, edad, peso y estatura con selectores tipo ruleta.
class OnboardingP1 extends StatefulWidget {
  const OnboardingP1({super.key, required this.answers, required this.onNext});

  final OnboardingAnswers answers;
  final VoidCallback onNext;

  @override
  State<OnboardingP1> createState() => _OnboardingP1State();
}

class _OnboardingP1State extends State<OnboardingP1> {
  static const _minEdad = 10;
  static const _maxEdad = 90;
  static const _minPeso = 30;
  static const _maxPeso = 200;
  static const _minEstatura = 100;
  static const _maxEstatura = 220;

  late int _edad;
  late int _peso;
  late int _estatura;
  String? _genero;

  @override
  void initState() {
    super.initState();
    _genero = widget.answers.genero;
    _edad = widget.answers.edad ?? 25;
    _peso = widget.answers.pesoKg?.round() ?? 70;
    _estatura = widget.answers.estaturaCm?.round() ?? 170;
  }

  void _submit() {
    widget.answers
      ..genero = _genero
      ..edad = _edad
      ..pesoKg = _peso.toDouble()
      ..estaturaCm = _estatura.toDouble();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _genero != null;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle('Cuéntanos de ti'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _GenderButton(
                  label: 'Hombre',
                  selected: _genero == 'hombre',
                  onTap: () => setState(() => _genero = 'hombre'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderButton(
                  label: 'Mujer',
                  selected: _genero == 'mujer',
                  onTap: () => setState(() => _genero = 'mujer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _WheelPicker(
                  label: 'Edad',
                  suffix: 'años',
                  min: _minEdad,
                  max: _maxEdad,
                  value: _edad,
                  onChanged: (v) => setState(() => _edad = v),
                ),
              ),
              Expanded(
                child: _WheelPicker(
                  label: 'Peso',
                  suffix: 'kg',
                  min: _minPeso,
                  max: _maxPeso,
                  value: _peso,
                  onChanged: (v) => setState(() => _peso = v),
                ),
              ),
              Expanded(
                child: _WheelPicker(
                  label: 'Estatura',
                  suffix: 'cm',
                  min: _minEstatura,
                  max: _maxEstatura,
                  value: _estatura,
                  onChanged: (v) => setState(() => _estatura = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: canContinue ? _submit : null,
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

/// P2: días por semana que entrena, 0-7, tap y avanza.
class OnboardingP2 extends StatelessWidget {
  const OnboardingP2({super.key, required this.answers, required this.onNext});

  final OnboardingAnswers answers;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _StepTitle('¿Cuántos días por semana entrenas actualmente?'),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i <= 7; i++)
              SizedBox(
                width: 64,
                height: 64,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(shape: const CircleBorder()),
                  onPressed: () {
                    answers.diasEntrenaSemana = i;
                    onNext();
                  },
                  child: Text('$i', style: const TextStyle(fontSize: 20)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// P3a: ¿tiene lesión? Sí/No.
class OnboardingP3a extends StatelessWidget {
  const OnboardingP3a({super.key, required this.answers, required this.onNext});

  final OnboardingAnswers answers;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _StepTitle(
            '¿Tienes alguna lesión o dolor que te limite al entrenar?'),
        const SizedBox(height: 32),
        _YesNoButtons(
          noLabel: 'No, ninguna',
          onNo: () {
            answers.tieneLesion = false;
            answers.zonasLesion.clear();
            answers.lesionOtraTexto = null;
            onNext();
          },
          onYes: () {
            answers.tieneLesion = true;
            onNext();
          },
        ),
      ],
    );
  }
}

/// P3b: zonas de la lesión (checkboxes) + texto libre si marca "Otra".
class OnboardingP3b extends StatefulWidget {
  const OnboardingP3b({super.key, required this.answers, required this.onNext});

  final OnboardingAnswers answers;
  final VoidCallback onNext;

  @override
  State<OnboardingP3b> createState() => _OnboardingP3bState();
}

class _OnboardingP3bState extends State<OnboardingP3b> {
  static const _zonas = [
    'Rodillas',
    'Espalda baja',
    'Hombros',
    'Muñecas',
    'Otra'
  ];

  late Set<String> _seleccion;
  late TextEditingController _otraController;

  @override
  void initState() {
    super.initState();
    _seleccion = {...widget.answers.zonasLesion};
    _otraController =
        TextEditingController(text: widget.answers.lesionOtraTexto ?? '');
  }

  @override
  void dispose() {
    _otraController.dispose();
    super.dispose();
  }

  void _submit() {
    widget.answers.zonasLesion
      ..clear()
      ..addAll(_seleccion);
    widget.answers.lesionOtraTexto =
        _seleccion.contains('Otra') && _otraController.text.trim().isNotEmpty
            ? _otraController.text.trim()
            : null;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle('¿En qué zona?'),
          const SizedBox(height: 8),
          for (final zona in _zonas)
            CheckboxListTile(
              title: Text(zona),
              value: _seleccion.contains(zona),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _seleccion.add(zona);
                } else {
                  _seleccion.remove(zona);
                }
              }),
            ),
          if (_seleccion.contains('Otra')) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _otraController,
              decoration: const InputDecoration(
                labelText: 'Cuéntanos cuál',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _seleccion.isNotEmpty ? _submit : null,
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

/// P4: equipo disponible, leído de equipment_options (activo = true,
/// ordenado por 'orden'). "sin_equipo" es excluyente con el resto.
class OnboardingP4 extends StatefulWidget {
  const OnboardingP4({super.key, required this.answers, required this.onNext});

  final OnboardingAnswers answers;
  final VoidCallback onNext;

  @override
  State<OnboardingP4> createState() => _OnboardingP4State();
}

class _OnboardingP4State extends State<OnboardingP4> {
  static const _sinEquipoSlug = 'sin_equipo';

  late final Future<List<EquipmentOption>> _optionsFuture;
  late Set<String> _seleccion;

  @override
  void initState() {
    super.initState();
    _seleccion = {...widget.answers.equipo};
    _optionsFuture = _fetchOptions();
  }

  Future<List<EquipmentOption>> _fetchOptions() async {
    final data = await supabase
        .from('equipment_options')
        .select()
        .eq('activo', true)
        .order('orden', ascending: true);
    return (data as List)
        .map((row) => EquipmentOption.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  void _toggle(String slug, bool checked) {
    setState(() {
      if (slug == _sinEquipoSlug) {
        _seleccion.clear();
        if (checked) _seleccion.add(_sinEquipoSlug);
      } else {
        _seleccion.remove(_sinEquipoSlug);
        if (checked) {
          _seleccion.add(slug);
        } else {
          _seleccion.remove(slug);
        }
      }
    });
  }

  void _submit() {
    widget.answers.equipo
      ..clear()
      ..addAll(_seleccion);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EquipmentOption>>(
      future: _optionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('No se pudo cargar el equipo: ${snapshot.error}'));
        }
        final options = snapshot.data ?? [];
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StepTitle('¿Con qué equipo Aldo Femat cuentas?'),
              const SizedBox(height: 8),
              for (final option in options)
                CheckboxListTile(
                  title: Text(option.nombre),
                  value: _seleccion.contains(option.slug),
                  onChanged: (checked) =>
                      _toggle(option.slug, checked ?? false),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _seleccion.isNotEmpty ? _submit : null,
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
