part of delaunay;

/* ported to Dart by Tommi Enenkel (2015)
 * The author of this software is Steven Fortune.  Copyright (c) 1994 by AT&T
 * Bell Laboratories.
 * Permission to use, copy, modify, and distribute this software for any
 * purpose without fee is hereby granted, provided that this entire notice
 * is included in all copies of any software which is or includes a copy
 * or modification of this software and in all copies of the supporting
 * documentation for such software.
 * THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTY.  IN PARTICULAR, NEITHER THE AUTHORS NOR AT&T MAKE ANY
 * REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
 * OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
 */

class Voronoi
{
  SiteList _sites;
  Dictionary _sitesIndexedByLocation;
  List<Triangle> _triangles;
  List<Edge> _edges;

  
  // TODO generalize this so it doesn't have to be a rectangle;
  // then we can make the fractal voronois-within-voronois
  Rectangle _plotBounds;
  Rectangle get plotBounds
  {
    return _plotBounds;
  }
  
  dispose()
  {
    int i, n;
    if (_sites)
    {
      _sites.dispose();
      _sites = null;
    }
    if (_triangles)
    {
      n = _triangles.length;
      for (i = 0; i < n; ++i)
      {
        _triangles[i].dispose();
      }
      _triangles.length = 0;
      _triangles = null;
    }
    if (_edges)
    {
      n = _edges.length;
      for (i = 0; i < n; ++i)
      {
        _edges[i].dispose();
      }
      _edges.length = 0;
      _edges = null;
    }
    _plotBounds = null;
    _sitesIndexedByLocation = null;
  }
  
  Voronoi(List<Point> points, List<int> colors, Rectangle plotBounds)
  {
    _sites = new SiteList();
    _sitesIndexedByLocation = new Dictionary(true);
    addSites(points, colors);
    _plotBounds = plotBounds;
    _triangles = new List<Triangle>();
    _edges = new List<Edge>();
    fortunesAlgorithm();
  }
  
  addSites(List<Point> points, List<int> colors)
  {
    int length = points.length;
    for (int i = 0; i < length; ++i)
    {
      addSite(points[i], colors ? colors[i] : 0, i);
    }
  }
  
  addSite(Point p, int color, int index)
  {
    num weight = Math.random() * 100;
    Site site = Site.create(p, index, weight, color);
    _sites.push(site);
    _sitesIndexedByLocation[p] = site;
  }

              List<Edge> edges()
              {
                return _edges;
              }
        
  List<Point> region(Point p)
  {
    Site site = _sitesIndexedByLocation[p];
    if (!site)
    {
      return new List<Point>();
    }
    return site.region(_plotBounds);
  }

        // TODO: bug: if you call this before you call region(), something goes wrong :(
  List<Point> neighborSitesForSite(Point coord)
  {
    List<Point> points = new List<Point>();
    Site site = _sitesIndexedByLocation[coord];
    if (!site)
    {
      return points;
    }
    List<Site> sites = site.neighborSites();
    Site neighbor;
    for(neighbor in sites)
    {
      points.push(neighbor.coord);
    }
    return points;
  }

  List<Circle> circles
  {
    return _sites.circles();
  }
  
  Vector<LineSegment> voronoiBoundaryForSite(Point coord)
  {
    return visibleLineSegments(selectEdgesForSitePoint(coord, _edges));
  }

  List<LineSegment> delaunayLinesForSite(Point coord)
  {
    return delaunayLinesForEdges(selectEdgesForSitePoint(coord, _edges));
  }
  
  List<LineSegment> voronoiDiagram()
  {
    return visibleLineSegments(_edges);
  }
  
  List<LineSegment> delaunayTriangulation([BitmapData keepOutMask = null])
  {
    return delaunayLinesForEdges(selectNonIntersectingEdges(keepOutMask, _edges));
  }
  
  List<LineSegment> hull()
  {
    return delaunayLinesForEdges(hullEdges());
  }
  
  List<Edge> _hullEdges()
  {
    bool myTest(Edge edge, int index, List<Edge> edges)
    {
      return (edge.isPartOfConvexHull());
    }
    
    return _edges.filter(myTest);
  }

