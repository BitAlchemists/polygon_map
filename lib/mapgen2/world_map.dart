part of mapgen2;


class WorldMap {
    /// 0 to 1, fraction of water corners for water polygon
    static num LAKE_THRESHOLD = 0.3;

    /// Passed in by the caller:
    num SIZE;

    /** Island shape is controlled by the islandRandom seed and the
    // type of island, passed in when we set the island shape. The
    // islandShape uses both of them to determine whether any
    // point should be water or land. **/
    Function islandShape;

    /** Island details are controlled by this random generator. The
    // initial map upon loading is always deterministic, but
    // subsequent maps reset this random number generator with a
    // random seed. **/
    PM_PRNG mapRandom = new PM_PRNG();
    
    /// see comment in pointSelector
    bool needsMoreRandomness; 

    /** Point selection is random for the original article, with Lloyd
    // Relaxation, but there are other ways of choosing points. Grids
    // in particular can be much simpler to start with, because you
    // don't need Voronoi at all. HOWEVER for ease of implementation,
    // I continue to use Voronoi here, to reuse the graph building
    // code. If you're using a grid, generate the graph directly. **/
    Function pointSelector;
    int numPoints;
    
    // These store the graph data
    List<Point> points;  // Only useful during map construction
    List<Center> centers;
    List<Corner> corners;
    List<Edge> edges;

    WorldMap(num size) {
      SIZE = size;
      numPoints = 1;
      reset();
    }
    
    // Random parameters governing the overall shape of the island
    newIsland(String islandSize, String pointType, int numPoints_, int seed, int variant) {
      islandShape = IslandShape.makePerlin(seed); //TODO: evaluate - make island shape based on selection
      pointSelector = PointSelector.generateRelaxed(SIZE, seed); //TODO: evaluate - make island shape based on selection
      needsMoreRandomness = PointSelector.needsMoreRandomness(pointType);
      numPoints = numPoints_;
      mapRandom.seed = variant;
    }

    
    reset() {
      Center p;
      Corner q;
      Edge edge;

      // Break cycles so the garbage collector will release data.
      if (points != null) {
        points.removeRange(0, points.length);
      }
      if (edges != null) {
        for(edge in edges) {
            edge.d0 = edge.d1 = null;
            edge.v0 = edge.v1 = null;
          }
        edges.removeRange(0, edges.length);
      }
      if (centers != null) {
        for(p in centers) {
            p.neighbors.removeRange(0, p.neighbors.length);
            p.corners.removeRange(0, p.corners.length);
            p.borders.removeRange(0, p.borders.length);
          }
        centers.removeRange(0, centers.length);
      }
      if (corners != null) {
        for(q in corners) {
            q.adjacent.removeRange(0, q.adjacent.length);
            q.touches.removeRange(0, q.touches.length);
            q.protrudes.removeRange(0, q.protrudes.length);
            q.downslope = null;
            q.watershed = null;
          }
        corners.removeRange(0, corners.length);
      }

      // Clear the previous graph data.
      if (points == null) points = new List<Point>();
      if (edges == null) edges = new List<Edge>();
      if (centers == null) centers = new List<Center>();
      if (corners == null) corners = new List<Corner>();
      
      //System.gc();
    }
      

