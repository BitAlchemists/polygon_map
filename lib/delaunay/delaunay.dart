library delaunay;

// http://nodename.github.io/as3delaunay/
import "package:disposable/disposable.dart";
import "package:stagexl/stagexl.dart";
import "package:polygon_map/geom/geom.dart";
import "dart:math" as Math;

part "edge.dart";
part "voronoi.dart";
part "halfedge.dart";
part "site_list.dart";
part "lr.dart";
part "vertex.dart";
part "i_coord.dart";
part "site.dart";
part "edge_reorderer.dart";
part "triangle.dart";

Math.Random random = new Math.Random();

List<Edge> selectEdgesForSitePoint(Point coord, List<Edge> edgesToTest)
{
  bool myTest(Edge edge)
  {
    return ((edge.leftSite != null && edge.leftSite.coord == coord)
    ||  (edge.rightSite != null && edge.rightSite.coord == coord));
  }

  return edgesToTest.where(myTest);
}

List<Edge> selectNonIntersectingEdges(BitmapData keepOutMask, List<Edge> edgesToTest)
{  
  if (keepOutMask == null)
  {
    return edgesToTest;
  }
  
  
  Point zeroPoint = new Point(0.0, 0.0);
  
  bool myTest(Edge edge)
  {
    BitmapData delaunayLineBmp = edge.makeDelaunayLineBmp();
    Bitmap keepOutMaskBitmap = new Bitmap(keepOutMask);
    Bitmap delaunayLineBitmap = new Bitmap(delaunayLineBmp);
    //TODO: evaluate
    bool notIntersecting = keepOutMaskBitmap.hitTestInput(zeroPoint.x, zeroPoint.y) != null && delaunayLineBitmap.hitTestInput(zeroPoint.x, zeroPoint.y) != null;
    return notIntersecting;
  }
  
  return edgesToTest.where(myTest);
  
  
}

List<LineSegment> visibleLineSegments(List<Edge> edges)
{
  List<LineSegment> segments = new List<LineSegment>();

  for(Edge edge in edges)
  {
    if (edge.visible)
    {
      Point p1 = edge.clippedEnds[LR.LEFT];
      Point p2 = edge.clippedEnds[LR.RIGHT];
      segments.add(new LineSegment(p1, p2));
    }
  }
  
  return segments;
}