  List<Point> hullPointsInOrder()
  {
    List<Edge> hullEdges = this.hullEdges();
    
    List<Point> points = new List<Point>();
    if (hullEdges.length == 0)
    {
      return points;
    }
    
    reorderer:EdgeReorderer = new EdgeReorderer(hullEdges, Site);
    hullEdges = reorderer.edges;
    List<LR> orientations = reorderer.edgeOrientations;
    reorderer.dispose();
    
    orientation:LR;

    n:int = hullEdges.length;
    for (int i = 0; i < n; ++i)
    {
      Edge edge = hullEdges[i];
      orientation = orientations[i];
      points.push(edge.site(orientation).coord);
    }
    return points;
  }
  
  spanningTree(type:String = "minimum", keepOutMask:BitmapData = null):List<LineSegment>
  {
    List<Edge> edges = selectNonIntersectingEdges(keepOutMask, _edges);
    segments:List<LineSegment> = delaunayLinesForEdges(edges);
    return kruskal(segments, type);
  }

  regions():List<List<Point>>
  {
    return _sites.regions(_plotBounds);
  }
  
  siteColors(referenceImage:BitmapData = null):List<uint>
  {
    return _sites.siteColors(referenceImage);
  }
  
  /**
   * 
   * @param proximityMap a BitmapData whose regions are filled with the site index values; see PlanePointsCanvas::fillRegions()
   * @param x
   * @param y
   * @return coordinates of nearest Site to (x, y)
   * 
   */
  nearestSitePoint(proximityMap:BitmapData, x:Number, y:Number):Point
  {
    return _sites.nearestSitePoint(proximityMap, x, y);
  }
  
  siteCoords():List<Point>
  {
    return _sites.siteCoords();
  }