    go(int first, int last) {
      List stages = [];

      timeIt(String name, Function fn) {
        //num t = getTimer();
        fn();
      }
      
      // Generate the initial random set of points
      stages.add
        (["Place points...",
          () {
            reset();
            points = pointSelector(numPoints);
          }]);

      // Create a graph structure from the Voronoi edge list. The
      // methods in the Voronoi object are somewhat inconvenient for
      // my needs, so I transform that data into the data I actually
      // need: edges connected to the Delaunay triangles and the
      // Voronoi polygons, a reverse map from those four points back
      // to the edge, a map from these four points to the points
      // they connect to (both along the edge and crosswise).
      stages.add
        ( ["Build graph...",
             () {
               delaunay.Voronoi voronoi = new delaunay.Voronoi(points, null, new Rectangle(0, 0, SIZE, SIZE));
               buildGraph(points, voronoi);
               improveCorners();
               voronoi = null;
               points = null;
          }]);

      stages.add
        (["Assign elevations...",
             () {
               // Determine the elevations and water at Voronoi corners.
               assignCornerElevations();

               // Determine polygon and corner type: ocean, coast, land.
               assignOceanCoastAndLand();

               // Rescale elevations so that the highest is 1.0, and they're
               // distributed well. We want lower elevations to be more common
               // than higher elevations, in proportions approximately matching
               // concentric rings. That is, the lowest elevation is the
               // largest ring around the island, and therefore should more
               // land area than the highest elevation, which is the very
               // center of a perfectly circular island.
               redistributeElevations(landCorners(corners));

               // Assign elevations to non-land corners
               for(Corner q in corners) {
                   if (q.ocean || q.coast) {
                     q.elevation = 0.0;
                   }
                 }
               
               // Polygon elevations are the average of their corners
               assignPolygonElevations();
          }]);
             

      stages.add
        (["Assign moisture...",
             () {
               // Determine downslope paths.
               calculateDownslopes();

               // Determine watersheds: for every corner, where does it flow
               // out into the ocean? 
               calculateWatersheds();

               // Create rivers.
               createRivers();

               // Determine moisture at corners, starting at rivers
               // and lakes, but not oceans. Then redistribute
               // moisture to cover the entire range evenly from 0.0
               // to 1.0. Then assign polygon moisture as the average
               // of the corner moisture.
               assignCornerMoisture();
               redistributeMoisture(landCorners(corners));
               assignPolygonMoisture();
             }]);

      stages.add
        (["Decorate map...",
             () {
               assignBiomes();
             }]);
      
      for (int i = first; i < last; i++) {
          timeIt(stages[i][0], stages[i][1]);
        }
    }

    
    // Although Lloyd relaxation improves the uniformity of polygon
    // sizes, it doesn't help with the edge lengths. Short edges can
    // be bad for some games, and lead to weird artifacts on
    // rivers. We can easily lengthen short edges by moving the
    // corners, but **we lose the Voronoi property**.  The corners are
    // moved to the average of the polygon centers around them. Short
    // edges become longer. Long edges tend to become shorter. The
    // polygons tend to be more uniform after this step.
    improveCorners() {
      List<Point> newCorners = new List<Point>(corners.length);
      Corner q;
      Center r;
      Point point;
      int i;
      Edge edge;

      // First we compute the average of the centers next tocorner.
      for(q in corners) {
          if (q.border) {
            newCorners[q.index] = q.point;
          } else {
            point = new Point(0.0, 0.0);
            for(r in q.touches) {
                point.x += r.point.x;
                point.y += r.point.y;
              }
            point.x /= q.touches.length;
            point.y /= q.touches.length;
            newCorners[q.index] = point;
          }
        }

      // Move the corners to the new locations.
      for (i = 0; i < corners.length; i++) {
        corners[i].point = newCorners[i];
      }

      // The edge midpoints were computed for the old corners and need
      // to be recomputed.
      for(edge in edges) {
          if (edge.v0 != null && edge.v1 != null) {
            edge.midpoint = Point.interpolate(edge.v0.point, edge.v1.point, 0.5);
          }
        }
    }

    
    // Create an array of corners that are on land only, for use by
    // algorithms that work only on land.  We return an array instead
    // of a vector because the redistribution algorithms want to sort
    // this array using Array.sortOn.
    List landCorners(List<Corner> corners) {
      Corner q;
      List locations = [];
      for(q in corners) {
          if (!q.ocean && !q.coast) {
            locations.add(q);
          }
        }
      return locations;
    }

    
    // Build graph data structure in 'edges', 'centers', 'corners',
    // based on information in the Voronoi results: point.neighbors
    // will be a list of neighboring points of the same type (corner
    // or center); point.edges will be a list of edges that include
    // that point. Each edge connects to four points: the Voronoi edge
    // edge.{v0,v1} and its dual Delaunay triangle edge edge.{d0,d1}.
    // For boundary polygons, the Delaunay edge will have one null
    // point, and the Voronoi edge may be null.
    buildGraph(List<Point> points, delaunay.Voronoi voronoi) {
      Center p;
      //Corner q;
      Point point;
      //Point other;
      List<delaunay.Edge> libedges = voronoi.edges;
      Map centerLookup = new Map();

      // Build Center objects forof the points, and a lookup map
      // to find those Center objects again as we build the graph
      for(point in points) {
          p = new Center();
          p.index = centers.length;
          p.point = point;
          p.neighbors = new  List<Center>();
          p.borders = new List<Edge>();
          p.corners = new List<Corner>();
          centers.add(p);
          centerLookup[point] = p;
        }
      
      // Workaround for Voronoi lib bug: we need to call region()
      // before Edges or neighboringSites are available
      for(p in centers) {
          voronoi.region(p.point);
        }
      
      // The Voronoi library generates multiple Point objects for
      // corners, and we need to canonicalize to one Corner object.
      // To make lookup fast, we keep an array of Points, bucketed by
      // x value, and then we only have to look at other Points in
      // nearby buckets. When we fail to find one, we'll create a new
      // Corner object.
      Map _cornerMap = {};
      Corner makeCorner(Point point) {
        Corner q;
        
        if (point == null) return null;

        int bucket;
        for (bucket = (point.x-1).toInt(); bucket <= (point.x+1); bucket++) {
          if(_cornerMap[bucket] == null) {
            continue;
          }
          
          for(q in _cornerMap[bucket]) {
              num x = point.x - q.point.x;
              num y = point.y - q.point.y;
              if (x*x + y*y < 1e-6) {
                return q;
              }
            }
        }
        bucket = point.x.toInt();
        if (_cornerMap[bucket] == null) _cornerMap[bucket] = [];
        q = new Corner();
        q.index = corners.length;
        corners.add(q);
        q.point = point;
        q.border = (point.x == 0 || point.x == SIZE
                    || point.y == 0 || point.y == SIZE);
        q.touches = new List<Center>();
        q.protrudes = new List<Edge>();
        q.adjacent = new List<Corner>();
        _cornerMap[bucket].add(q);
        return q;
      }

      // Helper s for the following for loop; ideally these
      // would be inlined
      addToCornerList(List<Corner> v, Corner x) {
        if (x != null && v.indexOf(x) < 0) { v.add(x); }
      }
      addToCenterList(List<Center> v, Center x) {
        if (x != null && v.indexOf(x) < 0) { v.add(x); }
      }
          
      for(delaunay.Edge libedge in libedges) {
        LineSegment dedge = libedge.delaunayLine();
        LineSegment vedge = libedge.voronoiEdge();

          // Fill the graph data. Make an Edge object corresponding to
          // the edge from the voronoi library.
          Edge edge = new Edge();
          edge.index = edges.length;
          edge.river = 0;
          edges.add(edge);
          // TODO: evaluate
          // edge.midpoint = vedge.p0 && vedge.p1 && Point.interpolate(vedge.p0, vedge.p1, 0.5);
          edge.midpoint = (vedge.p0 != null && vedge.p1 != null) ? Point.interpolate(vedge.p0, vedge.p1, 0.5) : null;

          // Edges point to corners. Edges point to centers. 
          edge.v0 = makeCorner(vedge.p0);
          edge.v1 = makeCorner(vedge.p1);
          edge.d0 = centerLookup[dedge.p0];
          edge.d1 = centerLookup[dedge.p1];

          // Centers point to edges. Corners point to edges.
          if (edge.d0 != null) { edge.d0.borders.add(edge); }
          if (edge.d1 != null) { edge.d1.borders.add(edge); }
          if (edge.v0 != null) { edge.v0.protrudes.add(edge); }
          if (edge.v1 != null) { edge.v1.protrudes.add(edge); }

          // Centers point to centers.
          if (edge.d0 != null && edge.d1 != null) {
            addToCenterList(edge.d0.neighbors, edge.d1);
            addToCenterList(edge.d1.neighbors, edge.d0);
          }

          // Corners point to corners
          if (edge.v0 != null && edge.v1 != null) {
            addToCornerList(edge.v0.adjacent, edge.v1);
            addToCornerList(edge.v1.adjacent, edge.v0);
          }

          // Centers point to corners
          if (edge.d0 != null) {
            addToCornerList(edge.d0.corners, edge.v0);
            addToCornerList(edge.d0.corners, edge.v1);
          }
          if (edge.d1 != null) {
            addToCornerList(edge.d1.corners, edge.v0);
            addToCornerList(edge.d1.corners, edge.v1);
          }

          // Corners point to centers
          if (edge.v0 != null) {
            addToCenterList(edge.v0.touches, edge.d0);
            addToCenterList(edge.v0.touches, edge.d1);
          }
          if (edge.v1 != null) {
            addToCenterList(edge.v1.touches, edge.d0);
            addToCenterList(edge.v1.touches, edge.d1);
          }
        }
    }


