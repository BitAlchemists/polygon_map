part of delaunay;

class Halfedge
{
  static List<Halfedge> _pool = new List<Halfedge>();
  static Halfedge create(Edge edge, LR lr)
  {
    if (_pool.length > 0)
    {
      return _pool.removeLast()._init(edge, lr);
    }
    else
    {
      return new Halfedge._internal(edge, lr);
    }
  }
  
  static Halfedge createDummy()
  {
    return create(null, null);
  }
  
  Halfedge edgeListLeftNeighbor, edgeListRightNeighbor;
  Halfedge nextInPriorityQueue;
  
  Edge edge;
  LR leftRight;
  Vertex vertex;
  
  // the vertex's y-coordinate in the transformed Voronoi space V*
  double ystar;

  Halfedge._internal([Edge edge = null, LR lr = null])
  {
    _init(edge, lr);
  }
  
  Halfedge _init(Edge edge, LR lr)
  {
    this.edge = edge;
    leftRight = lr;
    nextInPriorityQueue = null;
    vertex = null;
    ystar = 0.0;
    return this;
  }
  
  String toString()
  {
    return "Halfedge (leftRight: " + leftRight.toString() + "; vertex: " + vertex.toString() + ")";
  }
  
  dispose()
  {
    if (edgeListLeftNeighbor != null || edgeListRightNeighbor != null)
    {
      // still in EdgeList
      return;
    }
    if (nextInPriorityQueue != null)
    {
      // still in PriorityQueue
      return;
    }
    edge = null;
    leftRight = null;
    vertex = null;
    _pool.add(this);
  }
  
  reallyDispose()
  {
    edgeListLeftNeighbor = null;
    edgeListRightNeighbor = null;
    nextInPriorityQueue = null;
    edge = null;
    leftRight = null;
    vertex = null;
    _pool.add(this);
  }

  bool isLeftOf(Point p)
  {
    Site topSite;
    bool rightOfSite, above, fast;
    num dxp, dyp, dxs, t1, t2, t3, yl;
    
    topSite = edge.rightSite;
    rightOfSite = p.x > topSite.x;
    if (rightOfSite && this.leftRight == LR.LEFT)
    {
      return true;
    }
    if (!rightOfSite && this.leftRight == LR.RIGHT)
    {
      return false;
    }
    
    if (edge.a == 1.0)
    {
      dyp = p.y - topSite.y;
      dxp = p.x - topSite.x;
      fast = false;
      if ((!rightOfSite && edge.b < 0.0) || (rightOfSite && edge.b >= 0.0) )
      {
        above = dyp >= edge.b * dxp;  
        fast = above;
      }
      else 
      {
        above = p.x + p.y * edge.b > edge.c;
        if (edge.b < 0.0)
        {
          above = !above;
        }
        if (!above)
        {
          fast = true;
        }
      }
      if (!fast)
      {
        dxs = topSite.x - edge.leftSite.x;
        above = edge.b * (dxp * dxp - dyp * dyp) <
                dxs * dyp * (1.0 + 2.0 * dxp/dxs + edge.b * edge.b);
        if (edge.b < 0.0)
        {
          above = !above;
        }
      }
    }
    else  /* edge.b == 1.0 */
    {
      yl = edge.c - edge.a * p.x;
      t1 = p.y - yl;
      t2 = p.x - topSite.x;
      t3 = yl - topSite.y;
      above = t1 * t1 > t2 * t2 + t3 * t3;
    }
    return this.leftRight == LR.LEFT ? above : !above;
  }

}