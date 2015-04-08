library stagexl_plus;

import "dart:math" as Math;
import "package:stagexl/stagexl.dart" as stagexl;

part "perlin_noise.dart";

perlinNoise(stagexl.BitmapData bitmapData, num baseX, num baseY, num numOctaves, num randomSeed, bool stitch, bool fractalNoise, [num channelOptions, bool grayScale, Map offsets]){
  OptimizedPerlin perlin = new OptimizedPerlin();
  perlin.octaves = numOctaves;
  perlin.seed = randomSeed;
  //TODO: not all params are used
  perlin.fill(bitmapData, baseX, baseY);  
}

noise(stagexl.BitmapData bitmapData, int randomSeed, [int low = 0, int high = 255, int channelOptions, bool grayScale]){
  Math.Random random = new Math.Random(randomSeed);
  
  int randomMax = high - low;
  
  if(grayScale){
    for(int x = 0; x < bitmapData.width; x++){
      for(int y = 0; y < bitmapData.height; y++){
        int g = low + random.nextInt(randomMax);
        int color = 0;
        color += ((channelOptions & 8) != 0) ? g << 24 : 0xff << 24;
        color += channelOptions & 1 != 0 ? g << 16 : 0;
        color += channelOptions & 2 != 0 ? g << 8 : 0;
        color += channelOptions & 4 != 0 ? g : 0;
            
        bitmapData.setPixel32(x, y, color);
      }
    }
  }
  else
  {
    for(int x = 0; x < bitmapData.width; x++){
      for(int y = 0; y < bitmapData.height; y++){
        int a = low + random.nextInt(randomMax);
        int r = low + random.nextInt(randomMax);
        int g = low + random.nextInt(randomMax);
        int b = low + random.nextInt(randomMax);
        int color = 0;
        color += ((channelOptions & 8) != 0) ? a << 24 : 0xff << 24;
        color += channelOptions & 1 != 0 ? r << 16 : 0;
        color += channelOptions & 2 != 0 ? g << 8 : 0;
        color += channelOptions & 4 != 0 ? b : 0;
            
        bitmapData.setPixel32(x, y, color);
      }
    }
  }
  
  return bitmapData;
}