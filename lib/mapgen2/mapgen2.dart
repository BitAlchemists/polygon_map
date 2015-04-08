library mapgen2;

import "dart:core";
import "dart:math" as Math;
import 'package:stagexl/stagexl.dart';
import "../delaunay/delaunay.dart" as delaunay;
import "../PM_PRNG/PM_PRNG.dart";
import "../stagexl_plus/stagexl_plus.dart" as stagexl_plus;
import "package:vector_math/vector_math.dart";
import "package:polygon_map/geom/geom.dart";

part "world_map.dart";
part "island_shape.dart";
part "point_selector.dart";
part "roads.dart";
part "lava.dart";
part "watersheds.dart";
part "noisy_edges.dart";
part "helpers.dart";
part "graph/corner.dart";
part "graph/edge.dart";
part "graph/center.dart";
part "graph/biome.dart";


class displayColors {
  // Features
  static const int OCEAN = 0xff44447a;
  static const int COAST = 0xff33335a;
  static const int LAKESHORE = 0xff225588;
  static const int LAKE = 0xff336699;
  static const int RIVER = 0xff225588;
  static const int MARSH = 0xff2f6666;
  static const int ICE = 0xff99ffff;
  static const int BEACH = 0xffa09077;
  static const int ROAD1 = 0xff442211;
  static const int ROAD2 = 0xff553322;
  static const int ROAD3 = 0xff664433;
  static const int BRIDGE = 0xff686860;
  static const int LAVA = 0xffcc3333;

  // Terrain
  static const int SNOW = 0xffffffff;
  static const int TUNDRA = 0xffbbbbaa;
  static const int BARE = 0xff888888;
  static const int SCORCHED = 0xff555555;
  static const int TAIGA = 0xff99aa77;
  static const int SHRUBLAND = 0xff889977;
  static const int TEMPERATE_DESERT = 0xffc9d29b;
  static const int TEMPERATE_RAIN_FOREST = 0xff448855;
  static const int TEMPERATE_DECIDUOUS_FOREST = 0xff679459;
  static const int GRASSLAND = 0xff88aa55;
  static const int SUBTROPICAL_DESERT = 0xffd2b98b;
  static const int TROPICAL_RAIN_FOREST = 0xff337755;
  static const int TROPICAL_SEASONAL_FOREST = 0xff559944;
}

List _displayColorList = [displayColors.OCEAN, displayColors.COAST, displayColors.LAKESHORE,
  displayColors.LAKE, displayColors.RIVER, displayColors.MARSH, displayColors.ICE, displayColors.BEACH,
  displayColors.ROAD1, displayColors.ROAD2, displayColors.ROAD3, displayColors.BRIDGE, displayColors.LAVA,
  displayColors.SNOW, displayColors.TUNDRA, displayColors.BARE, displayColors.SCORCHED, displayColors.TAIGA,
  displayColors.SHRUBLAND, displayColors.TEMPERATE_DESERT, displayColors.TEMPERATE_RAIN_FOREST,
  displayColors.GRASSLAND, displayColors.SUBTROPICAL_DESERT, displayColors.TROPICAL_RAIN_FOREST,
  displayColors.TROPICAL_SEASONAL_FOREST];


class elevationGradientColors {
  static const int OCEAN = 0xff008800;
  static const int GRADIENT_LOW = 0xff008800;
  static const int GRADIENT_HIGH = 0xffffff00;
}

List _elevationGradientColors = [elevationGradientColors.OCEAN, elevationGradientColors.GRADIENT_LOW, elevationGradientColors.GRADIENT_HIGH];

class moistureGradientColors {
  static const int OCEAN = 0xff4466ff;
  static const int GRADIENT_LOW = 0xffbbaa33;
  static const int GRADIENT_HIGH = 0xff4466ff;
}

List _moistureGradientColors = [moistureGradientColors.OCEAN, moistureGradientColors.GRADIENT_LOW, moistureGradientColors.GRADIENT_HIGH];

addVectorToPoint(Vector V, Point P){
  return new Point(V.x + P.x, V.y + P.y);
}

class mapgen2 extends Sprite {
  static int SIZE = 600;

 
  // Island shape is controlled by the islandRandom seed and the
  // type of island. The islandShape uses both of them to
  // determine whether any point should be water or land.
  String islandType = 'Perlin';
  static String islandSeedInitial = "85882-8";
  //static String islandSeedInitial = "133-7";

  // Point distribution
  String pointType = 'Relaxed';
  int numPoints = 2000;
  
  // GUI for controlling the map generation and view
  Sprite controls = new Sprite();
  TextField islandSeedInput;
  TextField statusBar;

  // This is the current map style. UI buttons change this, and it
  // persists when you make a new map.
  String mapMode = 'smooth';
  Bitmap noiseLayer = new Bitmap(new BitmapData(SIZE, SIZE));
  
  /*
  // These store 3d rendering data
  num rotationAnimation = 0.0;
  List triangles3d = [];
  List<IGraphicsData> graphicsData;
  */
  
  // The map data
  WorldMap map;
  Roads roads;
  Lava lava;
  Watersheds watersheds;
  NoisyEdges noisyEdges;


