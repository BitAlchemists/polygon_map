import 'dart:html' as html;
import 'package:stagexl/stagexl.dart';
import "package:polygon_map/mapgen2/mapgen2.dart";
import "package:polygon_map/stagexl_plus/stagexl_plus.dart";

void main() {

  // setup the Stage and RenderLoop
  var canvas = html.querySelector('#stage');
  var stage = new Stage(canvas);
  var renderLoop = new RenderLoop();
  renderLoop.addStage(stage);
  
  stage.scaleMode = StageScaleMode.NO_SCALE;
  stage.align = StageAlign.TOP_LEFT;
  /*
  BitmapData perlin = new BitmapData(8,8);
  perlinNoise(perlin, 64, 64, 8, 234, false, true);
  Bitmap bitmap = new Bitmap(perlin);
  bitmap.addTo(stage);
  
   */
  
  mapgen2 map = new mapgen2();
  stage.addChild(map);
  map.go(map.islandType, map.pointType, map.numPoints);
  /*
   */
}
