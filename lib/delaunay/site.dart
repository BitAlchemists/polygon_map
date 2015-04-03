part of delaunay;

class Site implements ICoord
{
  static List<Site> _pool = new List<Site>();
  static Site create(Point p, int index, num weight, int color)
  {
    if (_pool.length > 0)
    {
      return _pool.removeLast().init(p, index, weight, color);
    }
    else
    {
      return new Site._internal(p, index, weight, color);
    }
  }
  
  static sortSites(List<Site> sites)
  {
    sites.sort(Site.compare);
  }

  /**
   * sort sites on y, then x, coord
   * also changesite's _siteIndex to match its new position in the list
   * so the _siteIndex can be used to identify the site for nearest-neighbor queries
   * 
   * haha "also" - means more than one responsibility...
   * 
   */
  static num compare(Site s1, Site s2)
  {
    int returnValue = Voronoi.compareByYThenX(s1, s2);
    
    // swap _siteIndex values if necessary to match new ordering:
    int tempIndex;
    if (returnValue == -1)
    {
      if (s1._siteIndex > s2._siteIndex)
      {
        tempIndex = s1._siteIndex;
        s1._siteIndex = s2._siteIndex;
        s2._siteIndex = tempIndex;
      }
    }
    else if (returnValue == 1)
    {
      if (s2._siteIndex > s1._siteIndex)
      {
        tempIndex = s2._siteIndex;
        s2._siteIndex = s1._siteIndex;
        s1._siteIndex = tempIndex;
      }
      
    }
    
    return returnValue;
  }


  static const num EPSILON = .005;
  static bool closeEnough(Point p0, Point p1)
  {
    return Point.distance(p0, p1) < EPSILON;
  }
      
  Point _coord;
  Point get coord
  {
    return _coord;
  }
  
  int color;
  num weight;
  
  int _siteIndex;
  
  // the edges that define this Site's Voronoi region:
  List<Edge> _edges;
  List<Edge> get edges
  {
    return _edges;
  }
  // which end ofedge hooks up with the previous edge in _edges:
  List<LR> _edgeOrientations;
  // ordered list of points that define the region clipped to bounds:
  List<Point> _region;

  Site._internal(Point p, int index, num weight, int color)
  {
    init(p, index, weight, color);
  }
  
  Site init(Point p, int index, num weight, int color)
  {
    _coord = p;
    _siteIndex = index;
    this.weight = weight;
    this.color = color;
    _edges = new List<Edge>();
    _region = null;
    return this;
  }
  
  String toString()
  {
    return "Site " + _siteIndex.toString() + ": " + coord.toString();
  }
  
  move(Point p)
  {
    clear();
    _coord = p;
  }
  
  dispose()
  {
    _coord = null;
    clear();
    _pool.add(this);
  }
  
  clear()
  {
    if (_edges != null)
    {
      _edges.length = 0;
      _edges = null;
    }
    if (_edgeOrientations != null)
    {
      _edgeOrientations.length = 0;
      _edgeOrientations = null;
    }
    if (_region != null)
    {
      _region.length = 0;
      _region = null;
    }
  }
  
  addEdge(Edge edge)
  {
    _edges.add(edge);
  }
  
  Edge nearestEdge()
  {
    _edges.sort(Edge.compareSitesDistances);
    return _edges[0];
  }
  
  List<Site> neighborSites()
  {
    if (_edges == null || _edges.length == 0)
    {
      return new List<Site>();
    }
    if (_edgeOrientations == null)
    { 
      reorderEdges();
    }
    List<Site> list = new List<Site>();
    Edge edge;
    for(edge in _edges)
    {
      list.add(neighborSite(edge));
    }
    return list;
  }
    
  Site neighborSite(Edge edge)
  {
    if (this == edge.leftSite)
    {
      return edge.rightSite;
    }
    if (this == edge.rightSite)
    {
      return edge.leftSite;
    }
    return null;
  }
  
  List<Point> region(Rectangle clippingBounds)
  {
    if (_edges == null || _edges.length == 0)
    {
      return new List<Point>();
    }
    if (_edgeOrientations == null)
    { 
      reorderEdges();
      _region = clipToBounds(clippingBounds);
      /** TODO: reimplement
      if ((new Polygon(_region)).winding() == Winding.CLOCKWISE)
      {
        _region = _region.reverse();
      }
      **/
    }
    return _region;
  }
  
  reorderEdges()
  {
    //trace("_edges:", _edges);
    EdgeReorderer reorderer = new EdgeReorderer(_edges, Vertex);
    _edges = reorderer.edges;
    //trace("reordered:", _edges);
    _edgeOrientations = reorderer.edgeOrientations;
    reorderer.dispose();
  }
  
  List<Point> clipToBounds(Rectangle bounds)
  {
    List<Point> points = new List<Point>();
    int n = _edges.length;
    int i = 0;
    Edge edge;
    while (i < n && !_edges[i].visible)
    {
      ++i;
    }
    
    if (i == n)
    {
      // no edges visible
      return new List<Point>();
    }
    edge = _edges[i];
    LR orientation = _edgeOrientations[i];
    points.add(edge.clippedEnds[orientation]);
    points.add(edge.clippedEnds[LR.other(orientation)]);
    
    for (int j = i + 1; j < n; ++j)
    {
      edge = _edges[j];
      if (edge.visible == false)
      {
        continue;
      }
      connect(points, j, bounds);
    }
    // close up the polygon by adding another corner point of the bounds if needed:
    connect(points, i, bounds, true);
    
    return points;
  }
  