  mapgen2() {
    addChild(noiseLayer);
    stagexl_plus.noise(noiseLayer.bitmapData, 555, 128-10, 128+10, 7, true);
    
    //TODO: it seems this feature is not supported in StageXL and propably never will due to the limitations of the HTML Canvas
    //noiseLayer.blendMode = BlendMode.HARDLIGHT;

    controls.x = SIZE;
    addChild(controls);

    addExportButtons();
    addViewButtons();
    addIslandShapeButtons();
    addPointSelectionButtons();
    addMiscLabels();

    map = new WorldMap(SIZE);
  }

  
  // Random parameters governing the overall shape of the island
  void newIsland(String newIslandType, String newPointType, int newNumPoints) {
    int seed = 0;
    int variant = 0;
    
    if (islandSeedInput.text.length == 0) {
      islandSeedInput.text = (new Math.Random().nextDouble()*100000).toStringAsFixed(0);
    }
    
    RegExp exp = new RegExp(r"\s*(\d+)(?:\-(\d+))\s*$");
    Match match = exp.firstMatch(islandSeedInput.text);
    if (match != null) {
      // It's of the format SHAPE-VARIANT
      seed = int.parse(match.group(1));
      variant = int.parse(match.groupCount >= 2 ? match.group(2) : "0");
    }
    //TODO: check if this works as intended
    if (seed == 0) {
      // Convert the string into a number. This is a cheesy way to
      // do it but it doesn't matter. It just allows people to use
      // words as seeds.
      for (int i = 0; i < islandSeedInput.text.length; i++) {
        seed = (seed << 4) | islandSeedInput.text.codeUnitAt(i);
      }
      seed %= 100000;
      variant = 1+(9*new Math.Random().nextDouble()).toInt();
    }
    islandType = newIslandType;
    pointType = newPointType;
    numPoints = newNumPoints;
    map.newIsland(islandType, pointType, numPoints, seed, variant);
  }

  
  void graphicsReset() {
    graphics.clear();
    graphics.rect(0, 0, SIZE, SIZE);
    graphics.fillColor(displayColors.OCEAN);
  }

  
  go(String newIslandType, String newPointType, int newNumPoints) {
    cancelCommands();

    roads = new Roads();
    lava = new Lava();
    watersheds = new Watersheds();
    noisyEdges = new NoisyEdges();
    
    commandExecute("Shaping map...",
                   () {
                     newIsland(newIslandType, newPointType, newNumPoints);
                   });
    
    commandExecute("Placing points...",
                   () {
                     map.go(0, 1);
                     drawMap('polygons');
                   });

    commandExecute("Building graph...",
                   () {
                     map.go(1, 2);
                     map.assignBiomes();
                     drawMap('polygons');
                   });
    
    commandExecute("Features...",
                   () {
                     map.go(2, 5);
                     map.assignBiomes();
                     drawMap('polygons');
                   });
/*
    commandExecute("Edges...",
                   () {
                     roads.createRoads(map);
                     // lava.createLava(map, map.mapRandom.nextDouble);
                     watersheds.createWatersheds(map);
                     noisyEdges.buildNoisyEdges(map, lava, map.mapRandom);
                     drawMap(mapMode);
                   });

  */
    }


  // Command queue is processed on ENTER_FRAME. If it's empty,
  // remove the handler.
  List _guiQueue = [];
  _onEnterFrame(Event e) { 
    (_guiQueue.removeAt(0)[1])();
    if (_guiQueue.length == 0) {
      stage.removeEventListener(Event.ENTER_FRAME, _onEnterFrame);
      statusBar.text = "";
    } else {
      statusBar.text = _guiQueue[0][0];
    }
  }

  cancelCommands() {
    if (_guiQueue.length != 0) {
      stage.removeEventListener(Event.ENTER_FRAME, _onEnterFrame);
      statusBar.text = "";
      _guiQueue = [];
    }
  }

  commandExecute(String status, command) {
    if (_guiQueue.length == 0) {
      statusBar.text = status;
      stage.addEventListener(Event.ENTER_FRAME, _onEnterFrame);
    }
    _guiQueue.add([status, command]);
  }

  
  // Show some information about the maps
  static List _biomeList =
    [ displayColors.BEACH, displayColors.LAKE, displayColors.ICE, displayColors.MARSH, displayColors.SNOW, displayColors.TUNDRA, displayColors.BARE, displayColors.SCORCHED,
    displayColors.TAIGA, displayColors.SHRUBLAND, displayColors.TEMPERATE_DESERT, displayColors.TEMPERATE_RAIN_FOREST,
    displayColors.TEMPERATE_DECIDUOUS_FOREST, displayColors.GRASSLAND, displayColors.SUBTROPICAL_DESERT,
    displayColors.TROPICAL_RAIN_FOREST, displayColors.TROPICAL_SEASONAL_FOREST];
  drawHistograms() {
    print("drawHistograms()");
    // There are pairs ofs forchart. The bucket
    // maps the polygon Center to a small int, and the
    // color maps the int to a color.
    int landTypeBucket(Center p) {
      if (p.ocean) return 1;
      else if (p.coast) return 2;
      else if (p.water) return 3;
      else return 4;
    }
    int landTypeColor(int bucket) {
      if (bucket == 1) return displayColors.OCEAN;
      else if (bucket == 2) return displayColors.BEACH;
      else if (bucket == 3) return displayColors.LAKE;
      else return displayColors.TEMPERATE_DECIDUOUS_FOREST;
    }
    int elevationBucket(Center p) {
      if (p.ocean) return -1;
      else return (p.elevation*10).floor();
    }
    int elevationColor(int bucket) {
      return interpolateColor(displayColors.TEMPERATE_DECIDUOUS_FOREST,
                              displayColors.GRASSLAND, bucket*0.1);
    }
    int moistureBucket(Center p) {
      if (p.water) return -1;
      else return (p.moisture*10).floor();
    }
    int moistureColor(int bucket) {
      return interpolateColor(displayColors.BEACH, displayColors.RIVER, bucket*0.1);
    }
    int biomeBucket(Center p) {
      return _biomeList.indexOf(p.biome);
    }
    int biomeColor(int bucket) {
      return _biomeList[bucket];
    }

    Map computeHistogram(Function bucketFn) {
      Center p;
      Map histogram = {};
      int bucket;
      for (p in map.centers) {
          bucket = bucketFn(p);
          if (bucket >= 0) histogram[bucket] = (histogram[bucket] != null ? histogram[bucket] : 0) + 1;
        }
      return histogram;
    }
    
    drawHistogram(num x, num y, bucketFn, colorFn,
                           num width, num height) {
      num scale;
      Map histogram = computeHistogram(bucketFn);
      
      scale = 0.0;
      histogram.forEach((k, v) => scale = Math.max(scale, (k < histogram.length) ? v : 0));
      histogram.forEach((k, v){
        graphics.beginPath();
        graphics.rect(SIZE+x+k*width/histogram.length, y+height,
                          Math.max(0, width/histogram.length-1), -height*v/scale);
        graphics.fillColor(colorFn(k));
      });      
    }

    drawDistribution(num x, num y, bucketFn, colorFn,
                              num width, num height) {
      num scale;
      int i;
      num w;
      Map histogram = computeHistogram(bucketFn);
    
      scale = 0.0;
      
      histogram.forEach((k, v) => scale += v);
      histogram.forEach((k, v){
        w = v/scale*width;
        graphics.beginPath();
        graphics.rect(SIZE+x, y, Math.max(0, w-1), height);
        x += w;
        graphics.fillColor(colorFn(i));        
      });

    }

    num x = 23;
    num y = 200;
    num width = 154;
    drawDistribution(x, y, landTypeBucket, landTypeColor, width, 20);
    drawDistribution(x, y+25, biomeBucket, biomeColor, width, 20);

    drawHistogram(x, y+55, elevationBucket, elevationColor, width, 30);
    drawHistogram(x, y+95, moistureBucket, moistureColor, width, 20);
  }

  
  // Helpers for rendering paths
  drawPathForwards(Graphics graphics, List<Point> path) {
    print("drawPathForwards()");
    for (int i = 0; i < path.length; i++) {
      graphics.lineTo(path[i].x, path[i].y);
    }
  }
  drawPathBackwards(Graphics graphics, List<Point> path) {
    print("drawPathBackwards()");
    for (int i = path.length-1; i >= 0; i--) {
      graphics.lineTo(path[i].x, path[i].y);
    }
  }

