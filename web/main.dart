library mapgen2;

import 'dart:html' as html;
import 'package:stagexl/stagexl.dart';

part "world_map.dart";

void main() {

  // setup the Stage and RenderLoop
  var canvas = html.querySelector('#stage');
  var stage = new Stage(canvas);
  var renderLoop = new RenderLoop();
  renderLoop.addStage(stage);
  
  // draw a red circle
  var shape = new Shape();
  shape.graphics.circle(100, 100, 60);
  shape.graphics.fillColor(Color.Red);
  stage.addChild(shape);
}

class displayColors {
  // Features
  static const int OCEAN = 0x44447a;
  static const int COAST = 0x33335a;
  static const int LAKESHORE = 0x225588;
  static const int LAKE = 0x336699;
  static const int RIVER = 0x225588;
  static const int MARSH = 0x2f6666;
  static const int ICE = 0x99ffff;
  static const int BEACH = 0xa09077;
  static const int ROAD1 = 0x442211;
  static const int ROAD2 = 0x553322;
  static const int ROAD3 = 0x664433;
  static const int BRIDGE = 0x686860;
  static const int LAVA = 0xcc3333;

  // Terrain
  static const int SNOW = 0xffffff;
  static const int TUNDRA = 0xbbbbaa;
  static const int BARE = 0x888888;
  static const int SCORCHED = 0x555555;
  static const int TAIGA = 0x99aa77;
  static const int SHRUBLAND = 0x889977;
  static const int TEMPERATE_DESERT = 0xc9d29b;
  static const int TEMPERATE_RAIN_FOREST = 0x448855;
  static const int TEMPERATE_DECIDUOUS_FOREST = 0x679459;
  static const int GRASSLAND = 0x88aa55;
  static const int SUBTROPICAL_DESERT = 0xd2b98b;
  static const int TROPICAL_RAIN_FOREST = 0x337755;
  static const int TROPICAL_SEASONAL_FOREST = 0x559944;
}

class elevationGradientColors {
  static const int OCEAN = 0x008800;
  static const int GRADIENT_LOW = 0x008800;
  static const int GRADIENT_HIGH = 0xffff00;
}

class moistureGradientColors {
  static const int OCEAN = 0x4466ff;
  static const int GRADIENT_LOW = 0xbbaa33;
  static const int GRADIENT_HIGH = 0x4466ff;
}

class mapgen2 extends Sprite {
  static int SIZE = 600;

 
  // Island shape is controlled by the islandRandom seed and the
  // type of island. The islandShape uses both of them to
  // determine whether any point should be water or land.
  String islandType = 'Perlin';
  static String islandSeedInitial = "85882-8";

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


  mapgen2.ctor() {
    stage.scaleMode = 'noScale';
    stage.align = 'TL';

    addChild(noiseLayer);
    noiseLayer.bitmapData.noise(555, 128-10, 128+10, 7, true);
    noiseLayer.blendMode = BlendMode.HARDLIGHT;

    controls.x = SIZE;
    addChild(controls);

    addExportButtons();
    addViewButtons();
    addIslandShapeButtons();
    addPointSelectionButtons();
    addMiscLabels();

    map = new Map(SIZE);
    go(islandType, pointType, numPoints);

  }

  
  // Random parameters governing the overall shape of the island
  void newIsland(String newIslandType, String newPointType, int newNumPoints) {
    int seed = 0;
    int variant = 0;
    num t = getTimer();
    
    if (islandSeedInput.text.length == 0) {
      islandSeedInput.text = (Math.random()*100000).toFixed(0);
    }
    
    RegExp exp = new RegExp(r"\s*(\d+)(?:\-(\d+))\s*$");
    Match match = exp.firstMatch(islandSeedInput.text);
    if (match != null) {
      // It's of the format SHAPE-VARIANT
      seed = parseInt(match[1]);
      variant = parseInt(match[2] || "0");
    }
    if (seed == 0) {
      // Convert the string into a number. This is a cheesy way to
      // do it but it doesn't matter. It just allows people to use
      // words as seeds.
      for (int i = 0; i < islandSeedInput.text.length; i++) {
        seed = (seed << 4) | islandSeedInput.text.charCodeAt(i);
      }
      seed %= 100000;
      variant = 1+Math.floor(9*Math.random());
    }
    islandType = newIslandType;
    pointType = newPointType;
    numPoints = newNumPoints;
    map.newIsland(islandType, pointType, numPoints, seed, variant);
  }

  
  void graphicsReset() {
    triangles3d = [];
    graphics.clear();
    graphics.beginFill(0xbbbbaa);
    graphics.drawRect(0, 0, 2000, 2000);
    graphics.endFill();
    graphics.beginFill(displayColors.OCEAN);
    graphics.drawRect(0, 0, SIZE, SIZE);
    graphics.endFill();
  }

  
  go(String newIslandType, newString pointType, int newNumPoints) {
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

    commandExecute("Edges...",
                   () {
                     roads.createRoads(map);
                     // lava.createLava(map, map.mapRandom.nextDouble);
                     watersheds.createWatersheds(map);
                     noisyEdges.buildNoisyEdges(map, lava, map.mapRandom);
                     drawMap(mapMode);
                   });
  }


