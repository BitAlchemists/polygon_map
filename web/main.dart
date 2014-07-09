import 'dart:html' as html;
import 'package:stagexl/stagexl.dart';


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
