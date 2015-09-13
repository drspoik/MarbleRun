// a Box2D object

class Marble {

  Body body;
  float r;
  color col = color(0, 0, 255);
  boolean isBoosting = false;
  int enterPortal;
  int exitPortal;
  boolean teleport = false;
  boolean canTeleport = true;
  int timer = 0;
  Vec2 telePos;
  Marble(float x, float y, float r) {
    this.r = r;
    makeBody(x, y, r);
  }

  // removes the body from the box2d world
  void destroy() {
    box2d.destroyBody(body);
  }

  // sets the color of the marble
  void setColor(color c) {
    col = c;
  }

  // checks if marble has left the screen and is ready for deletion
  boolean done() {
    // locate the position of the marble
    Vec2 pos = box2d.getBodyPixelCoord(body);
    // if it's below the screen, destroy it
    if (pos.y > height+r*2) {
      destroy();
      return true;
    }
    return false;
  }
 
 void orderTeleport(Vec2 pos, int enterPortal, int exitPortal){
   if(canTeleport){
     this.enterPortal = enterPortal;
     this.exitPortal = exitPortal;
     telePos = box2d.coordPixelsToWorld(pos.x,pos.y);
     teleport = true;
   }
 }
 
 void reportExitPortal(int exit){
   if(exit == enterPortal){
     return;
   } else {
     canTeleport = true;
   }
 }

  // this function is just used to display the marble on screen. Its physical body moves regardless
  void display() {
    
    //teleport cooldown, to avoid an instantaneous teleportation to the next portal 
     timer++;
    if(timer > 30){
      canTeleport = true;
    }
    //prepares the marble to be teleported to another position
    if(teleport){
      timer = 0;
      body.setTransform(telePos , 0);
      canTeleport = false;
      teleport = false;
    }
    // cache the position and the angle of rotation of the body
    Vec2 pos = box2d.getBodyPixelCoord(body);
    float a = body.getAngle();

    pushMatrix();

    // move to the position and rotate it accordingly
    translate(pos.x, pos.y);
    rotate(-a);

    // apply the looks
    fill(col);
    noStroke();

    // draw a circle
    ellipse(0, 0, r*2, r*2);

    // draw a reflection to see the rotation
    fill(255);
    ellipse(r*0.33, r*0.33, r/2, r/2);

    popMatrix();
    
  }

  // adds the physical presents into the Box2D world
  void makeBody(float x, float y, float r) {

    // define a body
    BodyDef bd = new BodyDef();
    // set position
    bd.position = box2d.coordPixelsToWorld(x, y);
    // dynamic type, since it moves
    bd.type = BodyType.DYNAMIC;
    // create the body
    body = box2d.world.createBody(bd);

    // define a shape, in this case a circle
    CircleShape cs = new CircleShape();
    cs.m_radius = box2d.scalarPixelsToWorld(r);

    // define the fixture i.e. the phyiscal properties
    FixtureDef fd = new FixtureDef();
    fd.shape = cs;
    // parameters that affect physics
    fd.density = 1;
    fd.friction = 0.01;
    fd.restitution = 0.3;

    // attach fixture to body
    body.createFixture(fd);
    body.setUserData(this);
  }

  void boost(float factor) { 
    Vec2 _v = body.getLinearVelocity();
    Vec2 _v2 = new Vec2( _v.x * factor, _v.y * factor );

    Vec2 pos = body.getWorldCenter();
    body.applyForce(_v2, pos);
  }
  
    
void attract(float x,float y) {
    // From BoxWrap2D example
    Vec2 worldTarget = box2d.coordPixelsToWorld(x,y);   
    Vec2 bodyVec = body.getWorldCenter();
    // First find the vector going from this body to the specified point
    worldTarget.subLocal(bodyVec);
    // Then, scale the vector to the specified force
    worldTarget.normalize();
    worldTarget.mulLocal((float) 50);
    // Now apply it to the body's center of mass.
    body.applyForce(worldTarget, bodyVec);
  }

  void enterCollRed() {
    isBoosting = true;
  }

  void exitCollRed() {
    isBoosting = false;
  }

}

