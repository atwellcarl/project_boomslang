import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/ballistic_profiles.dart';
import '../models/ballistic_profile.dart';
import 'wind_trainer_screen.dart';
import 'range_screen.dart';
import 'milling_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedProfileIndex = 0;

  BallisticProfile get _selectedProfile => kBallisticProfiles[_selectedProfileIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // App title
              Text(
                'LRM',
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF4A7C59),
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
              Text(
                'TRAINER',
                style: GoogleFonts.robotoMono(
                  color: Colors.white54,
                  fontSize: 16,
                  letterSpacing: 8,
                ),
              ),

              const SizedBox(height: 48),

              // Load selector label
              Text(
                'SELECT LOAD',
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF8BA888),
                  fontSize: 11,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),

              // Profile cards — independent scroll so more loads can be added
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: SingleChildScrollView(
                  child: Column(
                    children: kBallisticProfiles.asMap().entries.map((entry) {
                      final i = entry.key;
                      final profile = entry.value;
                      final selected = i == _selectedProfileIndex;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedProfileIndex = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 18),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF1A2E1F)
                                  : const Color(0xFF151B22),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF4A7C59)
                                    : const Color(0xFF2A3A2A),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: selected
                                      ? const Color(0xFF4A7C59)
                                      : Colors.white24,
                                  size: 20,
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.name,
                                      style: GoogleFonts.robotoMono(
                                        color: selected
                                            ? Colors.white
                                            : Colors.white60,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${profile.tableDistances.first}–${profile.tableDistances.last}M  •  ${profile.tableWindSpeeds.map((s) => '${s.toInt()}mph').join('/')}',
                                      style: GoogleFonts.robotoMono(
                                        color: selected
                                            ? const Color(0xFF8BA888)
                                            : Colors.white24,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Training tools label
              Text(
                'TRAINING TOOLS',
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF8BA888),
                  fontSize: 11,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),

              // Wind Call
              _ToolCard(
                title: 'WIND CALL',
                subtitle: 'Read wind — enter MRAD holdover',
                icon: Icons.air,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WindTrainerScreen(profile: _selectedProfile),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Target Milling
              _ToolCard(
                title: 'TARGET MILLING',
                subtitle: 'Measure target — estimate range with reticle',
                icon: Icons.straighten,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MillingScreen(),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Range Engagement
              _ToolCard(
                title: 'RANGE ENGAGEMENT',
                subtitle: 'Drag reticle — apply elevation + wind hold',
                icon: Icons.my_location,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RangeScreen(profile: _selectedProfile),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF151B22),
          border: Border.all(color: const Color(0xFF2A3A2A), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF4A7C59), size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF4A7C59)),
          ],
        ),
      ),
    );
  }
}
