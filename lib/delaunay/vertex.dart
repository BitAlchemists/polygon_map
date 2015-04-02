part of delaunay;

class Vertex extends ICoord
{
  static Vertex VERTEX_AT_INFINITY = new Vertex._internal(double.NAN, double.NAN);
  
  static List<Vertex> _pool = new List<Vertex>();
  static Vertex create(num x, num y)
  {
    if (x.isNaN || y.isNaN)
    {
      return VERTEX_AT_INFINITY;
    }
    if (_pool.length > 0)
    {
      return _pool.removeLast().init(x, y);
    }
    else
    {
      return new Vertex._internal(x, y);
    }
  }


  static int _nvertices = 0;
  
  Point _coord;
  Point get coord
  {
    return _coord;
  }
  int _vertexIndex;
  int get vertexIndex
  {
    return _vertexIndex;
  }
  
  Vertex._internal(num x, num y)
  {   
    init(x, y);
  }
  
  Vertex init(num x, num y)
  {
    _coord = new Point(x, y);
    return this;
  }
  
  dispose()
  {
    _coord = null;
    _pool.add(this);
  }
  
  setIndex()
  {
    _vertexIndex = _nvertices++;
  }
  
  String toString()
  {
    return "Vertex (" + _vertexIndex.toString() + ")";
  }

  /**
   * This is the only way to make a Vertex
   * 
   * @param halfedge0
   * @param halfedge1
   * @return 
   * 
   **/
  static Vertex intersect(Halfedge halfedge0, Halfedge halfedge1)
  {
    Edge edge0, edge1, edge;
    Halfedge halfedge;
    num determinant, intersectionX, intersectionY;
    bool rightOfSite;
  
    edge0 = halfedge0.edge;
    edge1 = halfedge1.edge;
    if (edge0 == null || edge1 == null)
    {
      return null;
    }
    if (edge0.rightSite == edge1.rightSite)
    {
      return null;
    }
  
    determinant = edge0.a * edge1.b - edge0.b * edge1.a;
    if (-1.0e-10 < determinant && determinant < 1.0e-10)
    {
      // the edges are parallel
      return null;
    }
  
    intersectionX = (edge0.c * edge1.b - edge1.c * edge0.b)/determinant;
    intersectionY = (edge1.c * edge0.a - edge0.c * edge1.a)/determinant;
  
    if (Voronoi.compareByYThenX(edge0.rightSite, edge1.rightSite) < 0)
    {
      halfedge = halfedge0; edge = edge0;
    }
    else
    {
      halfedge = halfedge1; edge = edge1;
    }
    rightOfSite = intersectionX >= edge.rightSite.x;
    if ((rightOfSite && halfedge.leftRight == LR.LEFT)
    ||  (!rightOfSite && halfedge.leftRight == LR.RIGHT))
    {
      return null;
    }
  
    return Vertex.create(intersectionX, intersectionY);
  }
  
  num get x
  {
    return _coord.x;
  }
  num get y
  {
    return _coord.y;
  }
  
}