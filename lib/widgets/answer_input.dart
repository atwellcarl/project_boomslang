import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/reticle_type.dart';

class AnswerInput extends StatefulWidget {
  final double value;
  final bool isRight;
  final ReticleType reticleType;
  final ValueChanged<double> onValueChanged;
  final ValueChanged<bool> onDirectionChanged;
  final VoidCallback onSubmit;
  final bool submitted;

  const AnswerInput({
    super.key,
    required this.value,
    required this.isRight,
    required this.reticleType,
    required this.onValueChanged,
    required this.onDirectionChanged,
    required this.onSubmit,
    required this.submitted,
  });

  @override
  State<AnswerInput> createState() => _AnswerInputState();
}

class _AnswerInputState extends State<AnswerInput> {
  late FixedExtentScrollController _controller;
  bool _scrolling = false;

  late int _itemCount;

  int _toIndex(double value) {
    final step = widget.reticleType.drumStep;
    return (value / step).round().clamp(0, _itemCount - 1);
  }

  double _fromIndex(int index) {
    return index * widget.reticleType.drumStep;
  }

  @override
  void initState() {
    super.initState();
    _itemCount = (widget.reticleType.drumMax / widget.reticleType.drumStep).round() + 1;
    _controller = FixedExtentScrollController(
      initialItem: _toIndex(widget.value),
    );
  }

  @override
  void didUpdateWidget(AnswerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update item count if reticle type changes
    final newItemCount = (widget.reticleType.drumMax / widget.reticleType.drumStep).round() + 1;
    if (newItemCount != _itemCount) {
      _itemCount = newItemCount;
    }
    // Snap back to 0 when a new scenario starts
    if (widget.value != oldWidget.value) {
      final targetIndex = _toIndex(widget.value);
      if (_controller.hasClients &&
          _controller.selectedItem != targetIndex) {
        _controller.animateToItem(
          targetIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Value drum dial
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
                  NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollStartNotification && !_scrolling) {
                        setState(() => _scrolling = true);
                      } else if (n is ScrollEndNotification && _scrolling) {
                        setState(() => _scrolling = false);
                      }
                      return false;
                    },
                  child: ListWheelScrollView.useDelegate(
                    controller: _controller,
                    physics: widget.submitted
                        ? const NeverScrollableScrollPhysics()
                        : const FixedExtentScrollPhysics(),
                    itemExtent: 44,
                    perspective: 0.003,
                    diameterRatio: 2.5,
                    onSelectedItemChanged: (index) {
                      widget.onValueChanged(_fromIndex(index));
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: _itemCount,
                      builder: (context, index) {
                        final value = _fromIndex(index);
                        final isSelected = (_toIndex(widget.value) == index);
                        final decimalPlaces = widget.reticleType == ReticleType.moa ? 2 : 1;
                        return Center(
                          child: Text(
                            value.toStringAsFixed(decimalPlaces),
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
                  )),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.reticleType.label,
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
            onPressed: widget.submitted || _scrolling ? null : widget.onSubmit,
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
