import 'dart:ui';
import '../models/range_target.dart';

// Hardcoded target set for the placeholder landscape.
// Vertical anchors are set low on screen to leave room above for elevation holds.
// At milToPx = vpHeight/35, max hold at 700M (.308) = 13.7 MIL = ~39% of viewport height.
// Recalibrate anchors when a real landscape photo is provided.
const List<RangeTarget> kRangeTargets = [
  RangeTarget(distanceMeters: 300, anchor: Offset(0.22, 0.72)),
  RangeTarget(distanceMeters: 500, anchor: Offset(0.55, 0.76)),
  RangeTarget(distanceMeters: 700, anchor: Offset(0.78, 0.80)),
];
