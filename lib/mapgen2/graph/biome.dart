part of mapgen2;

class Biome {
  static Biome OCEAN = new Biome(displayColors.OCEAN);
  static Biome MARSH = new Biome(displayColors.MARSH);
  static Biome ICE = new Biome(displayColors.ICE);
  static Biome LAKE = new Biome(displayColors.LAKE);
  static Biome BEACH = new Biome(displayColors.BEACH);
  static Biome SNOW = new Biome(displayColors.SNOW);
  static Biome TUNDRA = new Biome(displayColors.TUNDRA);
  static Biome BARE = new Biome(displayColors.BARE);
  static Biome SCORCHED = new Biome(displayColors.SCORCHED);
  static Biome TAIGA = new Biome(displayColors.TAIGA);
  static Biome SHRUBLAND = new Biome(displayColors.SHRUBLAND);
  static Biome TEMPERATE_DESERT = new Biome(displayColors.TEMPERATE_DESERT);
  static Biome TEMPERATE_RAIN_FOREST = new Biome(displayColors.TEMPERATE_RAIN_FOREST);
  static Biome TEMPERATE_DECIDUOUS_FOREST = new Biome(displayColors.TEMPERATE_DECIDUOUS_FOREST);
  static Biome GRASSLAND = new Biome(displayColors.GRASSLAND);
  static Biome TROPICAL_RAIN_FOREST = new Biome(displayColors.TROPICAL_RAIN_FOREST);
  static Biome TROPICAL_SEASONAL_FOREST = new Biome(displayColors.TROPICAL_SEASONAL_FOREST);
  static Biome SUBTROPICAL_DESERT = new Biome(displayColors.SUBTROPICAL_DESERT);
  
  Biome(this.color);
  int color; 
}