  // Command queue is processed on ENTER_FRAME. If it's empty,
  // remove the handler.
  List _guiQueue = [];
  _onEnterFrame(Event e) {
    (_guiQueue.shift()[1])();
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
    _guiQueue.push([status, command]);
  }

  
  // Show some information about the maps
  static List _biomeMap =
    ['BEACH', 'LAKE', 'ICE', 'MARSH', 'SNOW', 'TUNDRA', 'BARE', 'SCORCHED',
     'TAIGA', 'SHRUBLAND', 'TEMPERATE_DESERT', 'TEMPERATE_RAIN_FOREST',
     'TEMPERATE_DECIDUOUS_FOREST', 'GRASSLAND', 'SUBTROPICAL_DESERT',
     'TROPICAL_RAIN_FOREST', 'TROPICAL_SEASONAL_FOREST'];
  drawHistograms() {
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
      else return Math.floor(p.elevation*10);
    }
    int elevationColor(int bucket) {
      return interpolateColor(displayColors.TEMPERATE_DECIDUOUS_FOREST,
                              displayColors.GRASSLAND, bucket*0.1);
    }
    int moistureBucket(Center p) {
      if (p.water) return -1;
      else return Math.floor(p.moisture*10);
    }
    int moistureColor(int bucket) {
      return interpolateColor(displayColors.BEACH, displayColors.RIVER, bucket*0.1);
    }
    int biomeBucket(Center p) {
      return _biomeMap.indexOf(p.biome);
    }
    int biomeColor(int bucket) {
      return displayColors[_biomeMap[bucket]];
    }

    List computeHistogram(Function bucketFn) {
      Center p;
      List histogram;
      int bucket;
      histogram = [];
      for (p in map.centers) {
          bucket = bucketFn(p);
          if (bucket >= 0) histogram[bucket] = (histogram[bucket] || 0) + 1;
        }
      return histogram;
    }
    
    drawHistogram(num x, num y, bucketFn, colorFn,
                           num width, num height) {
      num scale;
      int i;
      List histogram = computeHistogram(bucketFn);
      
      scale = 0.0;
      for (i = 0; i < histogram.length; i++) {
        scale = Math.max(scale, histogram[i] || 0);
      }
      for (i = 0; i < histogram.length; i++) {
        if (histogram[i]) {
          graphics.beginFill(colorFn(i));
          graphics.drawRect(SIZE+x+i*width/histogram.length, y+height,
                            Math.max(0, width/histogram.length-1), -height*histogram[i]/scale);
          graphics.endFill();
        }
      }
    }

    drawDistribution(num x, num y, bucketFn, colorFn,
                              num width, num height) {
      num scale;
      int i;
      num w;
      histogram:Array = computeHistogram(bucketFn);
    
      scale = 0.0;
      for (i = 0; i < histogram.length; i++) {
        scale += histogram[i] || 0.0;
      }
      for (i = 0; i < histogram.length; i++) {
        if (histogram[i]) {
          graphics.beginFill(colorFn(i));
          w = histogram[i]/scale*width;
          graphics.drawRect(SIZE+x, y, Math.max(0, w-1), height);
          x += w;
          graphics.endFill();
        }
      }
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
    for (int i = 0; i < path.length; i++) {
      graphics.lineTo(path[i].x, path[i].y);
    }
  }
  drawPathBackwards(Graphics graphics, List<Point> path) {
    for (int i = path.length-1; i >= 0; i--) {
      graphics.lineTo(path[i].x, path[i].y);
    }
  }


