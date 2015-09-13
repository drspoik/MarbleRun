/**
 * MarbleRun
 * by Lukas Steinmetz (lukassteinmetz.com) 2015
 *
 * Fachhochschule St. Pölten University of Applied Sciences - Media Technology
 * Summersemester 2015 - Interactive Installations (IAI)
 *
 * Summary
 * The user can draw lines and shapes on a piece of paper or a whiteboard.
 * The webcam picks it up and interprets it as platforms.
 * Marbles start to drop and the physicsimulation kicks in.
 * 
 * If no webcam available, there is support for image files.
 * Arduino supported control.
 * 
 */

// use the video libary for the webcam
import processing.video.*;

// mainly used for the Rect class
import java.awt.*;

// used to process the image and find shapes
import gab.opencv.*;

// the various Box2D libaries for the physics simulation of the marbles
import shiffman.box2d.*;
import org.jbox2d.collision.shapes.*;
import org.jbox2d.common.*;
import org.jbox2d.dynamics.*;
import org.jbox2d.dynamics.contacts.*;

// these libaries allows us to use the arduino inside of processing
import processing.serial.*;
import cc.arduino.*;

// reference to the box2d world
Box2DProcessing box2d;

Arduino arduino;

// various lists of objects
ArrayList<Marble> marbles;
ArrayList<Contour> contours;
ArrayList<Vec2> vertices;
ArrayList<Surface> surfaces;
ArrayList<Spawner> spawners;
ArrayList<Portal> portals;

// the arduino pins
final int createButtonPin = 9;     
final int hideButtonPin = 8;
final int spawnPotPin = 0;
final int threshPotPin = 1;
final int ledPin = 13;

// these variables are used to keep track of the different button states
int cButtonState = 0;   
int hButtonState = 0;
float lastThreshPot = 0;
int lastHButtonState = 0;
boolean blockHButton = false;

// after every x-frames, every spawner creates a new marble 
// at a framerate of 60fps, there are 2 marbles per second
int spawnRate = 30;

// stores a reference of the webcam
PImage ref;

// define the borders of the canvas
int xBound = 10;
int yBound = 20;
int wBound, hBound;
boolean hide = false;

// stores the webcam image or file
Capture video;
PImage pic;

OpenCV opencv;

// the threshold determines how much of the image is intepreted as a platform
int threshold = 110;

// the state refers to the different states of the programm
// displayCamSelection, displayArduinoSelection, runningProgramm
int state = 0;

// keeps track of the selection
int camSelectionIndex = 0;
int maxcamSelectionIndex = 0;
boolean noCam = false;

// displaying the warning message?
boolean extensionWarning = false;

// keeps track of the selection
int ardSelectionIndex = 0;
int maxardSelectionIndex = 0;
boolean noArduino = false;

// list of all available cameras and arduinos
String[] cameras;
String[] arduinos;

void setup() {

  // sets initial size of the window
  size(600, 400);

  // enables anti-aliasing, so the lines don't look to jagged
  smooth();

  // enables the resizing of the window, to accommodate different resolutions
  frame.setResizable(true);

  // define the looks of the font (textLeading defines the line height)
  textSize(12);
  textLeading(13);

  // get all available webcams
  cameras = Capture.list();
  // calculates the number of pages, necessary to display 9 cameras at once
  maxcamSelectionIndex = ceil(cameras.length / 9);

  // get all available devices
  arduinos = Arduino.list();
  // calculates the number of pages, necessary to display 9 devices at once
  maxardSelectionIndex = ceil(arduinos.length / 9);

  // initialize box2d physics and create the world
  box2d = new Box2DProcessing(this);
  box2d.createWorld();

  // setting a custom gravity
  box2d.setGravity(0, -20);
  // activate the collision detection
  box2d.listenForCollisions();

  // create empty lists
  marbles = new ArrayList<Marble>();
  contours = new ArrayList<Contour>();

  surfaces = new ArrayList<Surface>();
  spawners = new ArrayList<Spawner>();
  portals = new ArrayList<Portal>();
}

