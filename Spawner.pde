// object that spawns marbles

class Spawner {
  
  // a list to store the vertices
  ArrayList<Vec2> vertices;
  color myColor = color(255,255,255);
  Rectangle boundingBox;

  Spawner(ArrayList<Vec2> vertices) {
    this.vertices = vertices;
  }

  void setColor(color myColor) {
    this.myColor = myColor;
  }
  
  void setBoundingBox(Rectangle bb){
    boundingBox = bb;
  }

  // displays the shape of the spawner
  void display() {

    stroke(0);
    strokeWeight(2);
    fill(myColor);
    beginShape();
    for (Vec2 v : vertices) {
      vertex(v.x, v.y);
    }
    vertex(vertices.get(0).x,vertices.get(0).y);
    endShape();
  }
}