  // TODO: do we need to cover alpha?
  // Helper for color manipulation. When f==0: color0, f==1: color1
  int interpolateColor(int color0, int color1, num f) {
    int a = ((1-f)*(color0 >> 24) + f*(color1 >> 24)).toInt();
    int r = ((1-f)*((color0 >> 16) & 0xff) + f*((color1 >> 16) & 0xff)).toInt();
    int g = ((1-f)*((color0 >> 8) & 0xff) + f*((color1 >> 8) & 0xff)).toInt();
    int b = ((1-f)*(color0 & 0xff) + f*(color1 & 0xff)).toInt();
    if (a > 255) a = 255;
    if (r > 255) r = 255;
    if (g > 255) g = 255;
    if (b > 255) b = 255;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  
   
  // Helper for drawing triangles with gradients. This
  // sets up the fill on the graphics object, and then
  // calls fillto draw the desired path.
  drawGradientTriangle(Graphics graphics,
                                        Vector3 v1, Vector3 v2, Vector3 v3,
                                        List colors, drawFunction) {
    // Center of triangle:
    Vector3 V = v1.add(v2).add(v3);
    V.scale(1/3.0);

    // Normal of the plane containing the triangle:
    Vector3 N = v2.sub(v1).cross(v3.sub(v1));
    N.normalize();

    // Gradient vector in x-y plane pointing in the direction of increasing z
    Vector3 G = new Vector3(-N.x/N.z, -N.y/N.z, 0.0);

    // Center of the color gradient
    Vector3 C = new Vector3(V.x - G.x*((V.z-0.5)/G.length/G.length), V.y - G.y*((V.z-0.5)/G.length/G.length), 0.0);

    graphics.beginPath();
    drawFunction();
    
    if (G.length < 1e-6) {
      // If the gradient vector is small, there's not much
      // difference in colors across this triangle. Use a plain
      // fill, because the numeric accuracy of 1/G.length is not to
      // be trusted.  NOTE: only works for 1, 2, 3 colors in the array
      int color = colors[0];
      if (colors.length == 2) {
        color = interpolateColor(colors[0], colors[1], V.z);
      } else if (colors.length == 3) {
        if (V.z < 0.5) {
          color = interpolateColor(colors[0], colors[1], V.z*2);
        } else {
          color = interpolateColor(colors[1], colors[2], V.z*2-1);
        }
      }
      graphics.fillColor(color);
    } else {
      // The gradient box is weird to set up, so we let Flash set up
      // a basic matrix and then we alter it:
      /** TODO: reimplement
      Matrix m = new Matrix.fromIdentity();
      m.createGradientBox(1, 1, 0, 0, 0);
      m.translate(-0.5, -0.5);
      m.scale((1/G.length), (1/G.length));
      m.rotate(Math.atan2(G.y, G.x));
      m.translate(C.x, C.y);
      List alphas = colors.map((_) { return 1.0; });
      List spread = colors.map((color) { return 255*colors.indexOf(color)/(colors.length-1); });
      */
      GraphicsGradient gradient = new GraphicsGradient.linear(0,0,G.x,G.y);
      gradient.addColorStop(0.0, 0xffffffff);
      gradient.addColorStop(1.0, 0xffff00ff);
      graphics.fillGradient(gradient);
      //graphics.beginGradientFill(GradientType.LINEAR, colors, alphas, spread, m, SpreadMethod.PAD);
    }
    
  }
  
  

  // Draw the map in the current map mode
  drawMap(String mode) {
    print("drawMap()");
    graphicsReset();
    noiseLayer.visible = true;
    
    //drawHistograms();
    
    if (mode == 'polygons') {
      noiseLayer.visible = false;
      renderDebugPolygons(graphics);
    } else if (mode == 'watersheds') {
      noiseLayer.visible = false;
      renderDebugPolygons(graphics);
      renderWatersheds(graphics);
      return;
    } else if (mode == 'biome') {
      renderPolygons(graphics, _displayColorList, null, null);
    } else if (mode == 'slopes') {
      renderPolygons(graphics, _displayColorList, null, colorWithSlope);
    } else if (mode == 'smooth') {
      renderPolygons(graphics, _displayColorList, null, colorWithSmoothColors);
    } else if (mode == 'elevation') {
      renderPolygons(graphics, _elevationGradientColors, 'elevation', null);
    } else if (mode == 'moisture') {
      renderPolygons(graphics, _moistureGradientColors, 'moisture', null);
    }

    if (mode != 'slopes' && mode != 'moisture') {
      renderRoads(graphics, _displayColorList);
    }
    if (mode != 'polygons') {
      renderEdges(graphics);
    }
    if (mode != 'slopes' && mode != 'moisture') {
      renderBridges(graphics);
    }
  }
  
  // Render the interior of polygons
  renderPolygons(Graphics graphics, List colors, String gradientFillProperty, colorOverrideFunction) {
    Center p;
    Center r;

    // My Voronoi polygon rendering doesn't handle the boundary
    // polygons, so I just fill everything with ocean first.
    graphics.beginPath();
    graphics.rect(0, 0, SIZE, SIZE);
    graphics.fillColor(displayColors.OCEAN);
    
    for (p in map.centers) {
        for(r in p.neighbors) {
            Edge edge = map.lookupEdgeFromCenter(p, r);
            int color = p.biome.color != null ? p.biome.color : 0;
            if (colors!= null) {
              color = colorOverrideFunction(color, p, r, edge);
            }

            drawPath0() {
              List<Point> path = noisyEdges.path0[edge.index];
              graphics.moveTo(p.point.x, p.point.y);
              graphics.lineTo(path[0].x, path[0].y);
              drawPathForwards(graphics, path);
              graphics.lineTo(p.point.x, p.point.y);
            }

            drawPath1() {
              List<Point> path = noisyEdges.path1[edge.index];
              graphics.moveTo(p.point.x, p.point.y);
              graphics.lineTo(path[0].x, path[0].y);
              drawPathForwards(graphics, path);
              graphics.lineTo(p.point.x, p.point.y);
            }

            if (noisyEdges.path0[edge.index] == null
                || noisyEdges.path1[edge.index] == null) {
              // It's at the edge of the map, where we don't have
              // the noisy edges computed. TODO: figure out how to
              // fill in these edges from the voronoi library.
              continue;
            }

            if (gradientFillProperty != null) {
              // We'll draw two triangles: center - corner0 -
              // midpoint and center - midpoint - corner1.
              Corner corner0 = edge.v0;
              Corner corner1 = edge.v1;

              // We pick the midpoint elevation/moisture between
              // corners instead of between polygon centers because
              // the resulting gradients tend to be smoother.
//              Point midpoint = edge.midpoint;
              /* TODO: reimplement
              num midpointAttr = 0.5*(corner0[gradientFillProperty]+corner1[gradientFillProperty]);
              
              drawGradientTriangle
                (graphics,
                 new Vector3(p.point.x, p.point.y, p[gradientFillProperty]),
                 new Vector3(corner0.point.x, corner0.point.y, corner0[gradientFillProperty]),
                 new Vector3(midpoint.x, midpoint.y, midpointAttr),
                 [displayColors.GRADIENT_LOW, displayColors.GRADIENT_HIGH], drawPath0);
              drawGradientTriangle
                (graphics,
                 new Vector3(p.point.x, p.point.y, p[gradientFillProperty]),
                 new Vector3(midpoint.x, midpoint.y, midpointAttr),
                 new Vector3(corner1.point.x, corner1.point.y, corner1[gradientFillProperty]),
                 [displayColors.GRADIENT_LOW, displayColors.GRADIENT_HIGH], drawPath1);
                
               */
            } else {
              drawPath0();
              drawPath1();
              graphics.fillColor(color);
            }
          }
      }
  }


  // Render bridges across every narrow river edge. Bridges are
  // straight line segments perpendicular to the edge. Bridges are
  // drawn after rivers. TODO: sometimes the bridges aren't long
  // enough to cross the entire noisy line river. TODO: bridges
  // don't line up with curved road segments when there are
  // roads. It might be worth making a shader that draws the bridge
  // only when there's water underneath.
  renderBridges(Graphics graphics) {
    Edge edge;

    for(edge in map.edges) {
        if (edge.river > 0 && edge.river < 4
            && !edge.d0.water && !edge.d1.water
            && (edge.d0.elevation > 0.05 || edge.d1.elevation > 0.05)) {
          
          
          Vector n = new Vector(-(edge.v1.point.y - edge.v0.point.y), edge.v1.point.x - edge.v0.point.x);
          
          // previous: n.normalize(0.25 + (roads.road[edge.index]? 0.5 : 0) + 0.75*Math.sqrt(edge.river));
          n = n.normalize().scale(0.25 + (roads.road.length >= edge.index ? 0.5 : 0) + 0.75*Math.sqrt(edge.river));
          
          // TODO: is this correct?
          //graphics.lineStyle(1.1, colors.BRIDGE, 1.0, false, LineScaleMode.NORMAL, CapsStyle.SQUARE);
          graphics.beginPath();
          graphics.moveTo(edge.midpoint.x - n.x, edge.midpoint.y - n.y);
          graphics.lineTo(edge.midpoint.x + n.x, edge.midpoint.y + n.y);
          //graphics.lineStyle();
          graphics.strokeColor(displayColors.BRIDGE);
        }
      }
  }

  
  // Render roads. We draw these before polygon edges, so that rivers overwrite roads.
  renderRoads(Graphics graphics, List colors) {
    // First draw the roads, because any other feature should draw
    // over them. Also, roads don't use the noisy lines.
    Center p;
    Point A;
    Point B;
    Point C;
    int i;
    int j;
    num d;
    Edge edge1;
    Edge edge2;
    List<Edge> edges;

    // Helper: find the normal vector across edge 'e' and
    // make sure to point it in a direction towards 'c'.
    Vector normalTowards(Edge e, Point c, num len) {
      // Rotate the v0-->v1 vector by 90 degrees:
      Vector n = new Vector(-(e.v1.point.y - e.v0.point.y), e.v1.point.x - e.v0.point.x);
      // Flip it around it if doesn't point towards c
      Point d = c - e.midpoint;
      if (n.x * d.x + n.y * d.y < 0) {
        n.scale(-1);
      }
      n = n.normalize().scale(len);
      return n;
    }
    
    for(p in map.centers) {
        if (roads.roadConnections[p.index] != null) {
          if (roads.roadConnections[p.index].length == 2) {
            // Regular road: draw a spline from one edge to the other.
            edges = p.borders;
            for (i = 0; i < edges.length; i++) {
              edge1 = edges[i];
              if (roads.road[edge1.index] > 0) {
                for (j = i+1; j < edges.length; j++) {
                  edge2 = edges[j];
                  if (roads.road[edge2.index] > 0) {
                    // The spline connects the midpoints of the edges
                    // and at right angles to them. In between we
                    // generate two control points A and B and one
                    // additional vertex C.  This usually works but
                    // not always.
                    d = 0.5*Math.min
                      ((edge1.midpoint - p.point).magnitude,
                       (edge2.midpoint - p.point).magnitude);
                    A = addVectorToPoint(normalTowards(edge1, p.point, d), edge1.midpoint);
                    B = addVectorToPoint(normalTowards(edge2, p.point, d), edge2.midpoint);
                    C = Point.interpolate(A, B, 0.5);
                    graphics.moveTo(edge1.midpoint.x, edge1.midpoint.y);
                    graphics.beginPath();
                    graphics.quadraticCurveTo(A.x, A.y, C.x, C.y);
                    graphics.strokeColor(roads.road[edge1.index].color, 1.1);
                    graphics.beginPath();
                    graphics.quadraticCurveTo(B.x, B.y, edge2.midpoint.x, edge2.midpoint.y);
                    graphics.strokeColor(roads.road[edge2.index].color, 1.1);
                  }
                }
              }
            }
          } else {
            // Intersection or dead end: draw a road spline from
            // each edge to the center
            for(edge1 in p.borders) {
                if (roads.road[edge1.index] > 0) {
                  d = 0.25 * (edge1.midpoint - p.point).magnitude;
                  A = addVectorToPoint(normalTowards(edge1, p.point, d), edge1.midpoint);
                  graphics.moveTo(edge1.midpoint.x, edge1.midpoint.y);
                  graphics.beginPath();
                  graphics.quadraticCurveTo(A.x, A.y, p.point.x, p.point.y);
                  graphics.strokeColor(roads.road[edge1.index].colors, 1.4);
                }
              }
          }
        }
      }
  }

  
  // Render the exterior of polygons: coastlines, lake shores,
  // rivers, lava fissures. We draw all of these after the polygons
  // so that polygons don't overwrite any edges.
  renderEdges(Graphics graphics) {
    Center p;
    Center r;
    Edge edge;

    for(p in map.centers) {
        for(r in p.neighbors) {
            edge = map.lookupEdgeFromCenter(p, r);
            if (noisyEdges.path0[edge.index] == null
                || noisyEdges.path1[edge.index] == null) {
              // It's at the edge of the map
              continue;
            }
            
            int color = 0;
            double width = 0.0;
            
            if (p.ocean != r.ocean) {
              // One side is ocean and the other side is land -- coastline
              color = displayColors.COAST;
              width = 2.0;
            } else if (p.water != r.water && p.biome != 'ICE' && r.biome != 'ICE') {
              // Lake boundary
              color = displayColors.LAKESHORE;
              width = 1.0;
            } else if (p.water || r.water) {
              // Lake interior – we don't want to draw the rivers here
              continue;
            } else if (lava.lava[edge.index] != null) {
              // Lava flow
              color = displayColors.LAVA;
              width = 1.0;
            } else if (edge.river > 0) {
              // River edge
              color = displayColors.RIVER;
              width = Math.sqrt(edge.river);
            } else {
              // No edge
              continue;
            }
            
            graphics.moveTo(noisyEdges.path0[edge.index][0].x,
                            noisyEdges.path0[edge.index][0].y);
            graphics.beginPath();
            drawPathForwards(graphics, noisyEdges.path0[edge.index]);
            drawPathBackwards(graphics, noisyEdges.path1[edge.index]);
            graphics.strokeColor(color, width);
          }
      }
  }


  // Render the polygons so that each can be seen clearly
  renderDebugPolygons(Graphics graphics) {
    Center p;
    Corner q;
    Edge edge;
    Point point;
    int color;

    print("Begin renderDebugPolygons");
    
    if (map.centers.length == 0) {
      // We're still constructing the map so we may have some points
      graphics.beginPath();
      graphics.rect(0, 0, SIZE, SIZE);
      graphics.fillColor(0xffdddddd);
      
      
      for(point in map.points) {
        graphics.beginPath();
          graphics.circle(point.x, point.y, 1.3);
          graphics.fillColor(0xff000000);
        }
    }
    
    
    
    for(Center p in map.centers) {   
      
      
      // Fill Polygon
          int fillColor = p.biome != null ? p.biome.color : 
            (p.ocean != null ? displayColors.OCEAN : 
              (p.water != null ? displayColors.RIVER : 0xffffffff));

          for(edge in p.borders) {
              if (edge.v0 != null && edge.v1 != null) {              
                graphics.beginPath();
                graphics.moveTo(p.point.x, p.point.y);
                graphics.lineTo(edge.v0.point.x, edge.v0.point.y);
                graphics.lineTo(edge.v1.point.x, edge.v1.point.y);
                graphics.fillColor(interpolateColor(fillColor, 0xffdddddd, 0.2));
              }
            }
          

       
        for(Edge edge in p.borders) {
            if (edge.v0 != null && edge.v1 != null) {
              //graphics.moveTo(p.point.x, p.point.y);
              int strokeColor = 0;
              double width = 0.0;
              if (edge.river > 0) {
                strokeColor = displayColors.RIVER;
                width = 2.0;
              } else {
                strokeColor = 0x66000000;
                width = 0.0;
              }

              graphics.beginPath();
              graphics.moveTo(edge.v0.point.x, edge.v0.point.y);
              graphics.lineTo(edge.v1.point.x, edge.v1.point.y);
              graphics.strokeColor(strokeColor, width);
            }
          }
          
           
        
      //draw every center
        graphics.beginPath();
               graphics.circle(p.point.x, p.point.y, 1.3);
               graphics.fillColor(p.water ? 0xb0003333 : 0xb0000000);
               
        //draw every corner
        for(q in p.corners) {
          graphics.beginPath();
            graphics.rect(q.point.x-0.7, q.point.y-0.7, 1.5, 1.5);
            graphics.fillColor(q.water ? 0xff0000ff : 0xff009900);
          }
        
        
      }
    
    print("End renderDebugPolygons");
  }


  // Render the paths from each polygon to the ocean, showing watersheds
  renderWatersheds(Graphics graphics) {
    Edge edge;
    int w0;
    int w1;

    for(edge in map.edges) {
        if (edge.d0 != null && edge.d1 != null && edge.v0 != null && edge.v1 != null
            && !edge.d0.ocean && !edge.d1.ocean) {
          w0 = watersheds.watersheds[edge.d0.index];
          w1 = watersheds.watersheds[edge.d1.index];
          if (w0 != w1) {
            graphics.moveTo(edge.v0.point.x, edge.v0.point.y);
            graphics.beginPath();
            graphics.lineTo(edge.v1.point.x, edge.v1.point.y);
            graphics.strokeColor((0xff * 0.1*Math.sqrt((map.corners[w0].watershed_size != null ? map.corners[w0].watershed_size : 1) + (map.corners[w1].watershed.watershed_size != null ? map.corners[w1].watershed.watershed_size : 1))).toInt() << 24, 3.5);
          }
        }
      }

    for(edge in map.edges) {
        if (edge.river != null) {
          graphics.moveTo(edge.v0.point.x, edge.v0.point.y);
          graphics.beginPath();
          graphics.lineTo(edge.v1.point.x, edge.v1.point.y);
          graphics.strokeColor(0xff6699ff);
        }
      }
  }
  

  Vector3 lightVector = new Vector3(-1.0, -1.0, 0.0);
  num calculateLighting(Center p, Corner r, Corner s) {
    Vector3 A = new Vector3(p.point.x, p.point.y, p.elevation);
    Vector3 B = new Vector3(r.point.x, r.point.y, r.elevation);
    Vector3 C = new Vector3(s.point.x, s.point.y, s.elevation);
    Vector3 normal = (B-A).cross(C-A);
    if (normal.z < 0) { normal.scale(-1.0); }
    normal.normalize();
    num light = 0.5 + 35*normal.dot(lightVector);
    if (light < 0) light = 0;
    if (light > 1) light = 1;
    return light;
  }
  
  int colorWithSlope(int color, Center p, Center q, Edge edge) {
    Corner r = edge.v0;
    Corner s = edge.v1;
    if (r == null || s == null) {
      // Edge of the map
      return displayColors.OCEAN;
    } else if (p.water) {
      return color;
    }

    if (q != null && p.water == q.water) color = interpolateColor(color, q.biome.color, 0.4);
    int colorLow = interpolateColor(color, 0xff333333, 0.7);
    int colorHigh = interpolateColor(color, 0xffffffff, 0.3);
    num light = calculateLighting(p, r, s);
    if (light < 0.5) return interpolateColor(colorLow, color, light*2);
    else return interpolateColor(color, colorHigh, light*2-1);
  }


  int colorWithSmoothColors(int color, Center p, Center q, Edge edge) {
    if (q != null && p.water == q.water) {
      color = interpolateColor(p.biome.color, q.biome.color, 0.25);
    }
    return color;
  }

  /*
  //////////////////////////////////////////////////////////////////////
  // The following code is used to export the maps to disk

  // We export elevation, moisture, and an override byte. Instead of
  // rendering with RGB values, we render with bytes 0x00-0xff as
  // colors, and then save these bytes in a ByteArray. For override
  // codes, we turn off anti-aliasing.
  static Map exportOverrideColors = {
    // override codes are 0:none, 0x10:river water, 0x20:lava,
    //   0x30:snow, 0x40:ice, 0x50:ocean, 0x60:lake, 0x70:lake shore,
    //   0x80:ocean shore, 0x90,0xa0,0xb0:road, 0xc0:bridge.  These
    //   are ORed with 0x01: polygon center, 0x02: safe polygon
    //   center. 
    POLYGON_CENTER: 0x01,
    POLYGON_CENTER_SAFE: 0x03,
    OCEAN: 0x50,
    COAST: 0x80,
    LAKE: 0x60,
    LAKESHORE: 0x70,
    RIVER: 0x10,
    MARSH: 0x10,
    ICE: 0x40,
    LAVA: 0x20,
    SNOW: 0x30,
    ROAD1: 0x90,
    ROAD2: 0xa0,
    ROAD3: 0xb0,
    BRIDGE: 0xc0
  };

  static Map exportElevationColors = {
    OCEAN: 0x00,
    GRADIENT_LOW: 0x00,
    GRADIENT_HIGH: 0xff
  };

  static Map exportMoistureColors = {
    OCEAN: 0xff,
    GRADIENT_LOW: 0x00,
    GRADIENT_HIGH: 0xff
  };
    
  
  // This draws to a bitmap and copies that data into the
  // three export byte arrays.  The layer parameter should be one of
  // 'elevation', 'moisture', 'overrides'.
  ByteArray makeExport(String layer) {
    BitmapData exportBitmap = new BitmapData(2048, 2048);
    Shape exportGraphics = new Shape();
    ByteArray exportData = new ByteArray();
    
    Matrix m = new Matrix();
    m.scale(2048.0 / SIZE, 2048.0 / SIZE);

    saveBitmapToArray() {
      for (int x = 0; x < 2048; x++) {
        for (int y = 0; y < 2048; y++) {
          exportData.writeByte(exportBitmap.getPixel(x, y) & 0xff);
        }
      }
    }

    if (layer == 'overrides') {
      renderPolygons(exportGraphics.graphics, exportOverrideColors, null, null);
      renderRoads(exportGraphics.graphics, exportOverrideColors);
      renderEdges(exportGraphics.graphics, exportOverrideColors);
      renderBridges(exportGraphics.graphics, exportOverrideColors);

      stage.quality = 'low';
      exportBitmap.draw(exportGraphics, m);
      stage.quality = 'best';

      // Mark the polygon centers in the export bitmap
      for(Center p in map.centers) {
          if (!p.ocean) {
            r:Point = new Point(Math.floor(p.point.x * 2048/SIZE),
                                  Math.floor(p.point.y * 2048/SIZE));
            exportBitmap.setPixel(r.x, r.y,
                                  exportBitmap.getPixel(r.x, r.y)
                                  | (roads.roadConnections[p]?
                                     exportOverrideColors.POLYGON_CENTER_SAFE
                                     : exportOverrideColors.POLYGON_CENTER));
          }
        }
      
      saveBitmapToArray();
    } else if (layer == 'elevation') {
      renderPolygons(exportGraphics.graphics, exportElevationColors, 'elevation', null);
      exportBitmap.draw(exportGraphics, m);
      saveBitmapToArray();
    } else if (layer == 'moisture') {
      renderPolygons(exportGraphics.graphics, exportMoistureColors, 'moisture', null);
      exportBitmap.draw(exportGraphics, m);
      saveBitmapToArray();
    }
    return exportData;
  }


  // Export the map visible in the UI as a PNG. Turn OFF the noise
  // layer because (1) it's scaled the wrong amount for the big
  // image, and (2) it makes the resulting PNG much bigger, and (3)
  // it makes it harder to apply your own texturing or noise later.
  ByteArray exportPng() {
    exportBitmap:BitmapData = new BitmapData(2048, 2048);
    originalNoiseLayerVisible:Boolean = noiseLayer.visible;
    
    Matrix m = new Matrix();
    m.scale(2048.0 / SIZE, 2048.0 / SIZE);
    noiseLayer.visible = false;
    exportBitmap.draw(this, m);
    noiseLayer.visible = originalNoiseLayerVisible;
    
    return PNGEncoder.encode(exportBitmap);
  }

  
  // Export the graph data as XML.
  String exportPolygons() {
    // NOTE: For performance, we do not assemble the entire XML in
    // memory and then serialize it. Instead, we incrementally
    // serialize small portions into arrays of strings, and then assemble the
    // strings together.
    Center p;
    Corner q;
    Center r;
    Corner s;
    Edge edge;
    XML.prettyPrinting = false;
    top:XML =
      <map
        shape={islandSeedInput.text}
        islandType={islandType} pointType={pointType} size={numPoints}>
        <generator
           url="http://www-cs-students.stanford.edu/~amitp/game-programming/polygon-map-generation/"
           timestamp={new Date().toUTCString()} />
        <REPLACE/>
      </map>;

    dnodes:Array = [];
    edges:Array = [];
    vnodes:Array = [];
    outroads:Array = [];
    accum:Array = [];  // temporary accumulator for serialized xml fragments
    edgeNode:XML;

    for(p in map.centers) {
        accum.splice(0, accum.length);

        for(r in p.neighbors) {
            accum.push(<center id={r.index}/>.toXMLString());
          }
        for(edge in p.borders) {
            accum.push(<edge id={edge.index}/>.toXMLString());
          }
        for(q in p.corners) {
            accum.push(<corner id={q.index}/>.toXMLString());
          }
        
        dnodes.push
          (<center id={p.index}
                   x={p.point.x} y={p.point.y}
                   water={p.water} ocean={p.ocean}
                   coast={p.coast} border={p.border}
                   biome={p.biome}
                   elevation={p.elevation} moisture={p.moisture}>
             <REPLACE/>
           </center>.toXMLString().replace("<REPLACE/>", accum.join("")));
      }

    for(edge in map.edges) {
        edgeNode =
          <edge id={edge.index} river={edge.river}/>;
        if (edge.midpoint != null) {
          edgeNode.@x = edge.midpoint.x;
          edgeNode.@y = edge.midpoint.y;
        }
        if (edge.d0 != null) edgeNode.@center0 = edge.d0.index;
        if (edge.d1 != null) edgeNode.@center1 = edge.d1.index;
        if (edge.v0 != null) edgeNode.@corner0 = edge.v0.index;
        if (edge.v1 != null) edgeNode.@corner1 = edge.v1.index;
        edges.push(edgeNode.toXMLString());
      }

    for(q in map.corners) {
        accum.splice(0, accum.length);
        for(p in q.touches) {
            accum.push(<center id={p.index}/>.toXMLString());
          }
        for(edge in q.protrudes) {
            accum.push(<edge id={edge.index}/>.toXMLString());
          }
        for(s in q.adjacent) {
            accum.push(<corner id={s.index}/>.toXMLString());
          }
        
        vnodes.push
          (<corner id={q.index}
                   x={q.point.x} y={q.point.y}
                   water={q.water} ocean={q.ocean}
                   coast={q.coast} border={q.border}
                   elevation={q.elevation} moisture={q.moisture}
                   river={q.river} downslope={q.downslope?q.downslope.index:-1}>
             <REPLACE/>
           </corner>.toXMLString().replace("<REPLACE/>", accum.join("")));
      }
      
      for (i:String in roads.road) {
        outroads.push(<road edge={i} contour={roads.road[i]} />.toXMLString());
      }

    out:String = top.toXMLString();
    accum = [].concat("<centers>",
                      dnodes, "</centers><edges>",
                      edges, "</edges><corners>",
                      vnodes, "</corners><roads>",
                      outroads, "</roads>");
    out = out.replace("<REPLACE/>", accum.join(""));
    return out;
  }
*/

  // Make a button or label. If the callback is null, it's just a label.
  TextField makeButton(String label, num x, num y, num width, callback) {
    TextField button = new TextField();
    //TextFormat format = new TextFormat("Arial");
//    format.font = "Arial";
  //  format.align = 'center';
    //button.defaultTextFormat = format;
    button.defaultTextFormat.font = "Arial";
    button.defaultTextFormat.align = 'center';
    button.text = label;
    //button.selectable = false;
    button.x = x;
    button.y = y;
    button.width = width;
    button.height = 20;
    if (callback != null) {
      button.background = true;
      button.backgroundColor = 0xffffffcc;
      button.addEventListener(MouseEvent.CLICK, callback);
    }
    return button;
  }
  
  Math.Random random = new Math.Random();

  
  addIslandShapeButtons() {
    int y = 4;
    TextField islandShapeLabel = makeButton("Island Shape:", 25, y, 150, null);

    TextField seedLabel = makeButton("Shape #", 20, y+22, 50, null);
    
    islandSeedInput = makeButton(islandSeedInitial, 70, y+22, 54, null);
    islandSeedInput.background = true;
    islandSeedInput.backgroundColor = 0xffccddcc;
    //islandSeedInput.selectable = true;
    islandSeedInput.type = TextFieldType.INPUT;
    islandSeedInput.addEventListener(KeyboardEvent.KEY_UP, (KeyboardEvent e) {
        if (e.keyCode == 13) {
          go(islandType, pointType, numPoints);
        }
      });

    Map mapTypes = {};
    
    markActiveIslandShape(String newIslandType) {
      mapTypes[islandType].backgroundColor = 0xffffffcc;
      mapTypes[newIslandType].backgroundColor = 0xffffff00;
    }
    
    Function setIslandTypeTo(String type){
      return(Event e) {
        markActiveIslandShape(type);
        go(type, pointType, numPoints);
      };
    }
    
    mapTypes = {
      'Radial': makeButton("Radial", 23, y+44, 40, setIslandTypeTo('Radial')),
      'Perlin': makeButton("Perlin", 65, y+44, 35, setIslandTypeTo('Perlin')),
      'Square': makeButton("Square", 102, y+44, 44, setIslandTypeTo('Square')),
      'Blob': makeButton("Blob", 148, y+44, 29, setIslandTypeTo('Blob'))
    };
    markActiveIslandShape(islandType);
    
    controls.addChild(islandShapeLabel);
    controls.addChild(seedLabel);
    controls.addChild(islandSeedInput);
    controls.addChild(makeButton("Random", 125, y+22, 56,
                                 (Event e) {
                                   islandSeedInput.text =
                                     ( random.nextInt(100000).toString()
                                       + "-"
                                       + random.nextInt(10).toString());
                                   go(islandType, pointType, numPoints);
                                 }));
    controls.addChild(mapTypes["Radial"]);
    controls.addChild(mapTypes["Perlin"]);
    controls.addChild(mapTypes["Square"]);
    controls.addChild(mapTypes["Blob"]);
  }


  addPointSelectionButtons() {
    
    Map pointTypes;
    
    markActivePointSelection(String newPointType) {
      pointTypes[pointType].backgroundColor = 0xffffffcc;
      pointTypes[newPointType].backgroundColor = 0xffffff00;
    }

    Function setPointsTo(String type){
      return(Event e) {
        markActivePointSelection(type);
        go(islandType, type, numPoints);
      };
    }
    
    pointTypes = {
      'Random': makeButton("Random", 16, y+120, 50, setPointsTo('Random')),
      'Relaxed': makeButton("Relaxed", 68, y+120, 48, setPointsTo('Relaxed')),
      'Square': makeButton("Square", 118, y+120, 44, setPointsTo('Square')),
      'Hexagon': makeButton("Hex", 164, y+120, 28, setPointsTo('Hexagon'))
    };
    markActivePointSelection(pointType);

    TextField pointTypeLabel = makeButton("Point Selection:", 25, y+100, 150, null);
    controls.addChild(pointTypeLabel);
    controls.addChild(pointTypes["Random"]);
    controls.addChild(pointTypes["Relaxed"]);
    controls.addChild(pointTypes["Square"]);
    controls.addChild(pointTypes["Hexagon"]);

    Map<int, TextField> pointCounts;
    
    markActiveNumPoints(int newNumPoints) {
      TextField previousButton = pointCounts[numPoints.toString()];
      if(previousButton != null){
        pointCounts[numPoints.toString()].backgroundColor = 0xffffffcc;        
      }
      
      TextField nextButton = pointCounts[newNumPoints.toString()]; 
      if(nextButton != null){
        nextButton.backgroundColor = 0xffffff00; 
      }
    }

    Function setNumPointsTo(int num){
      return(Event e) {
        markActiveNumPoints(num);
        go(islandType, pointType, num);
      };
    }
    
    pointCounts = {
      '500': makeButton("500", 23, y+142, 24, setNumPointsTo(500)),
      '1000': makeButton("1000", 49, y+142, 32, setNumPointsTo(1000)),
      '2000': makeButton("2000", 83, y+142, 32, setNumPointsTo(2000)),
      '4000': makeButton("4000", 117, y+142, 32, setNumPointsTo(4000)),
      '8000': makeButton("8000", 151, y+142, 32, setNumPointsTo(8000))
    };
    markActiveNumPoints(numPoints);
    controls.addChild(pointCounts['500']);
    controls.addChild(pointCounts['1000']);
    controls.addChild(pointCounts['2000']);
    controls.addChild(pointCounts['4000']);
    controls.addChild(pointCounts['8000']);
  }

  
  addViewButtons() {
    int y = 330;

    Map views;
    
    markViewButton(String mode) {
      views[mapMode].backgroundColor = 0xffffffcc;
      views[mode].backgroundColor = 0xffffff00;
    }
    Function switcher(String mode){
      return(Event e) {
        markViewButton(mode);
        mapMode = mode;
        drawMap(mapMode);
      };
    }
    
    views = {
      'biome': makeButton("Biomes", 25, y+22, 74, switcher('biome')),
      'smooth': makeButton("Smooth", 101, y+22, 74, switcher('smooth')),
      'slopes': makeButton("2D slopes", 25, y+44, 74, switcher('slopes')),
      'elevation': makeButton("Elevation", 25, y+66, 74, switcher('elevation')),
      'moisture': makeButton("Moisture", 101, y+66, 74, switcher('moisture')),
      'polygons': makeButton("Polygons", 25, y+88, 74, switcher('polygons')),
      'watersheds': makeButton("Watersheds", 101, y+88, 74, switcher('watersheds'))
    };

    markViewButton(mapMode);
    
    controls.addChild(makeButton("View:", 50, y, 100, null));
    
    controls.addChild(views["biome"]);
    controls.addChild(views["smooth"]);
    controls.addChild(views["slopes"]);
    controls.addChild(views["elevation"]);
    controls.addChild(views["moisture"]);
    controls.addChild(views["polygons"]);
    controls.addChild(views["watersheds"]);
  }


  addMiscLabels() {
    controls.addChild(makeButton("Distribution:", 50, 180, 100, null));
    statusBar = makeButton("", (SIZE/2-50).toInt(), 10, 100, null);
    addChild(statusBar);
  }

             
  addExportButtons() {
    num y = 450;
    controls.addChild(makeButton("Export byte arrays:", 25, y, 150, null));
             
    controls.addChild(makeButton("Elevation", 50, y+22, 100,
                        (Event e) {
                          //TODO: new FileReference().save(makeExport('elevation'), 'elevation.data');
                        }));
    controls.addChild(makeButton("Moisture", 50, y+44, 100,
                        (Event e) {
//TODO: new FileReference().save(makeExport('moisture'), 'moisture.data');
                        }));
    controls.addChild(makeButton("Overrides", 50, y+66, 100,
                        (Event e) {
//TODO:                   new FileReference().save(makeExport('overrides'), 'overrides.data');
                        }));

    controls.addChild(makeButton("Export:", 25, y+100, 50, null));
    controls.addChild(makeButton("XML", 77, y+100, 35,
                        (Event e) {
//TODO:                   new FileReference().save(exportPolygons(), 'map.xml');
                        }));
    controls.addChild(makeButton("PNG", 114, y+100, 35,
                        (Event e) {
//TODO:                   new FileReference().save(exportPng(), 'map.png');
                        }));
  }
  
}