void draw() {


  if (state == 0) {

    background(0);
    displayCamSelection();
  } else if (state == 1) {

    background(0);
    displayArduinoSelection();
  } else if (state == 2) {

    startProgramm();
  } else {

    // if there is an arduino connected, process the arduino input and output 
    if (!noArduino)
      arduinoIO();

    // draw white background (just in case)
    background(255);

    // step through Box2D time
    box2d.step();

    // draw the video image
    if (noCam) image(pic, 0, 0);
    else image(video, 0, 0);

    // updates the spawner, portals, surfaces and marbles
    updateObjects();

    // processes and draws the boundary box and controltext
    GUI();
  }
}

void displayCamSelection() {

  String s = "";
  if (cameras.length == 0) {
    s += "There are no cameras available for capture.";
  } else {
    s+= "Available cameras:\n";
    s+= "Minimum resolution of 640x360 recommended\n\n";
    s+= "To select a camera, hit the corresponding number on your keyboard\n";
    // display 9 cameras at once
    for (int i = 1; i <= 9; i++) {
      try {
        // shows the current camera considering the current pageindex
        s+= "["+i+"] - "+cameras[i-1 + (camSelectionIndex*9)]+"\n";
      }
      catch (Exception e) {
        // if there are no more cameras add an empty line
        s+="\n";
      }
    }
    // show the pagination
    s+="\nPage "+(camSelectionIndex+1)+" of "+(maxcamSelectionIndex+1)+" | Use the arrow keys to navigate\n\n";
  }
  s+="To select an image from you computer hit [0]";

  fill(255);
  text(s, 10, 10, width-10, height-10);
  // if the user chooses something other than a jp(e)g, png or gif, show a warning
  if (extensionWarning) {
    fill(255, 0, 0);
    text("Only pngs, jpgs and gifs allowed", 10, 250);
  }
}

void displayArduinoSelection() {

  String s = "";

  if (arduinos.length == 0) {
    s += "There are no devices available.";
  } else {
    s+= "Available devices:\n\n";
    s+= "To select a device, hit the corresponding number on your keyboard\n";
    // display 9 devices at once

    for (int i = 1; i <= 9; i++) {
      try {        
        // shows the current device considering the current pageindex
        s+= "["+i+"] - "+arduinos[i-1 + (ardSelectionIndex*9)]+"\n";
      }
      catch (Exception e) {
        // if there are no more devices add an empty line
        s+="\n";
      }
    }
    // show the pagination
    s+="\nPage "+(ardSelectionIndex+1)+" of "+(maxardSelectionIndex+1)+" | Use the arrow keys to navigate\n\n";
  }
  s+="If you don't want to use any of these devices or you don't have a matching Arduino configuration connected (Pin 8 - Button, Pin 9 - Button, Pin A0 - Potentiometer, Pin A1 - Potentiometer), hit [0] on your keyboard";
  fill(255);
  text(s, 10, 10, width-10, height-10);
}

void startProgramm() {
  // if no camera is used
  if (noCam) {
    // resize to fit the picture
    resize(pic.width, pic.height);
    frame.setSize(pic.width, pic.height);   
    // create opencv object with the same size as the picture   
    opencv = new OpenCV(this, pic.width, pic.height);
    // go to next step
    state++;
  } else { 
    // if the size of the video does not match the size of the window
    // the additional if condition is necessary, because the video feed takes some frames
    if (width != video.width && video.width != 0) {
      // resize to fit the video
      resize(video.width, video.height);
      frame.setSize(video.width, video.height);      
      // create opencv object with the same size as the video
      opencv = new OpenCV(this, video.width, video.height);
      // go to next step
      state++;
    }
  }
}

