part of geom;

class LineSegment
  {
    static num compareLengths_MAX(LineSegment segment0, LineSegment segment1)
    {
      num length0 = Point.distance(segment0.p0, segment0.p1);
      num length1 = Point.distance(segment1.p0, segment1.p1);
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
    
    static num compareLengths(LineSegment edge0, LineSegment edge1)
    {
      return - compareLengths_MAX(edge0, edge1);
    }

    Point p0;
    Point p1;
    
    LineSegment(Point p0, Point p1)
    {
      this.p0 = p0;
      this.p1 = p1;
    }
    
  }