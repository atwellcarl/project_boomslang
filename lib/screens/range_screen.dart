import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ballistic_profile.dart';
import '../models/difficulty_mode.dart';
import '../models/range_scenario.dart';
import '../models/range_target.dart';
import '../services/range_scenario_generator.dart';
import '../widgets/range_viewport.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _RangeState {
  final RangeScenario scenario;
  final List<RangeTarget> engagedTargets; // hit so far in this set of five
  final bool submitted;

  const _RangeState({
    required this.scenario,
    this.engagedTargets = const [],
    this.submitted = false,
  });

  _RangeState copyWith({
    RangeScenario? scenario,
    List<RangeTarget>? engagedTargets,
    bool? submitted,
  }) =>
      _RangeState(
        scenario: scenario ?? this.scenario,
        engagedTargets: engagedTargets ?? this.engagedTargets,
        submitted: submitted ?? this.submitted,
      );

  bool get isRangeClear =>
      engagedTargets.length + 1 >= scenario.allTargets.length;
}

class _RangeNotifier extends StateNotifier<_RangeState> {
  final BallisticProfile profile;
  final DifficultyMode difficulty;

  _RangeNotifier(this.profile, this.difficulty)
      : super(_RangeState(scenario: RangeScenarioGenerator.generate(profile, difficulty)));

  void submit() => state = state.copyWith(submitted: true);
  void reEngage() => state = state.copyWith(submitted: false);

  /// Advance to next unengaged target in the current set. Call after a hit.
  void nextTarget() {
    final newEngaged = [...state.engagedTargets, state.scenario.activeTarget];
    final remaining = state.scenario.allTargets
        .where((t) => !newEngaged.contains(t))
        .toList();

    if (remaining.isEmpty) {
      // All five done — fresh set.
      state = _RangeState(scenario: RangeScenarioGenerator.generate(profile, difficulty));
      return;
    }

    final next = remaining[Random().nextInt(remaining.length)];
    state = _RangeState(
      scenario: RangeScenarioGenerator.generateForTarget(
          next, state.scenario.allTargets, profile, difficulty),
      engagedTargets: newEngaged,
    );
  }
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

  const RangeScreen({super.key, required this.profile});

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
  Size _vpSize = Size.zero;
  bool _isPanningScene = false;
  double _zoomAtGestureStart = 1.0;

  double get _milToPx => _baseMilToPx * _zoom;

  DifficultyMode _difficulty = DifficultyMode.basic;
  bool _isCorrect = false;
  bool _rangeClear = false;
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
    _vpSize = viewportSize; // always current
    if (!_reticleInitialized) {
      _baseMilToPx = viewportSize.height / 35.0;
      _reticleOffset = Offset(viewportSize.width / 2, viewportSize.height / 2);
      _sceneOffset = Offset.zero;
      _reticleInitialized = true;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _zoom;
    // Commit zone at gesture start so it stays stable for the whole drag.
    // Left half = ORIENT (pan scene), right half = AIM (move reticle).
    _isPanningScene = details.localFocalPoint.dx < _vpSize.width / 2;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size viewportSize) {
    if (_bannerShowing) return;
    setState(() {
      if (details.pointerCount >= 2) {
        // Two fingers anywhere = pinch-to-zoom. Min 1.0 keeps landscape full-screen.
        _zoom = (_zoomAtGestureStart * details.scale).clamp(1.0, 6.0);
      } else if (_isPanningScene) {
        // Clamp scene pan so the background image never scrolls outside the
        // viewport. Image is 2560×1440 (16:9) scaled to cover viewport height.
        final double scaledImgW = (2560 / 1440) * viewportSize.height;
        final double maxDx = ((scaledImgW - viewportSize.width) / 2) * _zoom;
        final double maxDy = viewportSize.height * (_zoom - 1) / 2;
        _sceneOffset = Offset(
          (_sceneOffset.dx + details.focalPointDelta.dx).clamp(-maxDx, maxDx),
          (_sceneOffset.dy + details.focalPointDelta.dy).clamp(-maxDy, maxDy),
        );
      } else {
        // Allow reticle to travel well off-screen so large elevation/wind holds
        // can be applied. Bound loosely so it can't be lost entirely.
        _reticleOffset = Offset(
          (_reticleOffset.dx + details.focalPointDelta.dx)
              .clamp(-viewportSize.width * 2, viewportSize.width * 3),
          (_reticleOffset.dy + details.focalPointDelta.dy)
              .clamp(-viewportSize.height * 2, viewportSize.height * 3),
        );
      }
    });
  }

