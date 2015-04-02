part of mapgen2;

// Factory class to choose points for the graph
//import flash.geom.Point;
//import flash.geom.Rectangle;
//import com.nodename.Delaunay.Voronoi;
//import de.polygonal.math.PM_PRNG;
class PointSelector {
  static int NUM_LLOYD_RELAXATIONS = 2;

  // The square and hex grid point selection remove randomness from
  // where the points are; we need to inject more randomness elsewhere
  // to make the maps look better. I do this in the corner
  // elevations. However I think more experimentation is needed.
  static bool needsMoreRandomness(String type) {
    return type == 'Square' || type == 'Hexagon';
  }

  
  // Generate points at random locations
  static Function generateRandom(int size, int seed){
    return (int numPoints) {
      PM_PRNG mapRandom = new PM_PRNG();
      mapRandom.seed = seed;
      Point p;
      int i;
      List<Point> points = new List<Point>();
      for (i = 0; i < numPoints; i++) {
        p = new Point(mapRandom.nextDoubleRange(10, size-10),
                      mapRandom.nextDoubleRange(10, size-10));
        points.add(p);
      }
      return points;
    };
  }


  // Improve the random set of points with Lloyd Relaxation
  static Function generateRelaxed(int size, int seed){
    return (int numPoints) {
      // We'd really like to generate "blue noise". Algorithms:
      // 1. Poisson dart throwing: checknew point against all
      //     existing points, and reject it if it's too close.
      // 2. Start with a hexagonal grid and randomly perturb points.
      // 3. Lloyd Relaxation: movepoint to the centroid of the
      //     generated Voronoi polygon, then generate Voronoi again.
      // 4. Use force-based layout algorithms to push points away.
      // 5. More at http://www.cs.virginia.edu/~gfx/pubs/antimony/
      // Option 3 is implemented here. If it's run for too many iterations,
      // it will turn into a grid, but convergence is very slow, and we only
      // run it a few times.
      int i;
      Point p;
      Point q;
      delaunay.Voronoi voronoi;
      List<Point> region;
      List<Point> points = generateRandom(size, seed)(numPoints);
      for (i = 0; i < NUM_LLOYD_RELAXATIONS; i++) {
        voronoi = new delaunay.Voronoi(points, null, new Rectangle(0, 0, size, size));
        for(p in points) {
            region = voronoi.region(p);
            p.x = 0.0;
            p.y = 0.0;
            for(q in region) {
                p.x += q.x;
                p.y += q.y;
              }
            p.x /= region.length;
            p.y /= region.length;
            region.removeRange(0, region.length);
          }
        voronoi.dispose();
      }
      return points;
    };
  }
    
  
  // Generate points on a square grid
  static Function generateSquare(int size, int seed){
    return (int numPoints) {
      List<Point> points = new List<Point>();
      double N = Math.sqrt(numPoints);
      for (int x = 0; x < N; x++) {
        for (int y = 0; y < N; y++) {
          points.add(new Point((0.5 + x)/N * size, (0.5 + y)/N * size));
        }
      }
      return points;
    };
  }

  
  // Generate points on a square grid
  static Function generateHexagon(int size, int seed){
    return (int numPoints) {
      List<Point> points = new List<Point>();
      double N = Math.sqrt(numPoints);
      for (int x = 0; x < N; x++) {
        for (int y = 0; y < N; y++) {
          points.add(new Point((0.5 + x)/N * size, (0.25 + 0.5*x%2 + y)/N * size));
        }
      }
      return points;
    };
  }
}