  connect(List<Point> points, int j, Rectangle bounds, [bool closingUp = false])
  {
    Point rightPoint = points[points.length - 1];
    Edge newEdge = _edges[j];
    LR newOrientation = _edgeOrientations[j];
    // the point that  must be connected to rightPoint:
    Point newPoint = newEdge.clippedEnds[newOrientation];
    if (!closeEnough(rightPoint, newPoint))
    {
      // The points do not coincide, so they must have been clipped at the bounds;
      // see if they are on the same border of the bounds:
      if (rightPoint.x != newPoint.x
      &&  rightPoint.y != newPoint.y)
      {
        // They are on different borders of the bounds;
        // insert one or two corners of bounds as needed to hook them up:
        // (NOTE this will not be correct if the region should take up more than
        // half of the bounds rect, for then we will have gone the wrong way
        // around the bounds and included the smaller part rather than the larger)
        int rightCheck = BoundsCheck.check(rightPoint, bounds);
        int newCheck = BoundsCheck.check(newPoint, bounds);
        num px, py;
        if ((rightCheck & BoundsCheck.RIGHT) != 0)
        {
          px = bounds.right;
          if ((newCheck & BoundsCheck.BOTTOM) != null)
          {
            py = bounds.bottom;
            points.add(new Point(px, py));
          }
          else if ((newCheck & BoundsCheck.TOP) != 0)
          {
            py = bounds.top;
            points.add(new Point(px, py));
          }
          else if ((newCheck & BoundsCheck.LEFT) != 0)
          {
            if (rightPoint.y - bounds.top + newPoint.y - bounds.top < bounds.height)
            {
              py = bounds.top;
            }
            else
            {
              py = bounds.bottom;
            }
            points.add(new Point(px, py));
            points.add(new Point(bounds.left, py));
          }
        }
        else if ((rightCheck & BoundsCheck.LEFT) != 0)
        {
          px = bounds.left;
          if ((newCheck & BoundsCheck.BOTTOM) != 0)
          {
            py = bounds.bottom;
            points.add(new Point(px, py));
          }
          else if ((newCheck & BoundsCheck.TOP) != 0)
          {
            py = bounds.top;
            points.add(new Point(px, py));
          }
          else if ((newCheck & BoundsCheck.RIGHT) != 0)
          {
            if (rightPoint.y - bounds.top + newPoint.y - bounds.top < bounds.height)
            {
              py = bounds.top;
            }
            else
            {
              py = bounds.bottom;
            }
            points.add(new Point(px, py));
            points.add(new Point(bounds.right, py));
          }
        }
        else if ((rightCheck & BoundsCheck.TOP) != 0)
        {
          py = bounds.top;
          if ((newCheck & BoundsCheck.RIGHT) != 0)
          {
            px = bounds.right;
            points.add(new Point(px, py));
          }
          else if ((newCheck & BoundsCheck.LEFT) != 0)
          {
            px = bounds.left;
            points.add(new Point(px, py));
          }
          else if ((newCheck & BoundsCheck.BOTTOM) != 0)
          {
            if (rightPoint.x - bounds.left + newPoint.x - bounds.left < bounds.width)
            {
              px = bounds.left;
            }
            else
            {
              px = bounds.right;
            }
            points.add(new Point(px, py));
            points.add(new Point(px, bounds.bottom));
          }
        }
        else if ((rightCheck & BoundsCheck.BOTTOM) != 0)
        {
          py = bounds.bottom;
          if ((newCheck & BoundsCheck.RIGHT) != 0)
          {
            px = bounds.right;
            points.add(new Point(px, py));
          }
          else if ((newCheck & BoundsCheck.LEFT) != 0)
          {
            px = bounds.left;
            points.add(new Point(px, py));
          }
          else if ((newCheck & BoundsCheck.TOP) != 0)
          {
            if (rightPoint.x - bounds.left + newPoint.x - bounds.left < bounds.width)
            {
              px = bounds.left;
            }
            else
            {
              px = bounds.right;
            }
            points.add(new Point(px, py));
            points.add(new Point(px, bounds.top));
          }
        }
      }
      if (closingUp)
      {
        // newEdge's ends have already been added
        return;
      }
      points.add(newPoint);
    }
    Point newRightPoint = newEdge.clippedEnds[LR.other(newOrientation)];
    if (!closeEnough(points[0], newRightPoint))
    {
      points.add(newRightPoint);
    }
  }
              
  num get x
  {
    return _coord.x;
  }
  num get y
  {
    return _coord.y;
  }
  
  num dist(ICoord p)
  {
    return Point.distance(p.coord, this._coord);
  }

}


class BoundsCheck
{
  static const int TOP = 1;
  static const int BOTTOM = 2;
  static const int LEFT = 4;
  static const int RIGHT = 8;
  
  /**
   * 
   * @param point
   * @param bounds
   * @return an int with the appropriate bits set if the Point lies on the corresponding bounds lines
   * 
   */
  static int check(Point point, Rectangle bounds)
  {
    int value = 0;
    if (point.x == bounds.left)
    {
      value |= LEFT;
    }
    if (point.x == bounds.right)
    {
      value |= RIGHT;
    }
    if (point.y == bounds.top)
    {
      value |= TOP;
    }
    if (point.y == bounds.bottom)
    {
      value |= BOTTOM;
    }
    return value;
  }
}