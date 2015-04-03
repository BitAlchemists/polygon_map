part of delaunay;

class EdgeList
{
  num _deltax;
  num _xmin;
  
  int _hashsize;
  List<Halfedge> _hash;
  Halfedge _leftEnd;
  Halfedge get leftEnd
  {
    return _leftEnd;
  }
  Halfedge _rightEnd;
  Halfedge get rightEnd
  {
    return _rightEnd;
  }
  
  dispose()
  {
    Halfedge halfEdge = _leftEnd;
    Halfedge prevHe;
    while (halfEdge != _rightEnd)
    {
      prevHe = halfEdge;
      halfEdge = halfEdge.edgeListRightNeighbor;
      prevHe.dispose();
    }
    _leftEnd = null;
    _rightEnd.dispose();
    _rightEnd = null;

    int i;
    for (i = 0; i < _hashsize; ++i)
    {
      _hash[i] = null;
    }
    _hash = null;
  }
  
  EdgeList(num xmin, num deltax, int sqrt_nsites)
  {
    _xmin = xmin;
    _deltax = deltax;
    _hashsize = 2 * sqrt_nsites;

    _hash = new List<Halfedge>(_hashsize);
    
    // two dummy Halfedges:
    _leftEnd = Halfedge.createDummy();
    _rightEnd = Halfedge.createDummy();
    _leftEnd.edgeListLeftNeighbor = null;
    _leftEnd.edgeListRightNeighbor = _rightEnd;
    _rightEnd.edgeListLeftNeighbor = _leftEnd;
    _rightEnd.edgeListRightNeighbor = null;
    _hash[0] = _leftEnd;
    _hash[_hashsize - 1] = _rightEnd;
  }

  /**
   * Insert newHalfedge to the right of lb 
   * @param lb
   * @param newHalfedge
   * 
   */
  insert(Halfedge lb, Halfedge newHalfedge)
  {
    newHalfedge.edgeListLeftNeighbor = lb;
    newHalfedge.edgeListRightNeighbor = lb.edgeListRightNeighbor;
    lb.edgeListRightNeighbor.edgeListLeftNeighbor = newHalfedge;
    lb.edgeListRightNeighbor = newHalfedge;
  }

  /**
   * This only removes the Halfedge from the left-right list.
   * We cannot dispose it yet because we are still using it. 
   * @param halfEdge
   * 
   */
  remove(Halfedge halfEdge)
  {
    halfEdge.edgeListLeftNeighbor.edgeListRightNeighbor = halfEdge.edgeListRightNeighbor;
    halfEdge.edgeListRightNeighbor.edgeListLeftNeighbor = halfEdge.edgeListLeftNeighbor;
    halfEdge.edge = Edge.DELETED;
    halfEdge.edgeListLeftNeighbor = halfEdge.edgeListRightNeighbor = null;
  }

  /**
   * Find the rightmost Halfedge that is still left of p 
   * @param p
   * @return 
   * 
   **/
  Halfedge edgeListLeftNeighbor(Point p)
  {
    int i, bucket;
    Halfedge halfEdge;
  
    /* Use hash table to get close to desired halfedge */
    bucket = (p.x - _xmin)/_deltax * _hashsize;
    if (bucket < 0)
    {
      bucket = 0;
    }
    if (bucket >= _hashsize)
    {
      bucket = _hashsize - 1;
    }
    halfEdge = getHash(bucket);
    if (halfEdge == null)
    {
      for (i = 1; true ; ++i)
        {
        if ((halfEdge = getHash(bucket - i)) != null) break;
        if ((halfEdge = getHash(bucket + i)) != null) break;
        }
    }
    /* Now search linear list of halfedges for the correct one */
    if (halfEdge == leftEnd  || (halfEdge != rightEnd && halfEdge.isLeftOf(p)))
    {
      do
      {
        halfEdge = halfEdge.edgeListRightNeighbor;
      }
      while (halfEdge != rightEnd && halfEdge.isLeftOf(p));
      halfEdge = halfEdge.edgeListLeftNeighbor;
    }
    else
    {
      do
      {
        halfEdge = halfEdge.edgeListLeftNeighbor;
      }
      while (halfEdge != leftEnd && !halfEdge.isLeftOf(p));
    }
  
    /* Update hash table and reference counts */
    if (bucket > 0 && bucket <_hashsize - 1)
    {
      _hash[bucket] = halfEdge;
    }
    return halfEdge;
  }

  /* Get entry from hash table, pruning any deleted nodes */
  Halfedge getHash(int b)
  {
    Halfedge halfEdge;
  
    if (b < 0 || b >= _hashsize)
    {
      return null;
    }
    halfEdge = _hash[b]; 
    if (halfEdge != null && halfEdge.edge == Edge.DELETED)
    {
      /* Hash table points to deleted halfedge.  Patch as necessary. */
      _hash[b] = null;
      // still can't dispose halfEdge yet!
      return null;
    }
    else
    {
      return halfEdge;
    }
  }

}