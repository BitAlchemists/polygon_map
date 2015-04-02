part of delaunay;

enum LR_VALUE {
  LEFT,
  RIGHT
}

class LR
{  
  static LR LEFT = new LR._internal(LR_VALUE.LEFT);
  static LR RIGHT = new LR._internal(LR_VALUE.RIGHT);
  
  LR_VALUE _value;
  
  LR._internal(LR_VALUE value)
  {
    _value = value;
  }
  
  static LR other(LR leftRight)
  {
    return leftRight == LEFT ? RIGHT : LEFT;
  }
  
  String toString()
  {
    return _value == LR_VALUE.LEFT ? "LEFT" : "RIGHT";
  }

}