import 'dart:html' as html;
import 'package:stagexl/stagexl.dart';
import "package:polygon_map/mapgen2/mapgen2.dart";

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
  
  stage.scaleMode = StageScaleMode.NO_SCALE;
  stage.align = StageAlign.TOP_LEFT;
  
  mapgen2 map = new mapgen2();
  stage.addChild(map);
  map.go(map.islandType, map.pointType, map.numPoints);
}
