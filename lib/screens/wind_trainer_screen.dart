import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ballistic_profile.dart';
import '../models/difficulty_mode.dart';
import '../models/wind_scenario.dart';
import '../models/reticle_type.dart';
import '../services/scenario_generator.dart';
import '../widgets/wind_dial.dart';
import '../widgets/answer_input.dart';

class _TrainerState {
  final WindScenario scenario;
  final double userValue;
  final bool userIsRight;
  final bool submitted;
  final ReticleType reticleType;

  const _TrainerState({
    required this.scenario,
    required this.reticleType,
    this.userValue = 0.0,
    this.userIsRight = true,
    this.submitted = false,
  });

  bool get isCorrect {
    final step = reticleType.drumStep;
    final correctInUnit = reticleType.fromMil(scenario.correctMil);
    final steppedCorrect = (correctInUnit / step).round() * step;
    final valueCorrect = (userValue - steppedCorrect).abs() <= step;
    final dirCorrect = scenario.correctMil < 0.05 || userIsRight == scenario.isRightWind;
    return valueCorrect && dirCorrect;
  }

  _TrainerState copyWith({
    WindScenario? scenario,
    double? userValue,
    bool? userIsRight,
    bool? submitted,
    ReticleType? reticleType,
  }) {
    return _TrainerState(
      scenario: scenario ?? this.scenario,
      userValue: userValue ?? this.userValue,
      userIsRight: userIsRight ?? this.userIsRight,
      submitted: submitted ?? this.submitted,
      reticleType: reticleType ?? this.reticleType,
    );
  }
}

class _TrainerNotifier extends StateNotifier<_TrainerState> {
  final BallisticProfile profile;
  final DifficultyMode difficulty;
  final ReticleType reticleType;

  _TrainerNotifier(this.profile, this.difficulty, this.reticleType)
      : super(_TrainerState(
          scenario: ScenarioGenerator.generate(profile, difficulty),
          reticleType: reticleType,
        ));

  void setValue(double value) => state = state.copyWith(userValue: value);
  void setDirection(bool isRight) => state = state.copyWith(userIsRight: isRight);
  void submit() => state = state.copyWith(submitted: true);
  void reEngage() => state = state.copyWith(submitted: false);
  void nextScenario() => state = _TrainerState(
    scenario: ScenarioGenerator.generate(profile, difficulty),
    reticleType: reticleType,
  );
}

final _trainerProvider = StateNotifierProvider.family<_TrainerNotifier, _TrainerState, (BallisticProfile, DifficultyMode, ReticleType)>(
  (ref, key) => _TrainerNotifier(key.$1, key.$2, key.$3),
);

class WindTrainerScreen extends ConsumerStatefulWidget {
  final BallisticProfile profile;
  final ReticleType reticleType;

  const WindTrainerScreen({super.key, required this.profile, required this.reticleType});

  @override
  ConsumerState<WindTrainerScreen> createState() => _WindTrainerScreenState();
}

class _WindTrainerScreenState extends ConsumerState<WindTrainerScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  late AnimationController _bannerController;
  bool _isCorrect = false;
  int _bannerGen = 0;
  DifficultyMode _difficulty = DifficultyMode.basic;

  @override
  void initState() {
    super.initState();
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _showBanner(bool isCorrect, _TrainerNotifier notifier) async {
    _bannerGen++;
    final gen = _bannerGen;
    setState(() => _isCorrect = isCorrect);

    // Advance scenario immediately on hit; banner is just a notification overlay
    if (isCorrect) notifier.nextScenario();

    _bannerController.stop();
    await _bannerController.forward(from: 0);
    if (!mounted || gen != _bannerGen) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted || gen != _bannerGen) return;
    await _bannerController.reverse();
    if (!mounted || gen != _bannerGen) return;

    if (!isCorrect) notifier.reEngage();
  }

  @override
  Widget build(BuildContext context) {
    final key = (widget.profile, _difficulty, widget.reticleType);
    final notifier = ref.read(_trainerProvider(key).notifier);

    ref.listen(_trainerProvider(key), (prev, next) {
      if (next.submitted && !(prev?.submitted ?? false)) {
        _player.play(AssetSource(next.isCorrect ? 'sounds/hit.wav' : 'sounds/miss.wav'));
        _showBanner(next.isCorrect, notifier);
      }
    });

    final state = ref.watch(_trainerProvider(key));
    final scenario = state.scenario;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8BA888)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.profile.shortName,
          style: GoogleFonts.robotoMono(
            color: const Color(0xFF8BA888),
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Difficulty toggle
                _DifficultyBar(
                  difficulty: _difficulty,
                  onChanged: (d) => setState(() => _difficulty = d),
                ),

                // Distance display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  color: const Color(0xFF151B22),
                  child: Text(
                    '${scenario.distanceMeters}M',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                ),

                // Wind dial
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: WindDial(
                      clockPosition: scenario.clockPosition,
                      windSpeedMph: scenario.windSpeedMph,
                    ),
                  ),
                ),

                // Answer input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnswerInput(
                    value: state.userValue,
                    isRight: state.userIsRight,
                    reticleType: widget.reticleType,
                    onValueChanged: notifier.setValue,
                    onDirectionChanged: notifier.setDirection,
                    onSubmit: notifier.submit,
                    submitted: state.submitted,
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),

            // Drop-down banner overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _bannerController,
                builder: (context, child) => ClipRect(
                  child: Align(
                    heightFactor: _bannerController.value,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                  color: _isCorrect
                      ? const Color(0xFF4A7C59).withAlpha(230)
                      : const Color(0xFF8B3A3A).withAlpha(230),
                  child: Text(
                    _isCorrect ? 'HIT — NEXT TARGET' : 'MISS — RE-ENGAGE!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared difficulty toggle bar
// ---------------------------------------------------------------------------

class _DifficultyBar extends StatelessWidget {
  final DifficultyMode difficulty;
  final ValueChanged<DifficultyMode> onChanged;

  const _DifficultyBar({required this.difficulty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          _Chip(
            label: 'BASIC',
            selected: difficulty == DifficultyMode.basic,
            onTap: () => onChanged(DifficultyMode.basic),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'EXPERT',
            selected: difficulty == DifficultyMode.expert,
            onTap: () => onChanged(DifficultyMode.expert),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A2E1F) : const Color(0xFF151B22),
          border: Border.all(
            color: selected ? const Color(0xFF4A7C59) : const Color(0xFF2A3A2A),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.robotoMono(
            color: selected ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
