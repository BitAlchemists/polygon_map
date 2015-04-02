part of delaunay;

/**
   * The line segment connecting the two Sites is part of the Delaunay triangulation;
   * the line segment connecting the two Vertices is part of the Voronoi diagram
   * @author ashaw
   * 
   **/
  class Edge
  {
    static List<Edge> _pool = new List<Edge>();

    /**
     * This is the only way to create a new Edge 
     * @param site0
     * @param site1
     * @return 
     * 
     **/
    static Edge createBisectingEdge(Site site0, Site site1)
    {
      num dx, dy, absdx, absdy;
      num a, b, c;
    
      dx = site1.x - site0.x;
      dy = site1.y - site0.y;
      absdx = dx > 0 ? dx : -dx;
      absdy = dy > 0 ? dy : -dy;
      c = site0.x * dx + site0.y * dy + (dx * dx + dy * dy) * 0.5;
      if (absdx > absdy)
      {
        a = 1.0; b = dy/dx; c /= dx;
      }
      else
      {
        b = 1.0; a = dx/dy; c /= dy;
      }
      
      Edge edge = Edge.create();
    
      edge.leftSite = site0;
      edge.rightSite = site1;
      site0.addEdge(edge);
      site1.addEdge(edge);
      
      edge._leftVertex = null;
      edge._rightVertex = null;
      
      edge.a = a; edge.b = b; edge.c = c;
      //trace("createBisectingEdge: a ", edge.a, "b", edge.b, "c", edge.c);
      
      return edge;
    }

    static Edge create()
    {
      Edge edge;
      if (_pool.length > 0)
      {
        edge = _pool.removeLast();
        edge.init();
      }
      else
      {
        edge = new Edge._internal();
      }
      return edge;
    }
    
    static Sprite LINESPRITE = new Sprite();
    static Graphics GRAPHICS = LINESPRITE.graphics;
    
    BitmapData _delaunayLineBmp;
    BitmapData get delaunayLineBmp
    {
      if (_delaunayLineBmp == null)
      {
        _delaunayLineBmp = makeDelaunayLineBmp();
      }
      return _delaunayLineBmp;
    }
    
    // making this available to Voronoi; running out of memory in AIR so I cannot cache the bmp
    BitmapData makeDelaunayLineBmp()
    {
      Point p0 = leftSite.coord;
      Point p1 = rightSite.coord;
      
      GRAPHICS.clear();
      // clear() resets line style back to undefined!
//      GRAPHICS.lineStyle(0, 0, 1.0, false, LineScaleMode.NONE, CapsStyle.BUTT); //TODO: evaluate CapsStyle
      GRAPHICS.moveTo(p0.x, p0.y);
      GRAPHICS.lineTo(p1.x, p1.y);
      GRAPHICS.strokeColor(0xff000000, 0.0);
            
      
      int w = Math.max(p0.x, p1.x).ceil();
      if (w < 1)
      {
        w = 1;
      }
      int h = Math.max(p0.y, p1.y).ceil();
      if (h < 1)
      {
        h = 1;
      }
      BitmapData bmp = new BitmapData(w, h, true, 0);
      bmp.draw(LINESPRITE);
      return bmp;
    }

    LineSegment delaunayLine()
    {
      // draw a line connecting the input Sites for which the edge is a bisector:
      return new LineSegment(leftSite.coord, rightSite.coord);
    }

    LineSegment voronoiEdge()
    {
      if (!visible) return new LineSegment(null, null);
      return new LineSegment(_clippedVertices[LR.LEFT],
                             _clippedVertices[LR.RIGHT]);
    }

    static int _nedges = 0;
    
    static Edge DELETED = new Edge._internal();
    
    // the equation of the edge: ax + by = c
    num a, b, c;
    
    // the two Voronoi vertices that the edge connects
    //    (if one of them is null, the edge extends to infinity)
    Vertex _leftVertex;
    Vertex get leftVertex
    {
      return _leftVertex;
    }
    Vertex _rightVertex;
    Vertex get rightVertex
    {
      return _rightVertex;
    }
    Vertex vertex(LR leftRight)
    {
      return (leftRight == LR.LEFT) ? _leftVertex : _rightVertex;
    }
    setVertex(LR leftRight, Vertex v)
    {
      if (leftRight == LR.LEFT)
      {
        _leftVertex = v;
      }
      else
      {
        _rightVertex = v;
      }
    }
    
    bool isPartOfConvexHull()
    {
      return (_leftVertex == null || _rightVertex == null);
    }
    
    num sitesDistance()
    {
      return Point.distance(leftSite.coord, rightSite.coord);
    }
    
    static num compareSitesDistances_MAX(Edge edge0, Edge edge1)
    {
      num length0 = edge0.sitesDistance();
      num length1 = edge1.sitesDistance();
      if (length0 < length1)
      {
        return 1;
      }
      if (length0 > length1)
      {
        return -1;
      }
      return 0;
    }
    
    static num compareSitesDistances(Edge edge0, Edge edge1)
    {
      return - compareSitesDistances_MAX(edge0, edge1);
    }
    
    // Once clipVertices() is called, this Map will hold two Points
    // representing the clipped coordinates of the left and right ends...
    Map _clippedVertices;
    Map get clippedEnds
    {
      return _clippedVertices;
    }
    // unless the entire Edge is outside the bounds.
    // In that case visible will be false:
    bool get visible
    {
      return _clippedVertices != null;
    }
    
    // the two input Sites for which this Edge is a bisector:
    Map _sites;
    set leftSite(Site s)
    {
      _sites[LR.LEFT] = s;
    }
    Site get leftSite
    {
      return _sites[LR.LEFT];
    }
    set rightSite(Site s)
    {
      _sites[LR.RIGHT] = s;
    }
    Site get rightSite
    {
      return _sites[LR.RIGHT] as Site;
    }
    Site site(LR leftRight)
    {
      return _sites[leftRight] as Site;
    }
    
    int _edgeIndex;
    
    dispose()
    {
      if (_delaunayLineBmp != null)
      {
        _delaunayLineBmp = null;
      }
      _leftVertex = null;
      _rightVertex = null;
      if (_clippedVertices != null)
      {
        _clippedVertices[LR.LEFT] = null;
        _clippedVertices[LR.RIGHT] = null;
        _clippedVertices = null;
      }
      _sites[LR.LEFT] = null;
      _sites[LR.RIGHT] = null;
      _sites = null;
      
      _pool.add(this);
    }

    Edge._internal()
    {
      _edgeIndex = _nedges++;
      init();
    }
    
    init()
    { 
      _sites = new Map();
    }
    
    String toString()
    {
      return "Edge " + _edgeIndex.toString() + "; sites " + _sites[LR.LEFT] + ", " + _sites[LR.RIGHT]
          + "; endVertices " + (_leftVertex != null ? _leftVertex.vertexIndex : "null") + ", "
           + (_rightVertex != null ? _rightVertex.vertexIndex : "null") + "::";
    }

    /**
     * Set _clippedVertices to contain the two ends of the portion of the Voronoi edge that is visible
     * within the bounds.  If no part of the Edge falls within the bounds, leave _clippedVertices null. 
     * @param bounds
     * 
     */
    clipVertices(Rectangle bounds)
    {
      num xmin = bounds.x;
      num ymin = bounds.y;
      num xmax = bounds.right;
      num ymax = bounds.bottom;
      
      Vertex vertex0, vertex1;
      num x0, x1, y0, y1;
      
      if (a == 1.0 && b >= 0.0)
      {
        vertex0 = _rightVertex;
        vertex1 = _leftVertex;
      }
      else 
      {
        vertex0 = _leftVertex;
        vertex1 = _rightVertex;
      }
    
      if (a == 1.0)
      {
        y0 = ymin;
        if (vertex0 != null && vertex0.y > ymin)
        {
           y0 = vertex0.y;
        }
        if (y0 > ymax)
        {
          return;
        }
        x0 = c - b * y0;
        
        y1 = ymax;
        if (vertex1 != null && vertex1.y < ymax)
        {
          y1 = vertex1.y;
        }
        if (y1 < ymin)
        {
          return;
        }
        x1 = c - b * y1;
        
        if ((x0 > xmax && x1 > xmax) || (x0 < xmin && x1 < xmin))
        {
          return;
        }
        
        if (x0 > xmax)
        {
          x0 = xmax; y0 = (c - x0)/b;
        }
        else if (x0 < xmin)
        {
          x0 = xmin; y0 = (c - x0)/b;
        }
        
        if (x1 > xmax)
        {
          x1 = xmax; y1 = (c - x1)/b;
        }
        else if (x1 < xmin)
        {
          x1 = xmin; y1 = (c - x1)/b;
        }
      }
      else
      {
        x0 = xmin;
        if (vertex0 != null && vertex0.x > xmin)
        {
          x0 = vertex0.x;
        }
        if (x0 > xmax)
        {
          return;
        }
        y0 = c - a * x0;
        
        x1 = xmax;
        if (vertex1 != null && vertex1.x < xmax)
        {
          x1 = vertex1.x;
        }
        if (x1 < xmin)
        {
          return;
        }
        y1 = c - a * x1;
        
        if ((y0 > ymax && y1 > ymax) || (y0 < ymin && y1 < ymin))
        {
          return;
        }
        
        if (y0 > ymax)
        {
          y0 = ymax; x0 = (c - y0)/a;
        }
        else if (y0 < ymin)
        {
          y0 = ymin; x0 = (c - y0)/a;
        }
        
        if (y1 > ymax)
        {
          y1 = ymax; x1 = (c - y1)/a;
        }
        else if (y1 < ymin)
        {
          y1 = ymin; x1 = (c - y1)/a;
        }
      }

      _clippedVertices = new Map();
      if (vertex0 == _leftVertex)
      {
        _clippedVertices[LR.LEFT] = new Point(x0, y0);
        _clippedVertices[LR.RIGHT] = new Point(x1, y1);
      }
      else
      {
        _clippedVertices[LR.RIGHT] = new Point(x0, y0);
        _clippedVertices[LR.LEFT] = new Point(x1, y1);
      }
    }

  }