  // Helper for color manipulation. When f==0: color0, f==1: color1
  int interpolateColor(int color0, int color1, num f) {
    r:uint = uint((1-f)*(color0 >> 16) + f*(color1 >> 16));
    g:uint = uint((1-f)*((color0 >> 8) & 0xff) + f*((color1 >> 8) & 0xff));
    b:uint = uint((1-f)*(color0 & 0xff) + f*(color1 & 0xff));
    if (r > 255) r = 255;
    if (g > 255) g = 255;
    if (b > 255) b = 255;
    return (r << 16) | (g << 8) | b;
  }

  
  // Helper for drawing triangles with gradients. This
  // sets up the fill on the graphics object, and then
  // calls fillto draw the desired path.
  drawGradientTriangle(Graphics graphics,
                                        Vector3 v1, Vector3 v2, Vector3 v3,
                                        List colors, fillFunction) {
    m:Matrix = new Matrix();

    // Center of triangle:
    V:Vector3D = v1.add(v2).add(v3);
    V.scaleBy(1/3.0);

    // Normal of the plane containing the triangle:
    N:Vector3D = v2.subtract(v1).crossProduct(v3.subtract(v1));
    N.normalize();

    // Gradient vector in x-y plane pointing in the direction of increasing z
    G:Vector3D = new Vector3D(-N.x/N.z, -N.y/N.z, 0);

    // Center of the color gradient
    Vector3 C = new Vector3D(V.x - G.x*((V.z-0.5)/G.length/G.length), V.y - G.y*((V.z-0.5)/G.length/G.length));

    if (G.length < 1e-6) {
      // If the gradient vector is small, there's not much
      // difference in colors across this triangle. Use a plain
      // fill, because the numeric accuracy of 1/G.length is not to
      // be trusted.  NOTE: only works for 1, 2, 3 colors in the array
      color:uint = colors[0];
      if (colors.length == 2) {
        color = interpolateColor(colors[0], colors[1], V.z);
      } else if (colors.length == 3) {
        if (V.z < 0.5) {
          color = interpolateColor(colors[0], colors[1], V.z*2);
        } else {
          color = interpolateColor(colors[1], colors[2], V.z*2-1);
        }
      }
      graphics.beginFill(color);
    } else {
      // The gradient box is weird to set up, so we let Flash set up
      // a basic matrix and then we alter it:
      m.createGradientBox(1, 1, 0, 0, 0);
      m.translate(-0.5, -0.5);
      m.scale((1/G.length), (1/G.length));
      m.rotate(Math.atan2(G.y, G.x));
      m.translate(C.x, C.y);
      alphas:Array = colors.map((_, int index, List A) { return 1.0; });
      spread:Array = colors.map((_, int index, List A) { return 255*index/(A.length-1); });
      graphics.beginGradientFill(GradientType.LINEAR, colors, alphas, spread, m, SpreadMethod.PAD);
    }
    fill();
    graphics.endFill();
  }
  

  // Draw the map in the current map mode
  drawMap(String mode) {
    graphicsReset();
    noiseLayer.visible = true;
    
    drawHistograms();
    
    if (mode == 'polygons') {
      noiseLayer.visible = false;
      renderDebugPolygons(graphics, displayColors);
    } else if (mode == 'watersheds') {
      noiseLayer.visible = false;
      renderDebugPolygons(graphics, displayColors);
      renderWatersheds(graphics);
      return;
    } else if (mode == 'biome') {
      renderPolygons(graphics, displayColors, null, null);
    } else if (mode == 'slopes') {
      renderPolygons(graphics, displayColors, null, colorWithSlope);
    } else if (mode == 'smooth') {
      renderPolygons(graphics, displayColors, null, colorWithSmoothColors);
    } else if (mode == 'elevation') {
      renderPolygons(graphics, elevationGradientColors, 'elevation', null);
    } else if (mode == 'moisture') {
      renderPolygons(graphics, moistureGradientColors, 'moisture', null);
    }

    if (mode != 'slopes' && mode != 'moisture') {
      renderRoads(graphics, displayColors);
    }
    if (mode != 'polygons') {
      renderEdges(graphics, displayColors);
    }
    if (mode != 'slopes' && mode != 'moisture') {
      renderBridges(graphics, displayColors);
    }
  }
  
