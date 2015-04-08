part of mapgen2;

class Biome {
  static Biome OCEAN = new Biome("OCEAN", displayColors.OCEAN);
  static Biome MARSH = new Biome("MARSH", displayColors.MARSH);
  static Biome ICE = new Biome("ICE", displayColors.ICE);
  static Biome LAKE = new Biome("LAKE", displayColors.LAKE);
  static Biome BEACH = new Biome("BEACH", displayColors.BEACH);
  static Biome SNOW = new Biome("SNOW", displayColors.SNOW);
  static Biome TUNDRA = new Biome("TUNDRA", displayColors.TUNDRA);
  static Biome BARE = new Biome("BARE", displayColors.BARE);
  static Biome SCORCHED = new Biome("SCORCHED", displayColors.SCORCHED);
  static Biome TAIGA = new Biome("TAIGA", displayColors.TAIGA);
  static Biome SHRUBLAND = new Biome("SHRUBLAND", displayColors.SHRUBLAND);
  static Biome TEMPERATE_DESERT = new Biome("TEMPERATE_DESERT", displayColors.TEMPERATE_DESERT);
  static Biome TEMPERATE_RAIN_FOREST = new Biome("TEMPERATE_RAIN_FOREST", displayColors.TEMPERATE_RAIN_FOREST);
  static Biome TEMPERATE_DECIDUOUS_FOREST = new Biome("TEMPERATE_DECIDUOUS_FOREST", displayColors.TEMPERATE_DECIDUOUS_FOREST);
  static Biome GRASSLAND = new Biome("GRASSLAND", displayColors.GRASSLAND);
  static Biome TROPICAL_RAIN_FOREST = new Biome("TROPICAL_RAIN_FOREST", displayColors.TROPICAL_RAIN_FOREST);
  static Biome TROPICAL_SEASONAL_FOREST = new Biome("TROPICAL_SEASONAL_FOREST", displayColors.TROPICAL_SEASONAL_FOREST);
  static Biome SUBTROPICAL_DESERT = new Biome("SUBTROPICAL_DESERT", displayColors.SUBTROPICAL_DESERT);
  
  Biome(this.name, this.color);
  int color;
  String name;
  
  String toString() => name;
}