void updateObjects() {
  for (Surface su : surfaces) {
    // display the surfaces if desired
    if (!hide) {
      su.display();
    }
  }

  for (Spawner sp : spawners) {
    // display the spawner if desired
    if (!hide) 
      sp.display();
    // a new marble is spawned
    if (frameCount%spawnRate == 0) {
      // size and color depends on the spawner
      int size = sp.boundingBox.width < sp.boundingBox.height ? sp.boundingBox.width/2 : sp.boundingBox.height/2;
      Marble marb = new Marble((int) sp.boundingBox.getCenterX(), (int) sp.boundingBox.getCenterY(), size);
      marb.setColor(sp.myColor);

      if (!noArduino) {
        // flash the LED on the arduino
        arduino.digitalWrite(ledPin, Arduino.HIGH);
        delay(20);
        arduino.digitalWrite(ledPin, Arduino.LOW);
      }
      //add the marble to to list
      marbles.add(marb);
    }
  }

  for (Portal po : portals) {
    if (!hide) 
      po.display();
  }

  // displays all marbles
  for (Marble m : marbles) {
    m.display();
    // check if they are supposed to boost right now
    if (m.isBoosting)
      m.boost(3);
  }

  // if a marble exits the screen, it gets deleted from the Box2D world and the list
  for (int i = marbles.size ()-1; i >= 0; i--) {
    Marble m = marbles.get(i);
    if (m.done()) {
      marbles.remove(i);
    }
  }
}

void GUI() {

  // calculate the width and height of the boundary
  wBound = width-xBound;
  hBound = height-yBound;

  if (!hide) {

    //WASD can be used to adjust the box
    if (keyPressed) {
      if (key == 'W' || key == 'w') {
        if (yBound > 1)
          yBound -= 1;
      } else if (key == 'S' || key == 's') {
        if (yBound < (height / 2) - 20)
          yBound += 1;
      } else  if (key == 'A' || key == 'a') {
        if (xBound > 1)
          xBound -= 1;
      } else if (key == 'D' || key == 'd') {
        if (xBound < (width / 2) - 30)
          xBound += 1;
      }
    }

    // draw the framerate for performance check and the controls
    fill(0);
    String s = "framerate: " + (int)frameRate+", [SPACE] to generate platforms, [H] to toggle geometry, [C] to clear marbles, [W]/[A]/[S]/[D] to adjust frame, [UP]/[DOWN] to adjust the threshold, [LEFT]/[RIGHT] to adjust the spawnrate";
    text(s, xBound + 5, yBound + 5, wBound - xBound - 5, hBound - yBound - 5);

    //draw the rectangle in which all the elements should be placed
    stroke(255, 0, 0);
    strokeWeight(2);
    strokeJoin(BEVEL);
    noFill();

    rect(xBound, yBound, wBound - xBound, hBound - yBound);
  }
}

void arduinoIO() {
  // read the potentiometer value for the threshold of the image processing
  float pot = arduino.analogRead(threshPotPin);

  // calculate the difference between this value and the value of the last frame
  float difPot = pot - lastThreshPot;

  // if the difference is not insignificant...
  if (abs(difPot) > 2) {

    // remap the raw data into the desired range
    float rangedPot = map(pot, 0, 1023, 140, 70);

    // round to int and process the image
    threshold = round(rangedPot);
    processImage();

    // remeber the current value to check next frame
    lastThreshPot = pot;
  }
  
  float spawnPot = arduino.analogRead(spawnPotPin);
  spawnRate = round(map(spawnPot, 0, 1023, 20, 150));

  // store the state of the pushbutton value:
  cButtonState = arduino.digitalRead(createButtonPin);
  hButtonState = arduino.digitalRead(hideButtonPin);

  // if both buttons are pressed...
  if (cButtonState == Arduino.HIGH && hButtonState == Arduino.HIGH) {

    // block the hide button from firing when released
    blockHButton = true;

    // clear all marbles
    for (Marble m : marbles) {
      m.destroy();
    }  
    marbles.clear();
  } else {

    // if the create button is pressed...
    if (cButtonState == Arduino.HIGH) {
      // process the image
      processImage();
    } 

    // if the hide button is not pressed and is not blocked
    if (hButtonState == Arduino.LOW && !blockHButton) {

      // was it pressed last frame?
      if (lastHButtonState != hButtonState) {

        // toggle the hiding of the geometry
        hide = !hide;
      }
    }

    // remeber this button state
    lastHButtonState = hButtonState;

    // if both buttons are not pressed, unblock the hide button
    if (cButtonState == Arduino.LOW && hButtonState == Arduino.LOW) {
      blockHButton = false;
    }
  }

  // very short delay of the arduino for stability
  delay(1);
}

