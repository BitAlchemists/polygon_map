part of delaunay;

/**
*  Kruskal's spanning tree algorithm with union-find
 * Skiena: The Algorithm Design Manual, p. 196ff
 * Note: the sites are implied: they consist of the end points of the line segments
*/
List<LineSegment> kruskal(List<LineSegment> lineSegments, [String type = "minimum"])
  {
  Map nodes = new Map();
  List<LineSegment> mst = new List<LineSegment>();
  List<Node> nodePool = Node.pool;
    
    switch (type)
    {
      // note that the compare functions are the reverse of what you'd expect
      // because (see below) we traverse the lineSegments in reverse order for speed
      case "maximum":
        lineSegments.sort(LineSegment.compareLengths);
        break;
      default:
        lineSegments.sort(LineSegment.compareLengths_MAX);
        break;
    }
    
    for (int i = lineSegments.length; --i > -1;)
    {
      LineSegment lineSegment = lineSegments[i];
      
      Node node0 = nodes[lineSegment.p0];
      Node rootOfSet0;
      if (node0 == null)
      {
        node0 = nodePool.length > 0 ? nodePool.removeLast() : new Node();
        // intialize the node:
        rootOfSet0 = node0.parent = node0;
        node0.treeSize = 1;
      
        nodes[lineSegment.p0] = node0;
      }
      else
      {
        rootOfSet0 = find(node0);
      }
      
      Node node1 = nodes[lineSegment.p1];
      Node rootOfSet1;
      if (node1 == null)
      {
        node1 = nodePool.length > 0 ? nodePool.removeLast() : new Node();
        // intialize the node:
        rootOfSet1 = node1.parent = node1;
        node1.treeSize = 1;
      
        nodes[lineSegment.p1] = node1;
      }
      else
      {
        rootOfSet1 = find(node1);
      }
      
      if (rootOfSet0 != rootOfSet1) // nodes not in same set
      {
        mst.add(lineSegment);
        
        // merge the two sets:
        int treeSize0 = rootOfSet0.treeSize;
        int treeSize1 = rootOfSet1.treeSize;
        if (treeSize0 >= treeSize1)
        {
          // set0 absorbs set1:
          rootOfSet1.parent = rootOfSet0;
          rootOfSet0.treeSize += treeSize1;
        }
        else
        {
          // set1 absorbs set0:
          rootOfSet0.parent = rootOfSet1;
          rootOfSet1.treeSize += treeSize0;
        }
      }
    }
    
    for(Node node in nodes)
    {
      nodePool.add(node);
    }
    
    return mst;
  }

Node find(Node node)
{
  if (node.parent == node)
  {
    return node;
  }
  else
  {
    Node root = find(node.parent);
    // this line is just to speed up subsequent finds by keeping the tree depth low:
    node.parent = root;
    return root;
  }
}

class Node
{
  static List<Node> pool = new List<Node>();

  Node parent;
  int treeSize;
  
  Node() {}
}