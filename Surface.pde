// a platform for the marbles to collide and roll

class Surface {
  // a list to store all vertices
  ArrayList<Vec2> vertices;
  Body body;
  color myColor = color(255, 255, 255);
  boolean isRed, isGreen = false;

  Rectangle boundingBox;

  // default physics properties, should be overwritten depending on the platform
  float density = 1;
  float friction = 1;
  float restitution = 0;

  Surface(ArrayList<Vec2> vertices, float friction, float restitution) {
    this.vertices = vertices;
    this.friction = friction;
    this.restitution = restitution;

    makeBody();
  }

  // deletes the body from the Box2D world
  void destroy() {
    box2d.destroyBody(body);
  }

  // sets color
  void setColor(color myColor) {
    this.myColor = myColor;
  }

  // displays the shape of the platform. Does not affect the physics simulation
  void display() {
    stroke(0);
    strokeWeight(2);
    fill(myColor);
    beginShape();
    for (Vec2 v : vertices) {
      vertex(v.x, v.y);
    }
    // first vertex again to close the shape
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
    // parameters that affect physics
    fd.density = density;
    fd.friction = friction;
    fd.restitution = restitution;

    body.createFixture(fd);

    body.setUserData(this);
  }
}

