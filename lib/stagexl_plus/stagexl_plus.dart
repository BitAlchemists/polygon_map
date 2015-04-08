library stagexl_plus;

import "dart:math" as Math;
import "package:stagexl/stagexl.dart" as stagexl;

part "perlin_noise.dart";

stagexl.BitmapData perlinNoise(stagexl.BitmapData bitmapData, num baseX, num baseY, num numOctaves, num randomSeed, bool stitch, bool fractalNoise, [num channelOptions, bool grayScale, Map offsets]){
  OptimizedPerlin perlin = new OptimizedPerlin();
  perlin.octaves = numOctaves;
  perlin.seed = randomSeed;
  //TODO: not all params are used
  bitmapData = new stagexl.BitmapData(bitmapData.width, bitmapData.height);
  perlin.fill(bitmapData, baseX, baseY);
  
  return bitmapData;
}

stagexl.BitmapData noise(stagexl.BitmapData bitmapData, num randomSeed, [num low, num high, num channelOptions, bool grayScale]){
  return bitmapData;
  //TODO: implement
}