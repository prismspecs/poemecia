/*
  Biological Random Number Generator
 by Grayson Earle
 
 Now with more Organism Tweeting Capabilities!
 */

// controls
import controlP5.*;
ControlP5 cp5;
boolean showControls = true;
boolean showMovement = false;
boolean showCamera = true;
boolean record = false;
PImage twitterOff;

// syphon
import codeanticode.syphon.*;
SyphonServer server;

// doing video manipulation so we need to include this library
import processing.video.*;

// twitter crap
import java.util.*;
Twitter twitter = new TwitterFactory().getInstance();
long lastTweetSent;
int tweetBuffer = 3000;  // dont send out tweets more often than 3 secs

Capture cam;  // webcam object
int camW = 800;
int camH = 600;
PImage movementImg;  // this hold the black and white movement image

int[] previousFrame; // keeps track of the previous pixel array
int numPixels;       // how many pixels (width * height of camera dimensions)
int movementThreshold = 60;  // per pixel, what represents movement?
float movementThreshRatio = .045;  // per ROI, what represents movement?

ArrayList<ROI> roi = new ArrayList<ROI>();
// keep a stack so big syllable count phrases arent thrown out entirely
ArrayList<Phrase> phraseStack = new ArrayList<Phrase>();
// spots we can position the next available phrase (after one goes away)
ArrayList<PVector> availablePositions = new ArrayList<PVector>();


// for poem generation
String entirePoem;
String line1 = "";
String line2 = "";
String line3 = "";
int currentSyllableCount;

Table table;  // for nsa term lookup

PFont font;

boolean currentlyTweeting = false;  // only actively tweet when we wanna (good for reloading slide)

void settings() {
  size(1280, 1024, P3D);
  PJOGL.profile=1;
}

void setup() {

  // Create syhpon server to send frames out.
  server = new SyphonServer(this, "Processing Syphon");

  // connect to twitter API
  connectTwitter();
  twitterOff = loadImage("twitter_off.png");
  twitterOff.resize(30, 30);

  // text properties
  textAlign(LEFT, TOP);
  font = loadFont("source20.vlw");
  textFont(font, 20);

  // set up camera
  printArray(Capture.list());
  cam = new Capture(this, Capture.list()[3]);
  //cam = new Capture(this, camW, camH, 30);  // width, height, fps
  cam.start();  // vroom

  //numPixels = cam.width * cam.height;  // total number of pixels in webcam image
  numPixels = camW * camH;
  previousFrame = new int[numPixels];  // create array to store previous frame pixel data

  movementImg = new PImage (camW, camH);  // an image to show which pixels are different between frames

  // controls
  cp5 = new ControlP5(this);
  cp5.addSlider("movementThreshold")
    .setPosition(10, 10)
    .setRange(0, 150)
    ;
  cp5.addSlider("movementThreshRatio")
    .setPosition(10, 30)
    .setRange(0.0, 0.1)
    ;
  cp5.addToggle("showMovement")
    .setPosition(10, 50)
    ;
  cp5.addToggle("showCamera")
    .setPosition(10, 90)
    ;
  cp5.addToggle("currentlyTweeting")
    .setPosition(10, 130)
    ;
  cp5.addToggle("record")
    .setPosition(10, 170)
    ;

  cp5.loadProperties();

  // set up organizational parameters
  int ROIColumns = 6;
  int ROIRows = 40;
  float ROIWidth = width / float(ROIColumns);
  float ROIHeight = height / float(ROIRows);
  int ROIWBuffer = 0;
  int ROIHBuffer = 0;

  // load up the nsa terms
  table = loadTable("terms.csv", "header");

  int index = 0;

  for (TableRow row : table.rows()) {

    String phrase = row.getString("phrase");
    int syllableCount = row.getInt("syllablecount");

    //roi.add(new ROI(phrase, syllableCount, x, y, ROIWidth, ROIHeight, ROIWBuffer, ROIHBuffer));
    roi.add(new ROI(phrase, syllableCount, index, ROIWidth, ROIHeight, ROIWBuffer, ROIHBuffer));

    index++;
  }

  // terms have been loaded into ROI objects, shuffle 'em
  Collections.shuffle(roi);

  // where to initially place the ROI
  float xPos = 0;
  float yPos = 0;

  for (int i = 0; i < ROIColumns * ROIRows; i++) {
    ROI r = roi.get(i);

    r.onDisplay = true;

    r.x = xPos;
    r.y = yPos;

    // wrap
    xPos += ROIWidth;
    if (xPos + ROIWidth > width) {
      xPos = 0;
      yPos += ROIHeight;
    }
  }
}