  _fortunesAlgorithm()
  {
    newSite:Site, bottomSite:Site, topSite:Site, tempSite:Site;
    v:Vertex, vertex:Vertex;
    newintstar:Point;
    leftRight:LR;
    lbnd:Halfedge, rbnd:Halfedge, llbnd:Halfedge, rrbnd:Halfedge, bisector:Halfedge;
    Edge edge;
    
    dataBounds:Rectangle = _sites.getSitesBounds();
    
    sqrt_nsites:int = int(Math.sqrt(_sites.length + 4));
    heap:HalfedgePriorityQueue = new HalfedgePriorityQueue(dataBounds.y, dataBounds.height, sqrt_nsites);
    edgeList:EdgeList = new EdgeList(dataBounds.x, dataBounds.width, sqrt_nsites);
    halfEdges:List<Halfedge> = new List<Halfedge>();
    vertices:List<Vertex> = new List<Vertex>();
    
    bottomMostSite:Site = _sites.next();
    newSite = _sites.next();
    
    for (;;)
    {
      if (heap.empty() == false)
      {
        newintstar = heap.min();
      }
    
      if (newSite != null 
      &&  (heap.empty() || compareByYThenX(newSite, newintstar) < 0))
      {
        /* new site is smallest */
        //trace("smallest: new site " + newSite);
        
        // Step 8:
        lbnd = edgeList.edgeListLeftNeighbor(newSite.coord);  // the Halfedge just to the left of newSite
        //trace("lbnd: " + lbnd);
        rbnd = lbnd.edgeListRightNeighbor;    // the Halfedge just to the right
        //trace("rbnd: " + rbnd);
        bottomSite = rightRegion(lbnd);   // this is the same as leftRegion(rbnd)
        // this Site determines the region containing the new site
        //trace("new Site is in region of existing site: " + bottomSite);
        
        // Step 9:
        edge = Edge.createBisectingEdge(bottomSite, newSite);
        //trace("new edge: " + edge);
        _edges.push(edge);
        
        bisector = Halfedge.create(edge, LR.LEFT);
        halfEdges.push(bisector);
        // inserting two Halfedges into edgeList constitutes Step 10:
        // insert bisector to the right of lbnd:
        edgeList.insert(lbnd, bisector);
        
        // first half of Step 11:
        if ((vertex = Vertex.intersect(lbnd, bisector)) != null) 
        {
          vertices.push(vertex);
          heap.remove(lbnd);
          lbnd.vertex = vertex;
          lbnd.ystar = vertex.y + newSite.dist(vertex);
          heap.insert(lbnd);
        }
        
        lbnd = bisector;
        bisector = Halfedge.create(edge, LR.RIGHT);
        halfEdges.push(bisector);
        // second Halfedge for Step 10:
        // insert bisector to the right of lbnd:
        edgeList.insert(lbnd, bisector);
        
        // second half of Step 11:
        if ((vertex = Vertex.intersect(bisector, rbnd)) != null)
        {
          vertices.push(vertex);
          bisector.vertex = vertex;
          bisector.ystar = vertex.y + newSite.dist(vertex);
          heap.insert(bisector);  
        }
        
        newSite = _sites.next();  
      }
      else if (heap.empty() == false) 
      {
        /* intersection is smallest */
        lbnd = heap.extractMin();
        llbnd = lbnd.edgeListLeftNeighbor;
        rbnd = lbnd.edgeListRightNeighbor;
        rrbnd = rbnd.edgeListRightNeighbor;
        bottomSite = leftRegion(lbnd);
        topSite = rightRegion(rbnd);
        // these three sites define a Delaunay triangle
        // (not actually using these for anything...)
        //_triangles.push(new Triangle(bottomSite, topSite, rightRegion(lbnd)));
        
        v = lbnd.vertex;
        v.setIndex();
        lbnd.edge.setVertex(lbnd.leftRight, v);
        rbnd.edge.setVertex(rbnd.leftRight, v);
        edgeList.remove(lbnd); 
        heap.remove(rbnd);
        edgeList.remove(rbnd); 
        leftRight = LR.LEFT;
        if (bottomSite.y > topSite.y)
        {
          tempSite = bottomSite; bottomSite = topSite; topSite = tempSite; leftRight = LR.RIGHT;
        }
        edge = Edge.createBisectingEdge(bottomSite, topSite);
        _edges.push(edge);
        bisector = Halfedge.create(edge, leftRight);
        halfEdges.push(bisector);
        edgeList.insert(llbnd, bisector);
        edge.setVertex(LR.other(leftRight), v);
        if ((vertex = Vertex.intersect(llbnd, bisector)) != null)
        {
          vertices.push(vertex);
          heap.remove(llbnd);
          llbnd.vertex = vertex;
          llbnd.ystar = vertex.y + bottomSite.dist(vertex);
          heap.insert(llbnd);
        }
        if ((vertex = Vertex.intersect(bisector, rrbnd)) != null)
        {
          vertices.push(vertex);
          bisector.vertex = vertex;
          bisector.ystar = vertex.y + bottomSite.dist(vertex);
          heap.insert(bisector);
        }
      }
      else
      {
        break;
      }
    }
    
    // heap should be empty now
    heap.dispose();
    edgeList.dispose();
    
    for each (halfEdge:Halfedge in halfEdges)
    {
      halfEdge.reallyDispose();
    }
    halfEdges.length = 0;
    
    // we need the vertices to clip the edges
    for each (edge in _edges)
    {
      edge.clipVertices(_plotBounds);
    }
    // but we don't actually ever use them again!
    for each (vertex in vertices)
    {
      vertex.dispose();
    }
    vertices.length = 0;
    
    leftRegion(he:Halfedge):Site
    {
      Edge edge = he.edge;
      if (edge == null)
      {
        return bottomMostSite;
      }
      return edge.site(he.leftRight);
    }
    
    rightRegion(he:Halfedge):Site
    {
      Edge edge = he.edge;
      if (edge == null)
      {
        return bottomMostSite;
      }
      return edge.site(LR.other(he.leftRight));
    }
  }

  static _compareByYThenX(s1:Site, s2:*):Number
  {
    if (s1.y < s2.y) return -1;
    if (s1.y > s2.y) return 1;
    if (s1.x < s2.x) return -1;
    if (s1.x > s2.x) return 1;
    return 0;
  }

}