  // Render the interior of polygons
  renderPolygons(Graphics graphics, Map colors, String gradientFillProperty, colorOverrideFunction) {
    Center p;
    Center r;

    // My Voronoi polygon rendering doesn't handle the boundary
    // polygons, so I just fill everything with ocean first.
    graphics.beginFill(colors.OCEAN);
    graphics.drawRect(0, 0, SIZE, SIZE);
    graphics.endFill();
    
    for (p in map.centers) {
        for(r in p.neighbors) {
            Edge edge = map.lookupEdgeFromCenter(p, r);
            int color = colors[p.biome] || 0;
            if (colorOverride!= null) {
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
              corner0:Corner = edge.v0;
              corner1:Corner = edge.v1;

              // We pick the midpoint elevation/moisture between
              // corners instead of between polygon centers because
              // the resulting gradients tend to be smoother.
              midPoint point = edge.midpoint;
              midpointAttr:Number = 0.5*(corner0[gradientFillProperty]+corner1[gradientFillProperty]);
              drawGradientTriangle
                (graphics,
                 new Vector3D(p.point.x, p.point.y, p[gradientFillProperty]),
                 new Vector3D(corner0.point.x, corner0.point.y, corner0[gradientFillProperty]),
                 new Vector3D(midpoint.x, midpoint.y, midpointAttr),
                 [colors.GRADIENT_LOW, colors.GRADIENT_HIGH], drawPath0);
              drawGradientTriangle
                (graphics,
                 new Vector3D(p.point.x, p.point.y, p[gradientFillProperty]),
                 new Vector3D(midpoint.x, midpoint.y, midpointAttr),
                 new Vector3D(corner1.point.x, corner1.point.y, corner1[gradientFillProperty]),
                 [colors.GRADIENT_LOW, colors.GRADIENT_HIGH], drawPath1);
            } else {
              graphics.beginFill(color);
              drawPath0();
              drawPath1();
              graphics.endFill();
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
  renderBridges(Graphics graphics, Map colors) {
    Edge edge;

    for(edge in map.edges) {
        if (edge.river > 0 && edge.river < 4
            && !edge.d0.water && !edge.d1.water
            && (edge.d0.elevation > 0.05 || edge.d1.elevation > 0.05)) {
          n:Point = new Point(-(edge.v1.point.y - edge.v0.point.y), edge.v1.point.x - edge.v0.point.x);
          n.normalize(0.25 + (roads.road[edge.index]? 0.5 : 0) + 0.75*Math.sqrt(edge.river));
          graphics.lineStyle(1.1, colors.BRIDGE, 1.0, false, LineScaleMode.NORMAL, CapsStyle.SQUARE);
          graphics.moveTo(edge.midpoint.x - n.x, edge.midpoint.y - n.y);
          graphics.lineTo(edge.midpoint.x + n.x, edge.midpoint.y + n.y);
          graphics.lineStyle();
        }
      }
  }

  
  // Render roads. We draw these before polygon edges, so that rivers overwrite roads.
  renderRoads(Graphics graphics, Map colors) {
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
    Point normalTowards(Edge e, Point c, num len) {
      // Rotate the v0-->v1 vector by 90 degrees:
      n:Point = new Point(-(e.v1.point.y - e.v0.point.y), e.v1.point.x - e.v0.point.x);
      // Flip it around it if doesn't point towards c
      d:Point = c.subtract(e.midpoint);
      if (n.x * d.x + n.y * d.y < 0) {
        n.x = -n.x;
        n.y = -n.y;
      }
      n.normalize(len);
      return n;
    }
    
    for(p in map.centers) {
        if (roads.roadConnections[p.index]) {
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
                      (edge1.midpoint.subtract(p.point).length,
                       edge2.midpoint.subtract(p.point).length);
                    A = normalTowards(edge1, p.point, d).add(edge1.midpoint);
                    B = normalTowards(edge2, p.point, d).add(edge2.midpoint);
                    C = Point.interpolate(A, B, 0.5);
                    graphics.lineStyle(1.1, colors['ROAD'+roads.road[edge1.index]]);
                    graphics.moveTo(edge1.midpoint.x, edge1.midpoint.y);
                    graphics.curveTo(A.x, A.y, C.x, C.y);
                    graphics.lineStyle(1.1, colors['ROAD'+roads.road[edge2.index]]);
                    graphics.curveTo(B.x, B.y, edge2.midpoint.x, edge2.midpoint.y);
                    graphics.lineStyle();
                  }
                }
              }
            }
          } else {
            // Intersection or dead end: draw a road spline from
            // each edge to the center
            for(edge1 in p.borders) {
                if (roads.road[edge1.index] > 0) {
                  d = 0.25*edge1.midpoint.subtract(p.point).length;
                  A = normalTowards(edge1, p.point, d).add(edge1.midpoint);
                  graphics.lineStyle(1.4, colors['ROAD'+roads.road[edge1.index]]);
                  graphics.moveTo(edge1.midpoint.x, edge1.midpoint.y);
                  graphics.curveTo(A.x, A.y, p.point.x, p.point.y);
                  graphics.lineStyle();
                }
              }
          }
        }
      }
  }

  
  // Render the exterior of polygons: coastlines, lake shores,
  // rivers, lava fissures. We draw all of these after the polygons
  // so that polygons don't overwrite any edges.
  renderEdges(Graphics graphics, Map colors) {
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
            if (p.ocean != r.ocean) {
              // One side is ocean and the other side is land -- coastline
              graphics.lineStyle(2, colors.COAST);
            } else if ((p.water > 0) != (r.water > 0) && p.biome != 'ICE' && r.biome != 'ICE') {
              // Lake boundary
              graphics.lineStyle(1, colors.LAKESHORE);
            } else if (p.water || r.water) {
              // Lake interior – we don't want to draw the rivers here
              continue;
            } else if (lava.lava[edge.index]) {
              // Lava flow
              graphics.lineStyle(1, colors.LAVA);
            } else if (edge.river > 0) {
              // River edge
              graphics.lineStyle(Math.sqrt(edge.river), colors.RIVER);
            } else {
              // No edge
              continue;
            }
            
            graphics.moveTo(noisyEdges.path0[edge.index][0].x,
                            noisyEdges.path0[edge.index][0].y);
            drawPathForwards(graphics, noisyEdges.path0[edge.index]);
            drawPathBackwards(graphics, noisyEdges.path1[edge.index]);
            graphics.lineStyle();
          }
      }
  }


  // Render the polygons so that each can be seen clearly
  renderDebugPolygons(Graphics graphics, Map colors) {
    Center p;
    Corner q;
    Edge edge;
    Point point;
    int color;

    if (map.centers.length == 0) {
      // We're still constructing the map so we may have some points
      graphics.beginFill(0xdddddd);
      graphics.drawRect(0, 0, SIZE, SIZE);
      graphics.endFill();
      for(point in map.points) {
          graphics.beginFill(0x000000);
          graphics.drawCircle(point.x, point.y, 1.3);
          graphics.endFill();
        }
    }
    
    for(p in map.centers) {
        color = colors[p.biome] || (p.ocean? colors.OCEAN : p.water? colors.RIVER : 0xffffff);
        graphics.beginFill(interpolateColor(color, 0xdddddd, 0.2));
        for(edge in p.borders) {
            if (edge.v0 && edge.v1) {
              graphics.moveTo(p.point.x, p.point.y);
              graphics.lineTo(edge.v0.point.x, edge.v0.point.y);
              if (edge.river > 0) {
                graphics.lineStyle(2, displayColors.RIVER, 1.0);
              } else {
                graphics.lineStyle(0, 0x000000, 0.4);
              }
              graphics.lineTo(edge.v1.point.x, edge.v1.point.y);
              graphics.lineStyle();
            }
          }
        graphics.endFill();
        graphics.beginFill(p.water > 0 ? 0x003333 : 0x000000, 0.7);
        graphics.drawCircle(p.point.x, p.point.y, 1.3);
        graphics.endFill();
        for(q in p.corners) {
            graphics.beginFill(q.water? 0x0000ff : 0x009900);
            graphics.drawRect(q.point.x-0.7, q.point.y-0.7, 1.5, 1.5);
            graphics.endFill();
          }
      }
  }


  // Render the paths from each polygon to the ocean, showing watersheds
  renderWatersheds(Graphics graphics) {
    Edge edge;
    int w0;
    int w1;

    for(edge in map.edges) {
        if (edge.d0 && edge.d1 && edge.v0 && edge.v1
            && !edge.d0.ocean && !edge.d1.ocean) {
          w0 = watersheds.watersheds[edge.d0.index];
          w1 = watersheds.watersheds[edge.d1.index];
          if (w0 != w1) {
            graphics.lineStyle(3.5, 0x000000, 0.1*Math.sqrt((map.corners[w0].watershed_size || 1) + (map.corners[w1].watershed.watershed_size || 1)));
            graphics.moveTo(edge.v0.point.x, edge.v0.point.y);
            graphics.lineTo(edge.v1.point.x, edge.v1.point.y);
            graphics.lineStyle();
          }
        }
      }

    for(edge in map.edges) {
        if (edge.river) {
          graphics.lineStyle(1.0, 0x6699ff);
          graphics.moveTo(edge.v0.point.x, edge.v0.point.y);
          graphics.lineTo(edge.v1.point.x, edge.v1.point.y);
          graphics.lineStyle();
        }
      }
  }
  

  Vector3 lightVector = new Vector3D(-1, -1, 0);
  num calculateLighting(Center p, Corner r, Corner s) {
    Vector3 A = new Vector3D(p.point.x, p.point.y, p.elevation);
    Vector3 B = new Vector3D(r.point.x, r.point.y, r.elevation);
    Vector3 C = new Vector3D(s.point.x, s.point.y, s.elevation);
    Vector3 normal = B.subtract(A).crossProduct(C.subtract(A));
    if (normal.z < 0) { normal.scaleBy(-1); }
    normal.normalize();
    light:Number = 0.5 + 35*normal.dotProduct(lightVector);
    if (light < 0) light = 0;
    if (light > 1) light = 1;
    return light;
  }
  
  int colorWithSlope(int color, Center p, Center q, Edge edge) {
    Corner r = edge.v0;
    Corner s = edge.v1;
    if (!r || !s) {
      // Edge of the map
      return displayColors.OCEAN;
    } else if (p.water) {
      return color;
    }

    if (q != null && p.water == q.water) color = interpolateColor(color, displayColors[q.biome], 0.4);
    colorLow:int = interpolateColor(color, 0x333333, 0.7);
    colorHigh:int = interpolateColor(color, 0xffffff, 0.3);
    light:Number = calculateLighting(p, r, s);
    if (light < 0.5) return interpolateColor(colorLow, color, light*2);
    else return interpolateColor(color, colorHigh, light*2-1);
  }


  int colorWithSmoothColors(int color, Center p, Center q, Edge edge) {
    if (q != null && p.water == q.water) {
      color = interpolateColor(displayColors[p.biome], displayColors[q.biome], 0.25);
    }
    return color;
  }

  
  //////////////////////////////////////////////////////////////////////
  // The following code is used to export the maps to disk

  // We export elevation, moisture, and an override byte. Instead of
  // rendering with RGB values, we render with bytes 0x00-0xff as
  // colors, and then save these bytes in a ByteArray. For override
  // codes, we turn off anti-aliasing.
  static Map exportOverrideColors = {
    /* override codes are 0:none, 0x10:river water, 0x20:lava,
       0x30:snow, 0x40:ice, 0x50:ocean, 0x60:lake, 0x70:lake shore,
       0x80:ocean shore, 0x90,0xa0,0xb0:road, 0xc0:bridge.  These
       are ORed with 0x01: polygon center, 0x02: safe polygon
       center. */
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
    
    m:Matrix = new Matrix();
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

  /*
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
  TextField makeButton(String label, int x, int y, int width, callback) {
    TextField button = new TextField();
    TextFormat format = new TextFormat();
    format.font = "Arial";
    format.align = 'center';
    button.defaultTextFormat = format;
    button.text = label;
    button.selectable = false;
    button.x = x;
    button.y = y;
    button.width = width;
    button.height = 20;
    if (callback != null) {
      button.background = true;
      button.backgroundColor = 0xffffcc;
      button.addEventListener(MouseEvent.CLICK, callback);
    }
    return button;
  }

  
  addIslandShapeButtons() {
    int y = 4;
    islandShapeLabel:TextField = makeButton("Island Shape:", 25, y, 150, null);

    seedLabel:TextField = makeButton("Shape #", 20, y+22, 50, null);
    
    islandSeedInput = makeButton(islandSeedInitial, 70, y+22, 54, null);
    islandSeedInput.background = true;
    islandSeedInput.backgroundColor = 0xccddcc;
    islandSeedInput.selectable = true;
    islandSeedInput.type = TextFieldType.INPUT;
    islandSeedInput.addEventListener(KeyboardEvent.KEY_UP, (KeyboardEvent e) {
        if (e.keyCode == 13) {
          go(islandType, pointType, numPoints);
        }
      });

    markActiveIslandShape(String newIslandType) {
      mapTypes[islandType].backgroundColor = 0xffffcc;
      mapTypes[newIslandType].backgroundColor = 0xffff00;
    }
    
    Function setIslandTypeTo(String type){
      return(Event e) {
        markActiveIslandShape(type);
        go(type, pointType, numPoints);
      };
    }
    
    mapTypes:Object = {
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
                                     ( (Math.random()*100000).toFixed(0)
                                       + "-"
                                       + (1 + Math.floor(9*Math.random())).toFixed(0) );
                                   go(islandType, pointType, numPoints);
                                 }));
    controls.addChild(mapTypes.Radial);
    controls.addChild(mapTypes.Perlin);
    controls.addChild(mapTypes.Square);
    controls.addChild(mapTypes.Blob);
  }


  addPointSelectionButtons() {
    
    Map pointTypes;
    
    markActivePointSelection(String newPointType) {
      pointTypes[pointType].backgroundColor = 0xffffcc;
      pointTypes[newPointType].backgroundColor = 0xffff00;
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

    pointTypeLabel:TextField = makeButton("Point Selection:", 25, y+100, 150, null);
    controls.addChild(pointTypeLabel);
    controls.addChild(pointTypes.Random);
    controls.addChild(pointTypes.Relaxed);
    controls.addChild(pointTypes.Square);
    controls.addChild(pointTypes.Hexagon);

    Map pointCounts;
    
    markActiveNumPoints(int newNumPoints) {
      pointCounts[""+numPoints].backgroundColor = 0xffffcc;
      pointCounts[""+newNumPoints].backgroundColor = 0xffff00;
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
      views[mapMode].backgroundColor = 0xffffcc;
      views[mode].backgroundColor = 0xffff00;
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
    
    controls.addChild(views.biome);
    controls.addChild(views.smooth);
    controls.addChild(views.slopes);
    controls.addChild(views.elevation);
    controls.addChild(views.moisture);
    controls.addChild(views.polygons);
    controls.addChild(views.watersheds);
  }


  addMiscLabels() {
    controls.addChild(makeButton("Distribution:", 50, 180, 100, null));
    statusBar = makeButton("", SIZE/2-50, 10, 100, null);
    addChild(statusBar);
  }

             
  addExportButtons() {
    num y = 450;
    controls.addChild(makeButton("Export byte arrays:", 25, y, 150, null));
             
    controls.addChild(makeButton("Elevation", 50, y+22, 100,
                        (Event e) {
                          new FileReference().save(makeExport('elevation'), 'elevation.data');
                        }));
    controls.addChild(makeButton("Moisture", 50, y+44, 100,
                        (Event e) {
                          new FileReference().save(makeExport('moisture'), 'moisture.data');
                        }));
    controls.addChild(makeButton("Overrides", 50, y+66, 100,
                        (Event e) {
                          new FileReference().save(makeExport('overrides'), 'overrides.data');
                        }));

    controls.addChild(makeButton("Export:", 25, y+100, 50, null));
    controls.addChild(makeButton("XML", 77, y+100, 35,
                        (Event e) {
                          new FileReference().save(exportPolygons(), 'map.xml');
                        }));
    controls.addChild(makeButton("PNG", 114, y+100, 35,
                        (Event e) {
                          new FileReference().save(exportPng(), 'map.png');
                        }));
  }
  
}