void keyPressed() {

  // if we are on the camera selection screen
  if (state == 0) {
    if ( key == '1' || key == '2' || key == '3' || key == '4' || key == '5'
      || key == '6' || key == '7' || key == '8' || key == '9') {

      // convert the char to int
      int k = key - '0';

      //calculate the corresponding arrayindex
      int camIndex = (k - 1) + (camSelectionIndex * 9);

      // setup the camera
      video = new Capture(this, cameras[camIndex]);
      video.start();

      // go to next step
      state++;
    } else if ( key == '0') {
      // open the file chooser
      selectInput("Select an png, jpeg or gif:", "fileSelected");
    } else if (keyCode == RIGHT) {
      // go through the pages
      if (camSelectionIndex < maxcamSelectionIndex) {
        camSelectionIndex ++;
      }
    } else if (keyCode == LEFT) {
      // go through the pages
      if (camSelectionIndex > 0) {
        camSelectionIndex --;
      }
    }
    // if we are on the arduino selection screen
  } else if (state == 1) {
    if ( key == '1' || key == '2' || key == '3' || key == '4' || key == '5'
      || key == '6' || key == '7' || key == '8' || key == '9') {

      // convert char to int
      int k = key - '0';
      
      // adjust the input for the array
      k--;
      
      // arduino setup
      arduino = new Arduino(this, Arduino.list()[k], 57600);
      arduino.pinMode(createButtonPin, Arduino.INPUT);
      arduino.pinMode(hideButtonPin, Arduino.INPUT);
      arduino.pinMode(ledPin, Arduino.OUTPUT);
      
      // go to next step
      state ++;
      
      // do not use an arduino
    } else if ( key == '0') {
      noArduino = true;
      state ++;
    } else if (keyCode == RIGHT) {
      // go through the pages
      if (ardSelectionIndex < maxardSelectionIndex) {
        ardSelectionIndex ++;
      }
    } else if (keyCode == LEFT) {
      // go through the pages
      if (ardSelectionIndex > 0) {
        ardSelectionIndex --;
      }
    }
    
    // not on an selection screen but the actual programm
  } else {

    // adjust the threshold, determining the sensibility of the image processing
    if (keyCode == UP) {
      if(threshold < 160){
        threshold += 10;
        processImage();
      }
    } else if (keyCode == DOWN) {
      if(threshold > 10){
        threshold -= 10;
        processImage();
      }
    } else if (keyCode == LEFT){
      // increases spawnRate, therefore increases time between spawning
      spawnRate += 10;
    } else if (keyCode == RIGHT){
      // decreased spawnRate, creating more marbles in less time
      if(spawnRate > 10){
        spawnRate -= 10;
      }
    } else if (key == 'C' || key == 'c') {
      // clear all marbles
      for (Marble m : marbles) {
        m.destroy();
      }  
      marbles.clear();
      
    // toggle hiding geometry
    } else if (key == 'H' || key == 'h') {
      hide = !hide;
      
      // process image
    } else if (key ==' ') {
      processImage();
    }
  }
}

void fileSelected(File selection) {
  // if the selection has been canceled
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    // convert the filename to lowercase 
    String fileName =  selection.getName().toLowerCase();
    
    // check for fileextension
    if (!fileName.endsWith("png") && !fileName.endsWith("jpeg") 
      && !fileName.endsWith("jpg") && !fileName.endsWith("gif")) {
        
        //display the warning, if its a non supported file
      extensionWarning = true;
      
    } else {
      // get the file
      pic = loadImage(selection.getAbsolutePath());
      noCam = true;
      
      // go to next step
      state++;
    }
  }
}

void processImage() {
  // failsafe if the image has not loaded yet
  if (video != null || pic != null) {
    scanImage();
    clearObjects();
    createObjects();
  }
}

