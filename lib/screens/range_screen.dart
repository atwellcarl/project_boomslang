import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ballistic_profile.dart';
import '../models/difficulty_mode.dart';
import '../models/range_scenario.dart';
import '../services/range_scenario_generator.dart';
import '../widgets/range_viewport.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _RangeState {
  final RangeScenario scenario;
  final bool submitted;

  const _RangeState({required this.scenario, this.submitted = false});

  _RangeState copyWith({RangeScenario? scenario, bool? submitted}) =>
      _RangeState(
        scenario: scenario ?? this.scenario,
        submitted: submitted ?? this.submitted,
      );
}

class _RangeNotifier extends StateNotifier<_RangeState> {
  final BallisticProfile profile;
  final DifficultyMode difficulty;

  _RangeNotifier(this.profile, this.difficulty)
      : super(_RangeState(scenario: RangeScenarioGenerator.generate(profile, difficulty)));

  void submit() => state = state.copyWith(submitted: true);
  void reEngage() => state = state.copyWith(submitted: false);
  void nextScenario() =>
      state = _RangeState(scenario: RangeScenarioGenerator.generate(profile, difficulty));
}

final _rangeProvider = StateNotifierProvider.family<_RangeNotifier, _RangeState,
    (BallisticProfile, DifficultyMode)>(
  (ref, key) => _RangeNotifier(key.$1, key.$2),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class RangeScreen extends ConsumerStatefulWidget {
  final BallisticProfile profile;
  final DifficultyMode difficulty;

  const RangeScreen({super.key, required this.profile, required this.difficulty});

  @override
  ConsumerState<RangeScreen> createState() => _RangeScreenState();
}

class _RangeScreenState extends ConsumerState<RangeScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  late AnimationController _bannerController;

  Offset _reticleOffset = Offset.zero;
  Offset _sceneOffset = Offset.zero;
  bool _reticleInitialized = false;
  double _baseMilToPx = 20.0;
  double _zoom = 1.0;

  double get _milToPx => _baseMilToPx * _zoom;

  bool _isCorrect = false;
  bool _bannerShowing = false;

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

  void _initReticle(Size viewportSize) {
    if (!_reticleInitialized) {
      _baseMilToPx = viewportSize.height / 35.0;
      _reticleOffset = Offset(viewportSize.width / 2, viewportSize.height / 2);
      _sceneOffset = Offset.zero;
      _reticleInitialized = true;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {}

  void _onScaleUpdate(ScaleUpdateDetails details, Size viewportSize) {
    if (_bannerShowing) return;
    setState(() {
      if (details.pointerCount >= 2) {
        // Two fingers: pan the scene (background + targets) without moving the
        // reticle. Dividing by zoom keeps pan speed 1:1 regardless of zoom level.
        _sceneOffset = Offset(
          _sceneOffset.dx + details.focalPointDelta.dx,
          _sceneOffset.dy + details.focalPointDelta.dy,
        );
      } else {
        // One finger: move the reticle (aim)
        _reticleOffset = Offset(
          (_reticleOffset.dx + details.focalPointDelta.dx).clamp(0.0, viewportSize.width),
          (_reticleOffset.dy + details.focalPointDelta.dy).clamp(0.0, viewportSize.height),
        );
      }
    });
  }

  void _adjustZoom(double delta) {
    setState(() {
      _zoom = (_zoom + delta).clamp(0.5, 6.0);
    });
  }

  bool _checkHit(RangeScenario scenario, Size viewportSize) {
    final target = scenario.activeTarget;

    // Target's world position includes the scene pan offset (in screen-space px,
    // converted to world units by dividing by zoom so the canvas transform matches)
    final targetWorld = Offset(
      target.anchor.dx * viewportSize.width + _sceneOffset.dx / _zoom,
      target.anchor.dy * viewportSize.height + _sceneOffset.dy / _zoom,
    );

    // Project through the FFP zoom transform to get screen position
    final targetScreen = Offset(
      _zoom * (targetWorld.dx - _reticleOffset.dx) + _reticleOffset.dx,
      _zoom * (targetWorld.dy - _reticleOffset.dy) + _reticleOffset.dy,
    );

    final double milToPxScreen = _baseMilToPx * _zoom;
    final double windOffsetPx = (scenario.isRightHold ? 1 : -1) * scenario.windMil * milToPxScreen;
    final double elevOffsetPx = -scenario.elevationMil * milToPxScreen;

    final correctPos = Offset(targetScreen.dx + windOffsetPx, targetScreen.dy + elevOffsetPx);
    final tolerancePx = 0.4 * milToPxScreen;

    return ((_reticleOffset.dx - correctPos.dx).abs() <= tolerancePx &&
        (_reticleOffset.dy - correctPos.dy).abs() <= tolerancePx);
  }

  Future<void> _showBanner(bool isCorrect, _RangeNotifier notifier) async {
    if (_bannerShowing) return;
    _bannerShowing = true;
    setState(() => _isCorrect = isCorrect);

    if (isCorrect) {
      // Reset reticle to center for next scenario
      _reticleInitialized = false;
      notifier.nextScenario();
    }

    await _bannerController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _bannerController.reverse();
    if (!mounted) return;

    if (!isCorrect) notifier.reEngage();
    _bannerShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    final key = (widget.profile, widget.difficulty);
    final notifier = ref.read(_rangeProvider(key).notifier);
    final state = ref.watch(_rangeProvider(key));
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Viewport height = total height minus info strip (80) - fire btn (58) - spacers (36)
            final vpHeight = constraints.maxHeight - 80 - 58 - 36;
            final vpSize = Size(constraints.maxWidth, vpHeight);
            _initReticle(vpSize);

            return Stack(
              children: [
                Column(
                  children: [
                    // ---- Range viewport ----
                    SizedBox(
                      width: constraints.maxWidth,
                      height: vpHeight,
                      child: Stack(
                        children: [
                          RangeViewport(
                            scenario: scenario,
                            reticleOffset: _reticleOffset,
                            sceneOffset: _sceneOffset,
                            baseMilToPx: _baseMilToPx,
                            zoom: _zoom,
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: (d) => _onScaleUpdate(d, vpSize),
                          ),
                          // Zoom buttons
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Column(
                              children: [
                                _ZoomButton(
                                  icon: Icons.add,
                                  onTap: () => _adjustZoom(0.25),
                                ),
                                const SizedBox(height: 4),
                                _ZoomButton(
                                  icon: Icons.remove,
                                  onTap: () => _adjustZoom(-0.25),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ---- Scenario info strip ----
                    _ScenarioInfoStrip(scenario: scenario),

                    const SizedBox(height: 16),

                    // ---- FIRE button ----
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: state.submitted
                              ? null
                              : () {
                                  final isHit = _checkHit(scenario, vpSize);
                                  _player.play(AssetSource(
                                      isHit ? 'sounds/hit.wav' : 'sounds/miss.wav'));
                                  notifier.submit();
                                  _showBanner(isHit, notifier);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7C59),
                            disabledBackgroundColor: const Color(0xFF2A3A2A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'FIRE',
                            style: GoogleFonts.robotoMono(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),

                // ---- Drop-down banner overlay ----
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
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scenario info strip
// ---------------------------------------------------------------------------

class _ScenarioInfoStrip extends StatelessWidget {
  final RangeScenario scenario;

  const _ScenarioInfoStrip({required this.scenario});

  String _clockLabel(double clock) {
    if (clock == clock.truncate()) return '${clock.toInt()}:00';
    return '${clock.truncate()}:30';
  }

  @override
  Widget build(BuildContext context) {
    final windLabel = '${scenario.windSpeedMph.toInt()}mph @ ${_clockLabel(scenario.clockPosition)}';
    final holdDir = scenario.isRightHold ? 'R' : 'L';
    final windHoldLabel = scenario.windMil < 0.05
        ? 'NO WIND'
        : '${scenario.windMil.toStringAsFixed(1)} MIL $holdDir';

    return Container(
      height: 80,
      color: const Color(0xFF151B22),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Wind
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WIND', style: _labelStyle),
                const SizedBox(height: 4),
                Text(windLabel, style: _valueStyle),
                Text(windHoldLabel,
                    style: _valueStyle.copyWith(color: const Color(0xFFE8C84A))),
              ],
            ),
          ),

          // Distance
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('TARGET', style: _labelStyle),
                const SizedBox(height: 4),
                Text(
                  '${scenario.activeTarget.distanceMeters}M',
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),

          // Elevation
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('ELEVATION', style: _labelStyle),
                const SizedBox(height: 4),
                Text(
                  '${scenario.elevationMil.toStringAsFixed(1)} MIL',
                  style: _valueStyle.copyWith(color: const Color(0xFF8BA888)),
                ),
                Text('HOLD UP', style: _labelStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static final _labelStyle = GoogleFonts.robotoMono(
    color: const Color(0xFF8BA888),
    fontSize: 10,
    letterSpacing: 1.5,
  );

  static final _valueStyle = GoogleFonts.robotoMono(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );
}

// ---------------------------------------------------------------------------
// Zoom button
// ---------------------------------------------------------------------------

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xAA151B22),
          border: Border.all(color: const Color(0x554A7C59)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: const Color(0xFF8BA888), size: 20),
      ),
    );
  }
}