void draw() {
  if (cam.available()) {

    cam.read();

    // going to be analyzing these pixels so we need to load them
    cam.loadPixels();

    // must load pixels before manipulation
    movementImg.loadPixels();

    // This part is advanced in the way that it derives RGB data from the color hex,
    // just know that it is calculating the color difference between frames
    for (int i = 0; i < numPixels; i++) {
      int movementSum = 0;
      color currColor = cam.pixels[i];
      color prevColor = previousFrame[i];
      int currR = (currColor >> 16) & 0xFF;
      int currG = (currColor >> 8) & 0xFF;
      int currB = currColor & 0xFF;
      int prevR = (prevColor >> 16) & 0xFF;
      int prevG = (prevColor >> 8) & 0xFF;
      int prevB = prevColor & 0xFF;
      int diffR = abs(currR - prevR);
      int diffG = abs(currG - prevG);
      int diffB = abs(currB - prevB);

      // add any difference to the movementSum var
      movementSum += diffR + diffG + diffB;

      // given the movement sum, make a call on whether this pixel
      // should be white or black (based on the threshold below)
      if (movementSum > movementThreshold) {
        // if we crossed threshold, this pixel becomes white
        movementImg.pixels[i] = color(255);
      } else {
        // if not, let's paint in black
        movementImg.pixels[i] = color(0);
      }

      // reset previousFrame array for next comparison
      previousFrame[i] = currColor;

      // have to call an update pixels once you are done drawing to a PImage
      movementImg.updatePixels();
      cam.updatePixels();
    }

    background(0);

    // show the images (or dont)
    imageMode(CORNER);
    if (showMovement) {
      //tint(255, 255);  // semi transparent
      image(movementImg, 0, 0, width, height);
    }
    if (showCamera) {
      //tint(255, 127);
      image(cam, 0, 0, width, height);
    }


    for (ROI r : roi) {
      if (r.onDisplay) {
        r.check();
        r.display();
      }
    }

    // visual marker for tweet activation--ie safe to change slide
    imageMode(CENTER);
    tint(255, 255);
    if (!currentlyTweeting) {
      //image(twitterOff, width - twitterOff.width/2, twitterOff.height/2);
    }
  }

  if (record) {
    saveFrame("frames/####-brng.png");
  }

  server.sendScreen();
}

// see if there are enough words in the stack to make a haikuface
void checkForPoem() {
  // first get rid of used phrases
  for (int i = phraseStack.size() - 1; i >= 0; i--) {
    Phrase p = phraseStack.get(i);
    if (p.removeMe) {
      phraseStack.remove(i);
    }
  }

  // check in reverse so last syllable in phrase on previous line doesnt
  // duplicate in first phrase on current line

  // line3
  if (currentSyllableCount >= 12 && currentSyllableCount < 17) {
    // grab a fresh phrase off the stack... if it fits
    for (int i = 0; i < phraseStack.size(); i++) {
      Phrase p = phraseStack.get(i);

      if (p.syllableCount + currentSyllableCount <= 17) {
        line3 += p.phrase;

        // do we need a space after?
        if (currentSyllableCount != 17) line3 += " ";

        currentSyllableCount += p.syllableCount;
        p.removeMe = true;
      }
    }
  }

  // line2
  if (currentSyllableCount >= 5 && currentSyllableCount < 12) {
    // grab a fresh phrase off the stack... if it fits
    for (int i = 0; i < phraseStack.size(); i++) {
      Phrase p = phraseStack.get(i);

      if (p.syllableCount + currentSyllableCount <= 12) {
        line2 += p.phrase;

        // do we need a space after?
        if (currentSyllableCount != 12) line2 += " ";

        currentSyllableCount += p.syllableCount;
        p.removeMe = true;
      }
    }
  }

  // build line1
  if (currentSyllableCount < 5) {
    // grab a fresh phrase off the stack... if it fits
    for (int i = 0; i < phraseStack.size(); i++) {
      Phrase p = phraseStack.get(i);

      if (p.syllableCount + currentSyllableCount <= 5) {
        line1 += p.phrase;

        // do we need a space after?
        if (currentSyllableCount != 5) line1 += " ";

        currentSyllableCount += p.syllableCount;
        p.removeMe = true;
      }
    }
  }

  if (currentSyllableCount == 17) {
    // poem complete!

    // remove all active phrases
    for (ROI r : roi) {

      if (r.active) {
        // not on display any longer, sucker
        r.onDisplay = false;

        // add the late ROI's position to the stack of available positions
        availablePositions.add(new PVector(r.x, r.y));
      }
    }

    // re-populate!
    while (availablePositions.size() > 0) {
      for (int i = roi.size() - 1; i >= 0; i--) {
        ROI r = roi.get(i);

        // found one that is not on display
        if (!r.onDisplay) {
          // grab available position
          PVector newPos = availablePositions.get(0);
          // set ROI to that position
          r.x = newPos.x;
          r.y = newPos.y;
          r.resetPosition();
          //println(r.x, r.y);
          // make it show
          r.onDisplay = true;
          // remove that position
          availablePositions.remove(0);

          break;
        }
      }
    }


    entirePoem = line1 + "\n" + line2 + "\n" + line3;
    println(entirePoem);
    println();

    // reset!
    currentSyllableCount = 0;
    line1 = "";
    line2 = "";
    line3 = "";

    for (ROI r : roi) {
      r.active = false;
    }

    if (millis() > lastTweetSent + tweetBuffer && currentlyTweeting) {
      thread("sendTweet");  // testing...
      lastTweetSent = millis();
    }
  }
}

void keyPressed() {
  switch(key) {
  case 'a':
    currentlyTweeting = !currentlyTweeting;
    break;

    // hide, save, and load control p5 slider values
  case 's':
    cp5.saveProperties();
    break;
  case 'l':
    cp5.loadProperties();
    break;
  case 'h':
    showControls = !showControls;
    if (!showControls)
      cp5.hide();
    else
      cp5.show();
    break;
  }
}