void scanImage() {

  // loads the video image into the opencv object
  if (noCam) opencv.loadImage(pic);
  else opencv.loadImage(video);
  
  // stores reference image for color detection
  if (noCam) ref = pic.get();
  else ref = video.get();
  
  // converts the opencv image into grayscale and applies a threshold
  // the result is a pure black and white image, which is better for the contour detection
  opencv.gray();
  opencv.threshold(threshold);
}

void clearObjects() {

  // destroys the box2D bodies
  for (Surface su : surfaces) {
    su.destroy();
  }

  for (Portal po : portals) {
    po.destroy();
  }

  // clears the lists
  surfaces.clear();
  portals.clear();
  spawners.clear();
}


void createObjects() {

  // clears the list of contours to start anew
  contours.clear();
  contours = opencv.findContours();

  // iterates through all the found contours to process the good ones
  for (Contour c : contours) {

    // stores a list of vertices used for creating the platform
    vertices = new ArrayList<Vec2>();

    // the approximation factor is a number that determines how much the polygon gets simplified
    c.setPolygonApproximationFactor(5);

    // only simplified polygons with 3 or more vertices get looked at
    if (c.getPolygonApproximation().numPoints() >= 3) {
      // iterates through all points from the simplified polygon
      for (PVector p : c.getPolygonApproximation ().getPoints()) {
        // if the point is within the boundary, it's considered safe
        if (p.x > xBound && p.y > yBound && p.x < wBound && p.y < hBound) 
          vertices.add(new Vec2(p.x, p.y));
      }
      // if there are still at least 3 vertices, start deciding the type of shape
      if (vertices.size() >= 3) {

        // load the pixels for color recoginition
        ref.loadPixels();

        // get the rectangle surrounding the contour
        Rectangle bb = c.getBoundingBox();

        // store the center points of the bounding box
        int  x = (int) bb.getCenterX();
        int  y = (int) bb.getCenterY();
        color col = color(255, 255, 255);

        // if the center point of the bounding box is inside the contour,
        // it's a close to a rectangle, circle or regular polygon 
        if (c.containsPoint(x, y)) {
          col = ref.pixels[y*width+x];
        }

        // otherwise it's some kind of irregular polygon
        // since irregluar polygons don't have a center of mass, 
        // we have to take some educated guesses
        else {

          // storing the number of tries
          int tries = 0;
          // since this algorithm is pairing 2 vertices opposite to another, 
          // we only have to do this for half of all vertices
          int maxTries = vertices.size()/2;

          // as long as we haven't found  a point inside of the contour
          // and we didn't test every vertex, we try to find a match
          while (!c.containsPoint (x, y) && tries < maxTries) {
            // grab 2 vertices opposite to one another
            Vec2 p1 = vertices.get(tries);
            Vec2 p2 = vertices.get(tries + maxTries);
            // find the middle point
            Vec2 m = new Vec2((p1.x+p2.x)/2, (p1.y+p2.y)/2);
            x = (int) m.x;
            y = (int) m.y;
            tries++;
          }
          // if we haven't found a point inside of the shape, we apologize
          if (!c.containsPoint(x, y)) {
            println("Unrecognizable Shape, guessing color... sorry :(");
          }
          // get the color of a pixel that is inside of the shape or the last try
          col = ref.pixels[y*width+x];
        }

        // split the red, green and blue value for checking by right shifting the bit values
        int r = (col >> 16 & 0xFF);
        int g = (col >> 8 & 0xFF);
        int b = (col & 0xFF);

        // check the red, green and blue value of the object. If it's a shade of blue, it's a spawner
        // these numbers are arbitrary and came from trial and error
        if (b >= 60 && b >= 1.5*r && b >= 1.4*g ) {
          // create a spawner
          Spawner spawner = new Spawner(vertices);
          // set the bounding box for determining the size of the spawned marbles
          spawner.setBoundingBox(bb);
          spawner.setColor(col);
          // add the spawner to the list
          spawners.add(spawner);
        } 
        // green platform with bounciness
        else if (g >= 50 && g >= 1.3*r && g >= 1.1*b ) {
          Surface surf = new Surface(vertices, 1, 1);
          surf.setColor(col);
          surf.isGreen = true;
          surfaces.add(surf);
        }
        // red platform with zero friction
        else if ( r >= 100 && r >= 1.6*g && r >= 1.6*b) {
          Surface surf = new Surface(vertices, 0, 0);
          surf.setColor(col);
          surf.isRed = true;
          surfaces.add(surf);
        }
        // purple Portal
        else if ( r >= 80 && g < 80 && b >= 65 ) {
          Portal port = new Portal (vertices);
          port.setColor(col);
          port.boundingBox = bb;
          portals.add(port);
        }

        // otherwise it's a simple surface with high friction and no bounciness 
        else {
          Surface surf = new Surface(vertices, 1, 0);
          surf.setColor(col);
          surfaces.add(surf);
        }
      }
    }
  }
}

