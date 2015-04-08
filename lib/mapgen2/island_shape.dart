part of mapgen2;

// Factory class to build the 'inside' that tells us whether
// a point should be on the island or in the water.
//import flash.geom.Point;
//import flash.display.BitmapData;
//import de.polygonal.math.PM_PRNG;
class IslandShape {
// This class has factory s for generating islands of
// different shapes. The factory returns a that takes a
// normalized point (x and y are -1 to +1) and returns true if the
// point should be on the island, and false if it should be water
// (lake or ocean).


// The radial island radius is based on overlapping sine waves 
static num ISLAND_FACTOR = 1.07;  // 1.0 means no small islands; 2.0 leads to a lot
static Function makeRadial(int seed){
  PM_PRNG islandRandom = new PM_PRNG();
  islandRandom.seed = seed;
  int bumps = islandRandom.nextIntRange(1, 6);
  num startAngle = islandRandom.nextDoubleRange(0, 2*Math.PI);
  num dipAngle = islandRandom.nextDoubleRange(0, 2*Math.PI);
  num dipWidth = islandRandom.nextDoubleRange(0.2, 0.7);
  
  bool inside(Point q) {
    num angle = Math.atan2(q.y, q.x);
    num length = 0.5 * (Math.max(q.x.abs(), q.y.abs()) + q.magnitude);

    num r1 = 0.5 + 0.40*Math.sin(startAngle + bumps*angle + Math.cos((bumps+3)*angle));
    num r2 = 0.7 - 0.20*Math.sin(startAngle + bumps*angle - Math.sin((bumps+2)*angle));
    if ((angle - dipAngle).abs() < dipWidth
        || (angle - dipAngle + 2*Math.PI).abs() < dipWidth
        || (angle - dipAngle - 2*Math.PI).abs() < dipWidth) {
      r1 = r2 = 0.2;
    }
    return  (length < r1 || (length > r1*ISLAND_FACTOR && length < r2));
  }

  return inside;
}


// The Perlin-based island combines perlin noise with the radius
static Function makePerlin(int seed){
  BitmapData perlin = new BitmapData(256, 256);
  stagexl_plus.perlinNoise(perlin, 64, 64, 8, seed, false, true);

  return (Point q) {
    num c = (perlin.getPixel(((q.x+1)*128).toInt(), ((q.y+1)*128).toInt()) & 0xff) / 255.0;
    return c > (0.3+0.3*q.magnitude*q.magnitude);
  };
}


// The square shape fills the entire space with land
static Function makeSquare(int seed){
 return (Point q) {
   return true;
 };
}


// The blob island is shaped like Amit's blob logo
static Function makeBlob(int seed){
 return (Point q) {
   bool eye1 = new Point(q.x-0.2, q.y/2+0.2).magnitude < 0.05;
   bool eye2 = new Point(q.x+0.2, q.y/2+0.2).magnitude < 0.05;
   bool body = q.magnitude < 0.8 - 0.18*Math.sin(5*Math.atan2(q.y, q.x));
   return body && !eye1 && !eye2;
 };
}

}