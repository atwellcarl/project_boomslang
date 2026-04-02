import 'dart:ui';
import '../models/range_target.dart';

// Anchors derived from user-marked dots on range_landscape.jpg (2560x1440).
// Dot pixel coords: 700M=(1129,819), 300M=(1575,918), 500M interpolated.
// ny = dot_iy/1440; anchor_y = ny - body_height/2 so base lands on dot.
// nx = 0.5 + vpAspect*(ix-1280)/1440; vpAspect=1324/1179 (measured from screenshot).
const List<RangeTarget> kRangeTargets = [
  RangeTarget(distanceMeters: 300, anchor: Offset(0.730, 0.600)),
  RangeTarget(distanceMeters: 500, anchor: Offset(0.521, 0.573)),
  RangeTarget(distanceMeters: 700, anchor: Offset(0.382, 0.553)),
];
