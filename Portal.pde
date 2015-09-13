// object that attracts marbles

class Portal {

  // a list to store the vertices
  ArrayList<Vec2> vertices;
  Body body;
  color myColor = color(255, 255, 255);
  Rectangle boundingBox;

  Portal(ArrayList<Vec2> vertices) {
    this.vertices = vertices;
    makeBody();
  }
  
    // deletes the body from the Box2D world
  void destroy() {
    box2d.destroyBody(body);
  }

  void setColor(color myColor) {
    this.myColor = myColor;
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
    vertex(vertices.get(0).x, vertices.get(0).y);
    endShape();
  }
  
    void makeBody() {
    // define the shape. in this case a chain. as opposed to polygonshapes, chainshape can be concave
    ChainShape chain = new ChainShape();

    // parse the arraylist of pixel coordinates into an array of worldcoordinates
    Vec2[] v = new Vec2[vertices.size()];
    for (int i = 0; i < v.length; i++) {
      v[i] = box2d.coordPixelsToWorld(vertices.get(i));
    }

    //create the chain as a loop
    chain.createLoop(v, v.length);

    // define the body
    BodyDef bd = new BodyDef();
    body = box2d.world.createBody(bd);

    // define the fixture
    FixtureDef fd = new FixtureDef();
    fd.shape = chain;
    fd.isSensor = true;

    body.createFixture(fd);

    body.setUserData(this);
  }
  
}

