// Annotateedge with a noisy path, to make maps look more interesting.
// Author: amitp@cs.stanford.edu
// License: MIT
part of mapgen2;


class NoisyEdges {
 static num NOISY_LINE_TRADEOFF = 0.5;  // low: jagged vedge; high: jagged dedge
 
 List path0 = [];  // edge index -> List<Point>
 List path1 = [];  // edge index -> List<Point>
 
 NoisyEdges() {
 }

 // Build noisy line paths forof the Voronoi edges. There are
 // two noisy line paths foredge,covering half the
 // distance: path0 is from v0 to the midpoint and path1 is from v1
 // to the midpoint. When drawing the polygons, one or the other
 // must be drawn in reverse order.
 buildNoisyEdges(WorldMap map, Lava lava, PM_PRNG random) {
   Center p;
   Edge edge;
   for(p in map.centers) {
       for(edge in p.borders) {
           if (edge.d0 != null && edge.d1 != null && edge.v0 != null && edge.v1 != null && path0[edge.index] == null) {
             num f = NOISY_LINE_TRADEOFF;
             Point t = Point.interpolate(edge.v0.point, edge.d0.point, f);
             Point q = Point.interpolate(edge.v0.point, edge.d1.point, f);
             Point r = Point.interpolate(edge.v1.point, edge.d0.point, f);
             Point s = Point.interpolate(edge.v1.point, edge.d1.point, f);

             int minLength = 10;
             if (edge.d0.biome != edge.d1.biome) minLength = 3;
             if (edge.d0.ocean && edge.d1.ocean) minLength = 100;
             if (edge.d0.coast || edge.d1.coast) minLength = 1;
             if (edge.river != null || lava.lava[edge.index] != null) minLength = 1;
             
             path0[edge.index] = buildNoisyLineSegments(random, edge.v0.point, t, edge.midpoint, q, minLength);
             path1[edge.index] = buildNoisyLineSegments(random, edge.v1.point, s, edge.midpoint, r, minLength);
           }
         }
     }
 }

 
 // Helper function: build a single noisy line in a quadrilateral A-B-C-D,
 // and store the output points in a Vector.
 static List<Point> buildNoisyLineSegments(PM_PRNG random, Point A, Point B, Point C, Point D, num minLength) {
   List<Point> points = new List<Point>();

   subdivide(Point A, Point B, Point C, Point D) {
     if (A.subtract(C).length < minLength || B.subtract(D).length < minLength) {
       return;
     }

     // Subdivide the quadrilateral
     num p = random.nextDoubleRange(0.2, 0.8);  // vertical (along A-D and B-C)
     num q = random.nextDoubleRange(0.2, 0.8);  // horizontal (along A-B and D-C)

     // Midpoints
     Point E = Point.interpolate(A, D, p);
     Point F = Point.interpolate(B, C, p);
     Point G = Point.interpolate(A, B, q);
     Point I = Point.interpolate(D, C, q);
     
     // Central point
     Point H = Point.interpolate(E, F, q);
     
     // Divide the quad into subquads, but meet at H
     num s = 1.0 - random.nextDoubleRange(-0.4, 0.4);
     num t = 1.0 - random.nextDoubleRange(-0.4, 0.4);

     subdivide(A, Point.interpolate(G, B, s), H, Point.interpolate(E, D, t));
     points.push(H);
     subdivide(H, Point.interpolate(F, C, s), C, Point.interpolate(I, D, t));
   }

   points.push(A);
   subdivide(A, B, C, D);
   points.push(C);
   return points;
 }
}

