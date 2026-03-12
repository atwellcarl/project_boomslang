import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnswerInput extends StatefulWidget {
  final double milValue;
  final bool isRight;
  final ValueChanged<double> onMilChanged;
  final ValueChanged<bool> onDirectionChanged;
  final VoidCallback onSubmit;
  final bool submitted;

  const AnswerInput({
    super.key,
    required this.milValue,
    required this.isRight,
    required this.onMilChanged,
    required this.onDirectionChanged,
    required this.onSubmit,
    required this.submitted,
  });

  @override
  State<AnswerInput> createState() => _AnswerInputState();
}

class _AnswerInputState extends State<AnswerInput> {
  late FixedExtentScrollController _milController;

  static const int _itemCount = 51; // 0.0 to 5.0 in 0.1 steps

  int _milToIndex(double mil) => (mil / 0.1).round().clamp(0, _itemCount - 1);
  double _indexToMil(int index) => index * 0.1;

  @override
  void initState() {
    super.initState();
    _milController = FixedExtentScrollController(
      initialItem: _milToIndex(widget.milValue),
    );
  }

  @override
  void didUpdateWidget(AnswerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Snap back to 0 when a new scenario starts
    if (widget.milValue != oldWidget.milValue) {
      final targetIndex = _milToIndex(widget.milValue);
      if (_milController.hasClients &&
          _milController.selectedItem != targetIndex) {
        _milController.animateToItem(
          targetIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _milController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // MIL drum dial
        Column(
          children: [
            SizedBox(
              width: 140,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center selection highlight
                  Container(
                    height: 44,
                    decoration: const BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: Color(0xFF4A7C59), width: 1.5),
                      ),
                    ),
                  ),
                  // Drum wheel
                  ListWheelScrollView.useDelegate(
                    controller: _milController,
                    physics: widget.submitted
                        ? const NeverScrollableScrollPhysics()
                        : const FixedExtentScrollPhysics(),
                    itemExtent: 44,
                    perspective: 0.003,
                    diameterRatio: 2.5,
                    onSelectedItemChanged: (index) {
                      widget.onMilChanged(_indexToMil(index));
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: _itemCount,
                      builder: (context, index) {
                        final value = _indexToMil(index);
                        final isSelected =
                            (_milToIndex(widget.milValue) == index);
                        return Center(
                          child: Text(
                            value.toStringAsFixed(1),
                            style: GoogleFonts.robotoMono(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white24,
                              fontSize: isSelected ? 28 : 20,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'MIL',
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF4A7C59),
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Direction toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DirectionButton(
              label: 'LEFT',
              selected: !widget.isRight,
              onTap: widget.submitted ? null : () => widget.onDirectionChanged(false),
            ),
            const SizedBox(width: 12),
            _DirectionButton(
              label: 'RIGHT',
              selected: widget.isRight,
              onTap: widget.submitted ? null : () => widget.onDirectionChanged(true),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Submit button
        SizedBox(
          width: 200,
          child: ElevatedButton(
            onPressed: widget.submitted ? null : widget.onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A7C59),
              disabledBackgroundColor: const Color(0xFF2A3A2A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      ],
    );
  }
}

class _DirectionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _DirectionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4A7C59) : const Color(0xFF1A2A1A),
          border: Border.all(
            color: selected ? const Color(0xFF4A7C59) : const Color(0xFF3A4A3A),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoMono(
            color: selected ? Colors.white : Colors.white38,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
