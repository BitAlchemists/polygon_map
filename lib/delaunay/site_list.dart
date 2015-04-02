part of delaunay;

class SiteList// implements IDisposable
{
  List<Site> _sites;
  int _currentIndex;
  
  bool _sorted;
  
  SiteList()
  {
    _sites = new List<Site>();
    _sorted = false;
  }
  
  dispose()
  {
    if (_sites != null)
    {
      for(Site site in _sites)
      {
        site.dispose();
      }
      _sites.length = 0;
      _sites = null;
    }
  }
  
  int add(Site site)
  {
    _sorted = false;
    _sites.add(site);
    return _sites.length;
  }
  
  int get length
  {
    return _sites.length;
  }
  
  Site next()
  {
    if (_sorted == false)
    {
      throw "SiteList::next():  sites have not been sorted";
    }
    if (_currentIndex < _sites.length)
    {
      return _sites[_currentIndex++];
    }
    else
    {
      return null;
    }
  }

  Rectangle getSitesBounds()
  {
    if (_sorted == false)
    {
      Site.sortSites(_sites);
      _currentIndex = 0;
      _sorted = true;
    }
    num xmin, xmax, ymin, ymax;
    if (_sites.length == 0)
    {
      return new Rectangle(0, 0, 0, 0);
    }
    
    //TODO: evaluate
    xmin = double.MAX_FINITE;
    xmax = -double.MAX_FINITE;
    for(Site site in _sites)
    {
      if (site.x < xmin)
      {
        xmin = site.x;
      }
      if (site.x > xmax)
      {
        xmax = site.x;
      }
    }
    // here's where we assume that the sites have been sorted on y:
    ymin = _sites[0].y;
    ymax = _sites[_sites.length - 1].y;
    
    return new Rectangle(xmin, ymin, xmax - xmin, ymax - ymin);
  }

  List<int> siteColors([BitmapData referenceImage = null])
  {
    List<int> colors = new List<int>();
    for(Site site in _sites)
    {
      colors.add(referenceImage != null ? referenceImage.getPixel(site.x, site.y) : site.color);
    }
    return colors;
  }

  List<Point> siteCoords()
  {
    List<Point> coords = new List<Point>();
    for(Site site in _sites)
    {
      coords.add(site.coord);
    }
    return coords;
  }

  /**
   * 
   * @return the largest circle centered atsite that fits in its region;
   * if the region is infinite, return a circle of radius 0.
   * 
   */
  List<Circle> circles()
  {
    List<Circle> circles = new List<Circle>();
    for(Site site in _sites)
    {
      num radius = 0;
      Edge nearestEdge = site.nearestEdge();
      
      //TODO: Evaluate correct porting
      //!nearestEdge.isPartOfConvexHull() && (radius = nearestEdge.sitesDistance() * 0.5);
      if(!nearestEdge.isPartOfConvexHull())
      {
        radius = nearestEdge.sitesDistance() * 0.5;
      }
      circles.add(new Circle(site.x, site.y, radius));
    }
    return circles;
  }

  List<List<Point>> regions(Rectangle plotBounds)
  {
    List<List<Point>> regions = new List<List<Point>>();
    for(Site site in _sites)
    {
      regions.add(site.region(plotBounds));
    }
    return regions;
  }

  /**
   * 
   * @param proximityMap a BitmapData whose regions are filled with the site index values; see PlanePointsCanvas::fillRegions()
   * @param x
   * @param y
   * @return coordinates of nearest Site to (x, y)
   * 
   */
  Point nearestSitePoint(BitmapData proximityMap, num x, num y)
  {
    int index = proximityMap.getPixel(x, y);
    if (index > _sites.length - 1)
    {
      return null;
    }
    return _sites[index].coord;
  }
  
}