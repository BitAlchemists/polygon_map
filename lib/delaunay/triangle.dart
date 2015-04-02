part of delaunay;

class Triangle
{
  List<Site> _sites;
  List<Site> get sites
  {
    return _sites;
  }
  
  Triangle(Site a, Site b, Site c)
  {
    _sites = <Site>[ a, b, c ];
  }
  
  dispose()
  {
    _sites.length = 0;
    _sites = null;
  }

}