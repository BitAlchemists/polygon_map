part of mapgen2;

class Lava {
    static double FRACTION_LAVA_FISSURES = 0.2;  // 0 to 1, probability of fissure
    
    // The lava array marks the edges that hava lava.
    Map lava = {};  // edge index -> Boolean

    // Lava fissures are at high elevations where moisture is low
    createLava(WorldMap map, Function randomDouble) {
      Edge edge;
      for(edge in map.edges) {
          if (edge.river == null && !edge.d0.water && !edge.d1.water
              && edge.d0.elevation > 0.8 && edge.d1.elevation > 0.8
              && edge.d0.moisture < 0.3 && edge.d1.moisture < 0.3
              && randomDouble() < FRACTION_LAVA_FISSURES) {
            lava[edge.index] = true;
          }
        }
    }
  }