    // Determine elevations and water at Voronoi corners. By
    // construction, we have no local minima. This is important for
    // the downslope vectors later, which are used in the river
    // construction algorithm. Also by construction, inlets/bays
    // push low elevation areas inland, which means many rivers end
    // up flowing out through them. Also by construction, lakes
    // often end up on river paths because they don't raise the
    // elevation as much as other terrain does.
    assignCornerElevations() {
      Corner q;
      Corner s;
      List queue = [];
      
      for(q in corners) {
          q.water = !inside(q.point);
        }

      for(q in corners) {
          // The edges of the map are elevation 0
          if (q.border) {
            q.elevation = 0.0;
            queue.add(q);
          } else {
            q.elevation = double.INFINITY;
          }
        }
      // Traverse the graph and assign elevations topoint. As we
      // move away from the map border, increase the elevations. This
      // guarantees that rivers always have a way down to the coast by
      // going downhill (no local minima).
      while (queue.length > 0) {
        q = queue.removeAt(0);

        for(s in q.adjacent) {
            // Every step up is epsilon over water or 1 over land. The
            // number doesn't matter because we'll rescale the
            // elevations later.
            double newElevation = 0.01 + q.elevation;
            if (!q.water && !s.water) {
              newElevation += 1;
              if (needsMoreRandomness) {
                // HACK: the map looks nice because of randomness of
                // points, randomness of rivers, and randomness of
                // edges. Without random point selection, I needed to
                // inject some more randomness to make maps look
                // nicer. I'm doing it here, with elevations, but I
                // think there must be a better way. This hack is only
                // used with square/hexagon grids.
                newElevation += mapRandom.nextDouble();
              }
            }
            // If this point changed, we'll add it to the queue so
            // that we can process its neighbors too.
            if (newElevation < s.elevation) {
              s.elevation = newElevation;
              queue.add(s);
            }
          }
      }
    }

    
    // Change the overall distribution of elevations so that lower
    // elevations are more common than higher
    // elevations. Specifically, we want elevation X to have frequency
    // (1-X).  To do this we will sort the corners, then set each
    // corner to its desired elevation.
    redistributeElevations(List locations) {
      // SCALE_FACTOR increases the mountain area. At 1.0 the maximum
      // elevation barely shows up on the map, so we set it to 1.1.
      double SCALE_FACTOR = 1.1;
      int i;
      num y;
      num x;

      //TODO: evaluate
      locations.sort((Corner a, Corner b) => (a.elevation - b.elevation).toInt());      
      //locations.sortOn('elevation', Array.NUMERIC);
      for (i = 0; i < locations.length; i++) {
        // Let y(x) be the total area that we want at elevation <= x.
        // We want the higher elevations to occur less than lower
        // ones, and set the area to be y(x) = 1 - (1-x)^2.
        y = i/(locations.length-1);
        // Now we have to solve for x, given the known y.
        //  *  y = 1 - (1-x)^2
        //  *  y = 1 - (1 - 2x + x^2)
        //  *  y = 2x - x^2
        //  *  x^2 - 2x + y = 0
        // From this we can use the quadratic equation to get:
        x = Math.sqrt(SCALE_FACTOR) - Math.sqrt(SCALE_FACTOR*(1-y));
        if (x > 1.0) x = 1.0;  // TODO: does this break downslopes?
        locations[i].elevation = x;
      }
    }


