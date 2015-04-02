part of mapgen2;
  
  class Edge {
    int index;
    Center d0;
    Center d1;  // Delaunay edge
    Corner v0;
    Corner v1;  // Voronoi edge
    Point midpoint;  // halfway between v0,v1
    int river;  // volume of water, or 0
  }
