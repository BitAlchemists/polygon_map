part of mapgen2;

  class Center {
    int index;
  
    Point point;  // location
    bool water;  // lake or ocean
    bool ocean;  // ocean
    bool coast;  // land polygon touching an ocean
    bool border;  // at the edge of the map
    String biome;  // biome type (see article)
    num elevation;  // 0.0-1.0
    num moisture;  // 0.0-1.0

    List<Center> neighbors;
    List<Edge> borders;
    List<Corner> corners;
  }
