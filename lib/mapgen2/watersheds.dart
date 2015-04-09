// Define watersheds: if a drop of rain falls on any polygon, where
// does it exit the island? We follow the map corner downslope field.
// Author: amitp@cs.stanford.edu
// License: MIT

part of mapgen2;


class Watersheds {
 Map lowestCorner = {};  // polygon index -> corner index
 Map watersheds = {};  // polygon index -> corner index

 Watersheds();
 
 // We want to mark each polygon with the corner where water would
 // exit the island.
 createWatersheds(WorldMap map) {
   Center p;
   Corner q;
   Corner s;

   // Find the lowest corner of the polygon, and set that as the
   // exit point for rain falling on this polygon
   for(p in map.centers) {
       s = null;
       for(q in p.corners) {
           if (s == null || q.elevation < s.elevation) {
             s = q;
           }
         }
       lowestCorner[p.index] = (s == null)? -1 : s.index;
       watersheds[p.index] = (s == null)? -1 : (s.watershed == null)? -1 : s.watershed.index;
     }
 }
 
}

