part of mapgen2;

class displayColors {
  // Features
  static const int OCEAN = 0xff44447a;
  static const int COAST = 0xff33335a;
  static const int LAKESHORE = 0xff225588;
  static const int LAKE = 0xff336699;
  static const int RIVER = 0xff225588;
  static const int MARSH = 0xff2f6666;
  static const int ICE = 0xff99ffff;
  static const int BEACH = 0xffa09077;
  static const int ROAD1 = 0xff442211;
  static const int ROAD2 = 0xff553322;
  static const int ROAD3 = 0xff664433;
  static const int BRIDGE = 0xff686860;
  static const int LAVA = 0xffcc3333;

  // Terrain
  static const int SNOW = 0xffffffff;
  static const int TUNDRA = 0xffbbbbaa;
  static const int BARE = 0xff888888;
  static const int SCORCHED = 0xff555555;
  static const int TAIGA = 0xff99aa77;
  static const int SHRUBLAND = 0xff889977;
  static const int TEMPERATE_DESERT = 0xffc9d29b;
  static const int TEMPERATE_RAIN_FOREST = 0xff448855;
  static const int TEMPERATE_DECIDUOUS_FOREST = 0xff679459;
  static const int GRASSLAND = 0xff88aa55;
  static const int SUBTROPICAL_DESERT = 0xffd2b98b;
  static const int TROPICAL_RAIN_FOREST = 0xff337755;
  static const int TROPICAL_SEASONAL_FOREST = 0xff559944;
}

List _displayColorList = [displayColors.OCEAN, displayColors.COAST, displayColors.LAKESHORE,
  displayColors.LAKE, displayColors.RIVER, displayColors.MARSH, displayColors.ICE, displayColors.BEACH,
  displayColors.ROAD1, displayColors.ROAD2, displayColors.ROAD3, displayColors.BRIDGE, displayColors.LAVA,
  displayColors.SNOW, displayColors.TUNDRA, displayColors.BARE, displayColors.SCORCHED, displayColors.TAIGA,
  displayColors.SHRUBLAND, displayColors.TEMPERATE_DESERT, displayColors.TEMPERATE_RAIN_FOREST,
  displayColors.GRASSLAND, displayColors.SUBTROPICAL_DESERT, displayColors.TROPICAL_RAIN_FOREST,
  displayColors.TROPICAL_SEASONAL_FOREST];


class elevationGradientColors {
  static const int OCEAN = 0xff008800;
  static const int GRADIENT_LOW = 0xff008800;
  static const int GRADIENT_HIGH = 0xffffff00;
}

Map _elevationGradientColors = {
  "GRADIENT_LOW": elevationGradientColors.GRADIENT_LOW, 
  "GRADIENT_HIGH": elevationGradientColors.GRADIENT_HIGH };

class moistureGradientColors {
  static const int OCEAN = 0xff4466ff;
  static const int GRADIENT_LOW = 0xffbbaa33;
  static const int GRADIENT_HIGH = 0xff4466ff;
}

Map _moistureGradientColors = {
  "GRADIENT_LOW": moistureGradientColors.GRADIENT_LOW, 
  "GRADIENT_HIGH": moistureGradientColors.GRADIENT_HIGH };