  void _adjustZoom(double delta) {
    setState(() {
      _zoom = (_zoom + delta).clamp(1.0, 6.0);
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

  Future<void> _showBanner(bool isCorrect, _RangeNotifier notifier,
      {bool rangeClear = false}) async {
    if (_bannerShowing) return;
    _bannerShowing = true;
    setState(() {
      _isCorrect = isCorrect;
      _rangeClear = rangeClear;
    });

    if (isCorrect) {
      _reticleInitialized = false;
      notifier.nextTarget(); // advances within the set, or resets when all five done
    }

    await _bannerController.forward(from: 0);
    await Future.delayed(Duration(milliseconds: rangeClear ? 1400 : 900));
    if (!mounted) return;
    await _bannerController.reverse();
    if (!mounted) return;

    if (!isCorrect) notifier.reEngage();
    _bannerShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    final key = (widget.profile, _difficulty);
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
            // Viewport height = total height minus difficulty bar (38) - info strip (80) - fire btn (58) - spacers (36)
            final vpHeight = constraints.maxHeight - 38 - 80 - 58 - 36;
            final vpSize = Size(constraints.maxWidth, vpHeight);
            _initReticle(vpSize);

            return Stack(
              children: [
                Column(
                  children: [
                    // ---- Difficulty toggle ----
                    _DifficultyBar(
                      difficulty: _difficulty,
                      onChanged: (d) => setState(() {
                        _difficulty = d;
                        _reticleInitialized = false;
                      }),
                    ),

                    // ---- Range viewport ----
                    SizedBox(
                      width: constraints.maxWidth,
                      height: vpHeight,
                      child: Stack(
                        children: [
                          RangeViewport(
                            scenario: scenario,
                            engagedTargets: state.engagedTargets,
                            reticleOffset: _reticleOffset,
                            sceneOffset: _sceneOffset,
                            baseMilToPx: _baseMilToPx,
                            zoom: _zoom,
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: (d) => _onScaleUpdate(d, vpSize),
                          ),

                          // Mini wind clock — top-left
                          Positioned(
                            left: 10,
                            top: 10,
                            child: _WindClock(scenario: scenario),
                          ),

                          // ORIENT hint — bottom-left
                          const Positioned(
                            left: 10,
                            bottom: 10,
                            child: _ZoneHint(
                              icon: Icons.open_with,
                              label: 'ORIENT',
                            ),
                          ),

                          // AIM hint + zoom buttons — bottom-right
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const _ZoneHint(
                                  icon: Icons.gps_fixed,
                                  label: 'AIM',
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _ZoomButton(
                                      icon: Icons.remove,
                                      onTap: () => _adjustZoom(-0.25),
                                    ),
                                    const SizedBox(width: 4),
                                    _ZoomButton(
                                      icon: Icons.add,
                                      onTap: () => _adjustZoom(0.25),
                                    ),
                                  ],
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
                                  final clear = isHit && state.isRangeClear;
                                  _player.play(AssetSource(
                                      isHit ? 'sounds/hit.wav' : 'sounds/miss.wav'));
                                  notifier.submit();
                                  _showBanner(isHit, notifier, rangeClear: clear);
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
                        _isCorrect
                            ? (_rangeClear ? 'RANGE CLEAR' : 'HIT — NEXT TARGET')
                            : 'MISS — RE-ENGAGE!',
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

  @override
  Widget build(BuildContext context) {
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
          // Wind hold magnitude + direction (speed/clock shown on in-viewport clock)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WIND HOLD', style: _labelStyle),
                const SizedBox(height: 4),
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

class _ZoneHint extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ZoneHint({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.25,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Difficulty toggle bar
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

// ---------------------------------------------------------------------------
// Mini wind clock overlay
// ---------------------------------------------------------------------------

class _WindClock extends StatelessWidget {
  final RangeScenario scenario;
  const _WindClock({required this.scenario});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: _WindClockPainter(
              clockPosition: scenario.clockPosition,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${scenario.windSpeedMph.toInt()} MPH',
          style: GoogleFonts.robotoMono(
            color: Colors.white70,
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _WindClockPainter extends CustomPainter {
  final double clockPosition;
  const _WindClockPainter({required this.clockPosition});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 3;

    // Background
    canvas.drawCircle(
      Offset(cx, cy), r + 3,
      Paint()..color = const Color(0xBB0D1117),
    );

    // Ring
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = const Color(0xFF4A7C59)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Cardinal ticks
    final tickPaint = Paint()
      ..color = const Color(0xFF4A7C59)
      ..strokeWidth = 1.0;
    for (final h in [12.0, 3.0, 6.0, 9.0]) {
      final a = (h / 12.0) * 2 * pi - pi / 2;
      canvas.drawLine(
        Offset(cx + (r - 5) * cos(a), cy + (r - 5) * sin(a)),
        Offset(cx + r * cos(a), cy + r * sin(a)),
        tickPaint,
      );
    }

    // Wind arrow: FROM clock position TOWARD center.
    // Drawn from the ring edge inward, so it reads as "wind coming from here."
    final windAngle = (clockPosition / 12.0) * 2 * pi - pi / 2;
    final fromX = cx + r * 0.85 * cos(windAngle);
    final fromY = cy + r * 0.85 * sin(windAngle);
    // Arrow tip points toward center, stopping just past it
    final toX = cx + r * 0.18 * cos(windAngle + pi);
    final toY = cy + r * 0.18 * sin(windAngle + pi);

    final arrowPaint = Paint()
      ..color = Colors.white.withAlpha(220)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(fromX, fromY), Offset(toX, toY), arrowPaint);

    // Arrowhead
    final dir = atan2(toY - fromY, toX - fromX);
    const headLen = 5.0;
    const headSpread = 0.5;
    for (final side in [-1, 1]) {
      canvas.drawLine(
        Offset(toX, toY),
        Offset(toX - headLen * cos(dir - side * headSpread),
               toY - headLen * sin(dir - side * headSpread)),
        arrowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WindClockPainter old) => old.clockPosition != clockPosition;
}