    // Change the overall distribution of moisture to be evenly distributed.
    redistributeMoisture(List locations) {
      int i;
      //TODO:evaluate
      locations.sort((Corner a, Corner b) => (a.moisture - b.moisture).toInt());
      //locations.sortOn('moisture', Array.NUMERIC);
      for (i = 0; i < locations.length; i++) {
        locations[i].moisture = i/(locations.length-1);
      }
    }


    // Determine polygon and corner types: ocean, coast, land.
    assignOceanCoastAndLand() {
      // Compute polygon attributes 'ocean' and 'water' based on the
      // corner attributes. Count the water corners per
      // polygon. Oceans are all polygons connected to the edge of the
      // map. In the first pass, mark the edges of the map as ocean;
      // in the second pass, mark any water-containing polygon
      // connected an ocean as ocean.
      List queue = [];
      Center p;
      Corner q;
      Center r;
      int numWater;
      
      for(Center p in centers) {
          numWater = 0;
          for(Corner q in p.corners) {
              if (q.border) {
                p.border = true;
                p.ocean = true;
                q.water = true;
                queue.add(p);
              }
              if (q.water) {
                numWater += 1;
              }
            }
          p.water = (p.ocean || numWater >= p.corners.length * LAKE_THRESHOLD);
        }
      while (queue.length > 0) {
        p = queue.removeAt(0);
        for(r in p.neighbors) {
            if (r.water && !r.ocean) {
              r.ocean = true;
              queue.add(r);
            }
          }
      }
      
      int numOcean;
      int numLand;
      
      // Set the polygon attribute 'coast' based on its neighbors. If
      // it has at least one ocean and at least one land neighbor,
      // then this is a coastal polygon.
      for(p in centers) {
        numOcean = 0;
        numLand = 0;
          for(r in p.neighbors) {
              numOcean += r.ocean ? 1 : 0;
              numLand += r.water ? 0 : 1;
            }
          p.coast = (numOcean > 0) && (numLand > 0);
        }


      // Set the corner attributes based on the computed polygon
      // attributes. If all polygons connected to this corner are
      // ocean, then it's ocean; if all are land, then it's land;
      // otherwise it's coast.
      for(q in corners) {
          numOcean = 0;
          numLand = 0;
          for(p in q.touches) {
            numOcean += r.ocean ? 1 : 0;
            numLand += r.water ? 0 : 1;
            }
          q.ocean = (numOcean == q.touches.length);
          q.coast = (numOcean > 0) && (numLand > 0);
          q.water = q.border || ((numLand != q.touches.length) && !q.coast);
        }
    }
  

