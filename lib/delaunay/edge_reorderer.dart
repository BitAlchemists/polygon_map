part of delaunay;

class EdgeReorderer
{
  List<Edge> _edges;
  List<LR> _edgeOrientations;
  List<Edge> get edges
  {
    return _edges;
  }
  List<LR> get edgeOrientations
  {
    return _edgeOrientations;
  }
  
  EdgeReorderer(List<Edge> origEdges, Type criterion)
  {
    if (criterion != Vertex && criterion != Site)
    {
      throw new ArgumentError("Edges: criterion must be Vertex or Site");
    }
    _edges = new List<Edge>();
    _edgeOrientations = new List<LR>();
    if (origEdges.length > 0)
    {
      _edges = reorderEdges(origEdges, criterion);
    }
  }
  
  dispose()
  {
    _edges = null;
    _edgeOrientations = null;
  }

  List<Edge> reorderEdges(List<Edge> origEdges, Type criterion)
  {
    int i;
    int n = origEdges.length;
    Edge edge;
    // we're going to reorder the edges in order of traversal
    List<bool> done = new List<bool>(n);
    int nDone = 0;
    
    for(int i = 0; i < n; i++)
    {
      done[i] = false;
    }
    
    
    List<Edge> newEdges = new List<Edge>();
    
    i = 0;
    edge = origEdges[i];
    newEdges.add(edge);
    _edgeOrientations.add(LR.LEFT);
    ICoord firstPoint = (criterion == Vertex) ? edge.leftVertex : edge.leftSite;
    ICoord lastPoint = (criterion == Vertex) ? edge.rightVertex : edge.rightSite;
    
    if (firstPoint == Vertex.VERTEX_AT_INFINITY || lastPoint == Vertex.VERTEX_AT_INFINITY)
    {
      return new List<Edge>();
    }
    
    done[i] = true;
    ++nDone;
    
    while (nDone < n)
    {
      for (i = 1; i < n; ++i)
      {
        if (done[i])
        {
          continue;
        }
        
        edge = origEdges[i];
        ICoord leftPoint = (criterion == Vertex) ? edge.leftVertex : edge.leftSite;
        ICoord rightPoint = (criterion == Vertex) ? edge.rightVertex : edge.rightSite;
        if (leftPoint == Vertex.VERTEX_AT_INFINITY || rightPoint == Vertex.VERTEX_AT_INFINITY)
        {
          return new List<Edge>();
        }
        if (leftPoint == lastPoint)
        {
          lastPoint = rightPoint;
          _edgeOrientations.add(LR.LEFT);
          newEdges.add(edge);
          done[i] = true;
        }
        else if (rightPoint == firstPoint)
        {
          firstPoint = leftPoint;
          _edgeOrientations.insert(0, LR.LEFT);
          newEdges.insert(0, edge);
          done[i] = true;
        }
        else if (leftPoint == firstPoint)
        {
          firstPoint = rightPoint;
          _edgeOrientations.insert(0, LR.RIGHT);
          newEdges.insert(0, edge);
          done[i] = true;
        }
        else if (rightPoint == lastPoint)
        {
          lastPoint = leftPoint;
          _edgeOrientations.add(LR.RIGHT);
          newEdges.add(edge);
          done[i] = true;
        }
        if (done[i])
        {
          ++nDone;
        }
      }
    }
    
    return newEdges;
  }

}