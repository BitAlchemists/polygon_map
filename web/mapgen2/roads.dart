// Place roads on the polygonal island map roughly following contour lines.
// Author: amitp@cs.stanford.edu
// License: MIT


part of mapgen2;


class Roads {
 // The road array marks the edges that are roads.  The mark is 1,
 // 2, or 3, corresponding to the three contour levels. Note that
 // these are sparse arrays, only filled in where there are roads.
 List road;  // edge index -> int contour level
 List roadConnections;  // center index -> array of Edges with roads

 Roads() {
   road = [];
   roadConnections = [];
 }

 // We want to mark different elevation zones so that we can draw
 // island-circling roads that divide the areas.
 createRoads(WorldMap map) {
   // Oceans and coastal polygons are the lowest contour zone
   // (1). Anything connected to contour level K, if it's below
   // elevation threshold K, or if it's water, gets contour level
   // K.  (2) Anything not assigned a contour level, and connected
   // to contour level K, gets contour level K+1.
   List queue = [];
   Center p;
   Corner q;
   Center r;
   Edge edge;
   int newLevel;
   List elevationThresholds = [0, 0.05, 0.37, 0.64];
   List cornerContour = [];  // corner index -> int contour level
   List centerContour = [];  // center index -> int contour level
 
   for(p in map.centers) {
       if (p.coast || p.ocean) {
         centerContour[p.index] = 1;
         queue.push(p);
       }
     }
   
   while (queue.length > 0) {
     p = queue.shift();
     for(r in p.neighbors) {
         newLevel = centerContour[p.index] || 0;
         while (r.elevation > elevationThresholds[newLevel] && !r.water) {
           // NOTE: extend the contour line past bodies of
           // water so that roads don't terminate inside lakes.
           newLevel += 1;
         }
         if (newLevel < (centerContour[r.index] || 999)) {
           centerContour[r.index] = newLevel;
           queue.push(r);
         }
       }
   }

   // A corner's contour level is the MIN of its polygons
   for(p in map.centers) {
       for(q in p.corners) {
           cornerContour[q.index] = Math.min(cornerContour[q.index] || 999,
                                             centerContour[p.index] || 999);
         }
     }

   // Roads go between polygons that have different contour levels
   for(p in map.centers) {
       for(edge in p.borders) {
           if (edge.v0 && edge.v1
               && cornerContour[edge.v0.index] != cornerContour[edge.v1.index]) {
             road[edge.index] = Math.min(cornerContour[edge.v0.index],
                                         cornerContour[edge.v1.index]);
             if (!roadConnections[p.index]) {
               roadConnections[p.index] = [];
             }
             roadConnections[p.index].push(edge);
           }
         }
     }
 }
 
}


