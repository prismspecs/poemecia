class ROI {
  float x, y, w, h;
  int scaledX, scaledY, scaledW, scaledH;
  boolean active = false;
  int id;
  boolean onDisplay = false;  // if its currently showing

  // making haiku ;o
  String phrase;
  String displayText;  // in case too many characters...
  int syllables;

  // make sure it doesnt trigger too often
  long lastTrigger = 0;
  int triggerBuffer = 1000;

  ROI (String phrase, int syllables, int id, float w, float h, int wbuffer, int hbuffer) {
    // yummy
    this.phrase = phrase;
    displayText = phrase;

    // limit character count to 14
    if (this.phrase.length() > 17) displayText = this.phrase.substring(0, 14) + "...";  
    this.syllables = syllables;

    // identifier
    this.id = id;

    // scaled values for later embiggening
    scaledX = int(map(x, 0, width, 0, camW));
    scaledY = int(map(y, 0, height, 0, camH));
    scaledW = int(map(w, 0, width, 0, camW));
    scaledH = int(map(h, 0, height, 0, camH));


    // buffer for organization
    this.x = x + wbuffer;
    this.y = y + hbuffer;
    this.w = w - (wbuffer * 2);
    this.h = h - (hbuffer * 2);
  }

  void resetPosition () {
    // scaled values for later embiggening
    scaledX = int(map(x, 0, width, 0, camW));
    scaledY = int(map(y, 0, height, 0, camH));
    scaledW = int(map(w, 0, width, 0, camW));
    scaledH = int(map(h, 0, height, 0, camH));
  }

  void check() {

    // only check if it's been a bit since this one triggered
    // also only if not already active in current poem
    if ( millis() > lastTrigger + triggerBuffer && !active) {

      // loop thru the pixels inside of roi
      // first create a counter variable which stores how many
      // pixels inside the roi are active
      int theCount = 0;

      for (int xx = scaledX; xx < scaledW + scaledX; xx++) {
        for (int yy = scaledY; yy < scaledH + scaledY; yy++) {
          // extract color of each particular pixel
          color currColor = movementImg.get(xx, yy);

          // if it's not a black pixel
          if (brightness(currColor) > 1) {
            theCount++;
          }
        }
      }

      // done looping, what's theCount?
      if (theCount > (w * h) * movementThreshRatio) {
        active = true;  // the area is active enough

        // add it to the stack
        phraseStack.add(new Phrase(phrase, syllables));
        checkForPoem();  // make a poem if possible

        // set trigger time
        lastTrigger = millis();
      } else {
        active = false;  // nope
      }
    }
  }

  void display() {
    // draw the roi (or dont)

    if (active)
      fill(255, 15, 15);
    else
      fill(255, 150);

    // print the word
    text(displayText, x, y);
  }
}