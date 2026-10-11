import 'package:flutter/material.dart';

/// All map tile settings live here (used by the main map and the picker).
class MapConfig {
  static const String tileKey = 'cb1_4fpu_1_14c8181e7149081530d72060';

  /// Dark map (what the design needs).
  static const String darkTileUrl =
      'https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}{r}.png?key=$tileKey';

  /// Light map (Voyager) - only used by the fallback below.
  static const String lightTileUrl =
      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=$tileKey';

  /// FALLBACK: if the dark tiles ever show up blank/grey, change this to true.
  /// It loads the light map and inverts its colours into a dark map.
  static const bool invertLightTiles = false;

  static String get tileUrl => invertLightTiles ? lightTileUrl : darkTileUrl;

  /// Turns each light tile into a dark one (only used when invertLightTiles).
  static Widget invertBuilder(BuildContext context, Widget tile, Object? info) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -0.85, 0, 0, 0, 232, //
        0, -0.85, 0, 0, 232, //
        0, 0, -0.85, 0, 240, //
        0, 0, 0, 1, 0,
      ]),
      child: tile,
    );
  }
}