    // Polygon elevations are the average of the elevations of their corners.
    assignPolygonElevations() {
      Center p;
      Corner q;
      num sumElevation;
      for(p in centers) {
          sumElevation = 0.0;
          for(q in p.corners) {
              sumElevation += q.elevation;
            }
          p.elevation = sumElevation / p.corners.length;
        }
    }

    
    // Calculate downslope pointers.  At every point, we point to the
    // point downstream from it, or to itself.  This is used for
    // generating rivers and watersheds.
    calculateDownslopes() {
      Corner q;
      Corner s;
      Corner r;
      
      for(q in corners) {
          r = q;
          for(s in q.adjacent) {
              if (s.elevation <= r.elevation) {
                r = s;
              }
            }
          q.downslope = r;
        }
    }


    // Calculate the watershed of every land point. The watershed is
    // the last downstream land point in the downslope graph. TODO:
    // watersheds are currently calculated on corners, but it'd be
    // more useful to compute them on polygon centers so that every
    // polygon can be marked as being in one watershed.
    calculateWatersheds() {
      Corner q;
      Corner r;
      int i;
      bool changed;
      
      // Initially the watershed pointer points downslope one step.      
      for(q in corners) {
          q.watershed = q;
          if (!q.ocean && !q.coast) {
            q.watershed = q.downslope;
          }
        }
      // Follow the downslope pointers to the coast. Limit to 100
      // iterations although most of the time with numPoints==2000 it
      // only takes 20 iterations because most points are not far from
      // a coast.  TODO: can run faster by looking at
      // p.watershed.watershed instead of p.downslope.watershed.
      for (i = 0; i < 100; i++) {
        changed = false;
        for(q in corners) {
            if (!q.ocean && !q.coast && !q.watershed.coast) {
              r = q.downslope.watershed;
              if (!r.ocean) q.watershed = r;
              changed = true;
            }
          }
        if (!changed) break;
      }
      // How big iswatershed?
      for(q in corners) {
          r = q.watershed;
          r.watershed_size = 1 + (r.watershed_size != null ? r.watershed_size : 0);
        }
    }


    // Create rivers along edges. Pick a random corner point, then
    // move downslope. Mark the edges and corners as rivers.
    createRivers() {
      int i;
      Corner q;
      Edge edge;
      
      for (i = 0; i < SIZE/2; i++) {
        q = corners[mapRandom.nextIntRange(0, corners.length-1)];
        if (q.ocean || q.elevation < 0.3 || q.elevation > 0.9) continue;
        // Bias rivers to go west: if (q.downslope.x > q.x) continue;
        while (!q.coast) {
          if (q == q.downslope) {
            break;
          }
          edge = lookupEdgeFromCorner(q, q.downslope);
          edge.river = edge.river + 1;
          q.river = (q.river != null ? q.river : 0) + 1;
          q.downslope.river = (q.downslope.river != null ? q.downslope.river : 0) + 1;  // TODO: fix double count
          q = q.downslope;
        }
      }
    }


