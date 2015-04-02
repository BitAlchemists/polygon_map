part of mapgen2;

  class Corner {
    int index;
  
    Point point;  // location
    bool ocean;  // ocean
    bool water;  // lake or ocean
    bool coast;  // touches ocean and land polygons
    bool border;  // at the edge of the map
    num elevation;  // 0.0-1.0
    num moisture;  // 0.0-1.0

    List<Center> touches;
    List<Edge> protrudes;
    List<Corner> adjacent;
  
    int river;  // 0 if no river, or volume of water in river
    Corner downslope;  // pointer to adjacent corner most downhill
    Corner watershed;  // pointer to coastal corner, or null
    int watershed_size;
  }
