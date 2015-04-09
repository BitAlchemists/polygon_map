part of mapgen2;

  class Center {
    int index;
  
    Point point;  // location
    bool water;  // lake or ocean
    bool ocean;  // ocean
    bool coast;  // land polygon touching an ocean
    bool border;  // at the edge of the map
    Biome biome;  // biome type (see article)
    num elevation;  // 0.0-1.0
    num moisture;  // 0.0-1.0

    List<Center> neighbors;
    List<Edge> borders;
    List<Corner> corners;
    
    Center(){
      water = false;
      ocean = false;
      coast = false;
      border = false;
      elevation = 0.0;
      moisture = 0.0;
    }
    
    String toString() => point != null ? ("Center - x:${point.x.toInt().toString()} y:${point.y.toInt().toString()}")  : "Center - not initialized";
  }