    // Calculate moisture. Freshwater sources spread moisture: rivers
    // and lakes (not oceans). Saltwater sources have moisture but do
    // not spread it (we set it at the end, after propagation).
    assignCornerMoisture() {
      Corner q;
      Corner r;
      num newMoisture;
      List queue = [];
      // Fresh water
      for(q in corners) {
          if ((q.water || q.river > 0) && !q.ocean) {
            q.moisture = q.river > 0? Math.min(3.0, (0.2 * q.river)) : 1.0;
            queue.add(q);
          } else {
            q.moisture = 0.0;
          }
        }
      while (queue.length > 0) {
        q = queue.removeAt(0);

        for(r in q.adjacent) {
            newMoisture = q.moisture * 0.9;
            if (newMoisture > r.moisture) {
              r.moisture = newMoisture;
              queue.add(r);
            }
          }
      }
      // Salt water
      for(q in corners) {
          if (q.ocean || q.coast) {
            q.moisture = 1.0;
          }
        }
    }


    // Polygon moisture is the average of the moisture at corners
    assignPolygonMoisture() {
      Center p;
      Corner q;
      num sumMoisture;
      for(p in centers) {
          sumMoisture = 0.0;
          for(q in p.corners) {
              if (q.moisture > 1.0) q.moisture = 1.0;
              sumMoisture += q.moisture;
            }
          p.moisture = sumMoisture / p.corners.length;
        }
    }


    // Assign a biome type topolygon. If it has
    // ocean/coast/water, then that's the biome; otherwise it depends
    // on low/high elevation and low/medium/high moisture. This is
    // roughly based on the Whittaker diagram but adapted to fit the
    // needs of the island map generator.
    static Biome getBiome(Center p) {
      if (p.ocean) {
        return Biome.OCEAN;
      } else if (p.water) {
        if (p.elevation < 0.1) return Biome.MARSH;
        if (p.elevation > 0.8) return Biome.ICE;
        return Biome.LAKE;
      } else if (p.coast) {
        return Biome.BEACH;
      } else if (p.elevation > 0.8) {
        if (p.moisture > 0.50) return Biome.SNOW;
        else if (p.moisture > 0.33) return Biome.TUNDRA;
        else if (p.moisture > 0.16) return Biome.BARE;
        else return Biome.SCORCHED;
      } else if (p.elevation > 0.6) {
        if (p.moisture > 0.66) return Biome.TAIGA;
        else if (p.moisture > 0.33) return Biome.SHRUBLAND;
        else return Biome.TEMPERATE_DESERT;
      } else if (p.elevation > 0.3) {
        if (p.moisture > 0.83) return Biome.TEMPERATE_RAIN_FOREST;
        else if (p.moisture > 0.50) return Biome.TEMPERATE_DECIDUOUS_FOREST;
        else if (p.moisture > 0.16) return Biome.GRASSLAND;
        else return Biome.TEMPERATE_DESERT;
      } else {
        if (p.moisture > 0.66) return Biome.TROPICAL_RAIN_FOREST;
        else if (p.moisture > 0.33) return Biome.TROPICAL_SEASONAL_FOREST;
        else if (p.moisture > 0.16) return Biome.GRASSLAND;
        else return Biome.SUBTROPICAL_DESERT;
      }
    }
    
    assignBiomes() {
      Center p;
      for(p in centers) {
          p.biome = getBiome(p);
        }
    }


    // Look up a Voronoi Edge object given two adjacent Voronoi
    // polygons, or two adjacent Voronoi corners
    Edge lookupEdgeFromCenter(Center p, Center r) {
      for(Edge edge in p.borders) {
          if (edge.d0 == r || edge.d1 == r) return edge;
        }
      return null;
    }

    Edge lookupEdgeFromCorner(Corner q, Corner s) {
      for(Edge edge in q.protrudes) {
          if (edge.v0 == s || edge.v1 == s) return edge;
        }
      return null;
    }

    
    // Determine whether a given point should be on the island or in the water.
    bool inside(Point p) {
      return islandShape(new Point(2*(p.x/SIZE - 0.5), 2*(p.y/SIZE - 0.5)));
    }
}




