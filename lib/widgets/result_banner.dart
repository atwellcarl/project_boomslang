import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ResultBanner extends StatelessWidget {
  final bool isCorrect;
  final VoidCallback onNext;
  final VoidCallback onReEngage;

  const ResultBanner({
    super.key,
    required this.isCorrect,
    required this.onNext,
    required this.onReEngage,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? const Color(0xFF4A7C59) : const Color(0xFF8B3A3A);
    final label = isCorrect ? 'CORRECT' : 'MISS — RE-ENGAGE!';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.robotoMono(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: isCorrect ? onNext : onReEngage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A3A4A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isCorrect ? 'NEXT' : 'RE-ENGAGE',
                style: GoogleFonts.robotoMono(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
