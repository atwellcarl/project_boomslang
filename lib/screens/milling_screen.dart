import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/milling_scenario.dart';
import '../services/milling_scenario_generator.dart';
import '../widgets/milling_viewport.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _MillingState {
  final MillingScenario scenario;
  final bool submitted;

  const _MillingState({required this.scenario, this.submitted = false});

  _MillingState copyWith({MillingScenario? scenario, bool? submitted}) =>
      _MillingState(
        scenario: scenario ?? this.scenario,
        submitted: submitted ?? this.submitted,
      );
}

class _MillingNotifier extends StateNotifier<_MillingState> {
  _MillingNotifier()
      : super(_MillingState(scenario: MillingScenarioGenerator.generate()));

  void submit() => state = state.copyWith(submitted: true);
  void reEngage() => state = state.copyWith(submitted: false);
  void nextScenario() =>
      state = _MillingState(scenario: MillingScenarioGenerator.generate());
}

final _millingProvider =
    StateNotifierProvider<_MillingNotifier, _MillingState>(
  (ref) => _MillingNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MillingScreen extends ConsumerStatefulWidget {
  const MillingScreen({super.key});

  @override
  ConsumerState<MillingScreen> createState() => _MillingScreenState();
}

class _MillingScreenState extends ConsumerState<MillingScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  late AnimationController _bannerController;
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();

  Offset _reticleOffset = Offset.zero;
  Offset _sceneOffset = Offset.zero;
  bool _reticleInitialized = false;
  double _baseMilToPx = 20.0;
  double _zoom = 1.0;
  Size _vpSize = Size.zero;
  bool _isPanningScene = false;
  double _zoomAtGestureStart = 1.0;

  // Shooter preference: true = measure height (40"), false = width (19.5")
  bool _useHeight = true;

  bool _isCorrect = false;
  bool _bannerShowing = false;
  String _bannerMessage = '';

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
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _initReticle(Size viewportSize) {
    _vpSize = viewportSize;
    if (!_reticleInitialized) {
      _baseMilToPx = viewportSize.height / 35.0;
      _reticleOffset = Offset(viewportSize.width / 2, viewportSize.height / 2);
      _sceneOffset = Offset.zero;
      _reticleInitialized = true;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _zoom;
    _isPanningScene = details.localFocalPoint.dx < _vpSize.width / 2;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size viewportSize) {
    if (_bannerShowing) return;
    setState(() {
      if (details.pointerCount >= 2) {
        _zoom = (_zoomAtGestureStart * details.scale).clamp(1.0, 6.0);
      } else if (_isPanningScene) {
        _sceneOffset = Offset(
          _sceneOffset.dx + details.focalPointDelta.dx,
          _sceneOffset.dy + details.focalPointDelta.dy,
        );
      } else {
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

  bool _checkAnswer(MillingScenario scenario) {
    final input = int.tryParse(_inputController.text.trim());
    if (input == null) return false;
    return (input - scenario.trueDistanceMeters).abs() <= 25;
  }

  void _handleSubmit(MillingScenario scenario, _MillingNotifier notifier) {
    if (_inputController.text.trim().isEmpty) return;
    final isHit = _checkAnswer(scenario);
    _player.play(AssetSource(isHit ? 'sounds/hit.wav' : 'sounds/miss.wav'));
    notifier.submit();
    _showBanner(isHit, notifier, scenario.trueDistanceMeters);
  }

  Future<void> _showBanner(
      bool isCorrect, _MillingNotifier notifier, int trueDistM) async {
    if (_bannerShowing) return;
    _bannerShowing = true;
    _inputFocusNode.unfocus();
    setState(() {
      _isCorrect = isCorrect;
      _bannerMessage = isCorrect
          ? 'HIT — ${trueDistM}M'
          : 'MISS — TRUE: ${trueDistM}M';
    });

    if (isCorrect) {
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
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(_millingProvider.notifier);
    final state = ref.watch(_millingProvider);
    final scenario = state.scenario;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8BA888)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'TARGET MILLING',
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
            final vpHeight = constraints.maxHeight - 80 - 58 - 36;
            final vpSize = Size(constraints.maxWidth, vpHeight);
            _initReticle(vpSize);

            return Stack(
              children: [
                Column(
                  children: [
                    // ---- Milling viewport ----
                    SizedBox(
                      width: constraints.maxWidth,
                      height: vpHeight,
                      child: Stack(
                        children: [
                          MillingViewport(
                            scenario: scenario,
                            reticleOffset: _reticleOffset,
                            sceneOffset: _sceneOffset,
                            baseMilToPx: _baseMilToPx,
                            zoom: _zoom,
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: (d) => _onScaleUpdate(d, vpSize),
                          ),

                          const Positioned(
                            left: 10,
                            bottom: 10,
                            child: _ZoneHint(
                                icon: Icons.open_with, label: 'ORIENT'),
                          ),

                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const _ZoneHint(
                                    icon: Icons.gps_fixed, label: 'AIM'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _ZoomButton(
                                        icon: Icons.remove,
                                        onTap: () => _adjustZoom(-0.25)),
                                    const SizedBox(width: 4),
                                    _ZoomButton(
                                        icon: Icons.add,
                                        onTap: () => _adjustZoom(0.25)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ---- Info strip ----
                    _InfoStrip(
                      useHeight: _useHeight,
                      onToggle: () =>
                          setState(() => _useHeight = !_useHeight),
                    ),

                    const SizedBox(height: 8),

                    // ---- Range input row ----
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              focusNode: _inputFocusNode,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              enabled: !state.submitted,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: 'RANGE (M)',
                                hintStyle: GoogleFonts.robotoMono(
                                  color: Colors.white24,
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF151B22),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2A3A2A)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2A3A2A)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF4A7C59), width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                              onSubmitted: (_) {
                                if (!state.submitted) {
                                  _handleSubmit(scenario, notifier);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: state.submitted
                                  ? null
                                  : () => _handleSubmit(scenario, notifier),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A7C59),
                                disabledBackgroundColor:
                                    const Color(0xFF2A3A2A),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'SUBMIT',
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 24),
                      color: _isCorrect
                          ? const Color(0xFF4A7C59).withAlpha(230)
                          : const Color(0xFF8B3A3A).withAlpha(230),
                      child: Text(
                        _bannerMessage,
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
// Info strip
// ---------------------------------------------------------------------------

class _InfoStrip extends StatelessWidget {
  final bool useHeight;
  final VoidCallback onToggle;

  const _InfoStrip({required this.useHeight, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final dimLabel = useHeight ? 'HEIGHT  40"' : 'WIDTH  19.5"';

    return Container(
      height: 80,
      color: const Color(0xFF151B22),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Dimension toggle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MEASURE', style: _labelStyle),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2E1F),
                      border:
                          Border.all(color: const Color(0xFF4A7C59), width: 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(dimLabel, style: _valueStyle),
                  ),
                ),
              ],
            ),
          ),

          // Hidden distance
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('TARGET', style: _labelStyle),
                const SizedBox(height: 4),
                Text(
                  '??? M',
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFE8C84A),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),

          // Spacer to balance the measure toggle on the left
          const Expanded(child: SizedBox(),
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
// Shared small widgets
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