void captureEvent(Capture c) {
  c.read();
}

// collision detection
void beginContact(Contact cp) {

  // get the involved fixtures
  Fixture f1 = cp.getFixtureA();
  Fixture f2 = cp.getFixtureB();

  // get both bodies
  Body b1 = f1.getBody();
  Body b2 = f2.getBody();

  // get the objects
  Object o1 = b1.getUserData();
  Object o2 = b2.getUserData();

  // if one of the objects is a marble and the other one is a surface
  if (o1.getClass() == Marble.class && o2.getClass() == Surface.class) {
    Marble m = (Marble) o1;
    Surface s = (Surface) o2;
    // and the surface is red, tell the marble it is colliding with a red platform
    if (s.isRed) {
      m.enterCollRed();
    }
  }

  //the same, just flipped
  if (o1.getClass() == Surface.class && o2.getClass() == Marble.class) {
    Surface s = (Surface) o1;
    Marble m = (Marble) o2;
    if (s.isRed) {
      m.enterCollRed();
    }
  }

  //check if it's a portal
  if (o1.getClass() == Marble.class && o2.getClass() == Portal.class) {
    Marble m = (Marble) o1;
    Portal p = (Portal) o2;

    // only if there are at least 2 portals in the level q
    if (portals.size()>1) 
      teleport(p, m);
  }

  if (o1.getClass() == Portal.class && o2.getClass() == Marble.class) {
    Portal p = (Portal) o1;
    Marble m = (Marble) o2;

    if (portals.size()>1) 
      teleport(p, m);
  }
}

// call the marble to order a teleportation to another portal
void teleport(Portal p, Marble m) {

  // get the index of the enter portal
  int portalIndex = portals.indexOf(p);

  // cache the index of a randomly chosen portal
  int exitPortalIndex = portalIndex;
  // if the exit portal is the enter portal, roll the die again
  while (exitPortalIndex == portalIndex) {
    exitPortalIndex = floor(random(0, portals.size()));
  }

  Portal newPort = portals.get(exitPortalIndex);
  Vec2 pos = new Vec2((int)newPort.boundingBox.getCenterX(), (int)newPort.boundingBox.getCenterY());
  m.orderTeleport(pos, portalIndex, exitPortalIndex);
}

// objects stopped colliding
void endContact(Contact cp) {

  //the same procedure as with the collision detection
  Fixture f1 = cp.getFixtureA();
  Fixture f2 = cp.getFixtureB();
  Body b1 = f1.getBody();
  Body b2 = f2.getBody();
  Object o1 = b1.getUserData();
  Object o2 = b2.getUserData();

  // only need to check if one of the objects is a marble, since it's not touching anything
  if (o1.getClass() == Marble.class) {
    Marble m = (Marble) o1;
    m.exitCollRed();
  }
  if (o2.getClass() == Marble.class) {
    Marble m = (Marble) o2;
    m.exitCollRed();
  }

  if (o1.getClass() == Marble.class && o2.getClass() == Portal.class) {
    Marble m = (Marble) o1;
    Portal p = (Portal) o2;

    exitPort(p, m);
  }

  if (o1.getClass() == Portal.class && o2.getClass() == Marble.class) {
    Portal p = (Portal) o1;
    Marble m = (Marble) o2;

    exitPort(p, m);
  }
}

void exitPort(Portal p, Marble m) {
  int portalIndex = portals.indexOf(p);
  m.reportExitPortal(portalIndex);
}

