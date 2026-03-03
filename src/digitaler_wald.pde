// 🌳🌧️ Forest Seasons + Red Game of Life Overlay (Interpolated Leaves)
// by ChatGPT (2025)

import processing.serial.*;
Serial myPort;

// --------------------- Forest Variables ---------------------
int pot1 = 0, pot2 = 0, pot3 = 0, pot4 = 1023;
float t = 0;
float noiseScale = 0.012;

int treeCount = 16;
int baseLeaves = 800;
int baseMushrooms = 100;
int maxDrops = 1000;

Raindrop[] drops;
Tree[] trees;
Leaf[] leaves;
Mushroom[] mushrooms;

// --------------------- Game of Life Variables ---------------------
int pixelSize = 10;
int cols, rows;
boolean[][] current;
boolean[][] next;
color[][] cellColor;

// ------------------------------------------------------------
// SETUP
// ------------------------------------------------------------
void setup() {
  size(1300, 1000);
  smooth(8);
  colorMode(HSB, 360, 100, 100, 100);
  frameRate(30);

  println("Connecting to serial...");
  try {
    myPort = new Serial(this, "/dev/cu.usbserial-A10N81H1", 9600);
    myPort.bufferUntil('\n');
    println("✅ Serial connected!");
  } catch (Exception e) {
    println("⚠️ Serial not available. Running in demo mode.");
  }

  // 🌧️ Raindrops
  drops = new Raindrop[maxDrops];
  for (int i = 0; i < maxDrops; i++) {
    drops[i] = new Raindrop(random(width), random(-600, 0), random(2, 6));
  }

  // 🍄 Mushrooms
  mushrooms = new Mushroom[baseMushrooms * 2];
  for (int i = 0; i < mushrooms.length; i++) {
    mushrooms[i] = new Mushroom(random(width), random(height * 0.65, height * 0.95), random(15, 50));
  }

  // 🍃 Leaves
  leaves = new Leaf[baseLeaves];
  for (int i = 0; i < baseLeaves; i++) {
    float y;
    float r = random(1);
    if (r < 0.05) y = random(0, 100);
    else if (r < 0.95) y = random(100, height * 0.66);
    else y = random(height * 0.66, height);
    leaves[i] = new Leaf(random(width), y);
  }

  // 🌳 Trees
  trees = new Tree[treeCount];
  for (int i = 0; i < treeCount; i++) {
    trees[i] = new Tree(random(width), random(height * 0.65, height * 0.95), random(140, 240));
  }

  // 🧬 Game of Life setup
  cols = width / pixelSize;
  rows = height / pixelSize;
  current = new boolean[cols][rows];
  next = new boolean[cols][rows];
  cellColor = new color[cols][rows];
}

// ------------------------------------------------------------
// DRAW
// ------------------------------------------------------------
void draw() {
  background(0);
  t += 0.005;

  // ---------- FOREST ----------
  int dropsToDraw = int(map(pot1, 0, 1023, 0, maxDrops));
  float saturation = map(pot4, 0, 1023, 0, 1023);
  float groundDensity = map(pot3, 0, 1023, 0.1, 2.0);

  // 🍂 SEASONS (interpolated)

  float leafHueMin, leafHueMax, leafSizeMin, leafSizeMax;
  float leafCountFactor, mushroomFactor;

  // --- Base season keyframes ---
  float[] leafHueMins = {45, 30, 100, 85};
  float[] leafHueMaxs = {75, 50, 130, 110};
  float[] leafSizeMins = {8, 8, 6, 10};
  float[] leafSizeMaxs = {20, 20, 14, 24};
  float[] leafFactors = {0.9, 0.1, 0.8, 0.9};
  float[] mushroomFactors = {0.9, 0.1, 0.4, 0.2};

  // --- Interpolate between the nearest two seasons ---
  float seasonPos = 0;
int s1 = 0, s2 = 0;
float blend = 0;
  blend = pow(blend, 1.4);

  // 🍂 AUTUMN → ❄️ WINTER
  if (pot2 < 256) {
    s1 = 0; s2 = 1;
    blend = map(pot2, 0, 256, 0, 1);
  }
  // ❄️ WINTER → 🌸 SPRING
  else if (pot2 < 512) {
    s1 = 1; s2 = 2;
    blend = map(pot2, 256, 512, 0, 1);
  }
  // 🌸 SPRING → ☀️ SUMMER
  else if (pot2 < 768) {
    s1 = 2; s2 = 3;
    blend = map(pot2, 512, 768, 0, 1);
  }
  // ☀️ SUMMER (no blend)
  else {
    s1 = 3; s2 = 3;
    blend = 0;
  }

  leafHueMin = lerp(leafHueMins[s1], leafHueMins[s2], blend);
  leafHueMax = lerp(leafHueMaxs[s1], leafHueMaxs[s2], blend);
  leafSizeMin = lerp(leafSizeMins[s1], leafSizeMins[s2], blend);
  leafSizeMax = lerp(leafSizeMaxs[s1], leafSizeMaxs[s2], blend);
  leafCountFactor = lerp(leafFactors[s1], leafFactors[s2], blend);
  mushroomFactor = lerp(mushroomFactors[s1], mushroomFactors[s2], blend);

  int leafCount = int(leaves.length * leafCountFactor);
  int mushroomCount = int(mushrooms.length * mushroomFactor);

  // 🌿 Ground
  drawGround(saturation, groundDensity);

  // 🍄 Mushrooms
  for (int i = 0; i < mushroomCount; i++) mushrooms[i].show(saturation);

  // 🌳 Trees
  for (Tree tree : trees) tree.show();

  // 🍃 Leaves
  for (int i = 0; i < leafCount; i++)
    leaves[i].show(saturation, leafHueMin, leafHueMax, leafSizeMin, leafSizeMax);

  // 🌧️ Rain
  for (int i = 0; i < dropsToDraw; i++) {
    drops[i].fall();
    drops[i].show();
  }

  // ---------- GAME OF LIFE LAYER ----------
  runGameOfLife();

  // 🧭 Info
  fill(255);
  text("Rain=" + pot1 + " | Season=" + pot2 + " | CO2=" + pot3 + " | Temp=" + pot4, 20, 20);
}

// ------------------------------------------------------------
// GAME OF LIFE SYSTEM (unchanged)
// ------------------------------------------------------------
void runGameOfLife() {
// ----------------- CUSTOM FIRE ACTIVATION RULES -----------------
float fraction = 0;

// HIGH-PRIORITY KILL SWITCH
if (pot1 >= 512) {
  fraction = 0.0; // immediately kill the fire
  // optional: gradually clear existing cells
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      current[i][j] = false;
    }
  }
}

// Rule 1
if ((pot1 >= 0 && pot1 <= 255) &&
    ((pot2 >= 0 && pot2 <= 255) || (pot2 >= 512 && pot2 <= 767)) &&
    (pot3 >= 512)) {
  fraction = 0.7; // strong fire
}

// Rule 2
else if ((pot1 >= 0 && pot1 <= 255) &&
         (pot2 >= 256 && pot2 <= 511) &&
         (pot3 >= 768 && pot3 <= 1023) &&
         (pot4 >= 512)) {
  fraction = 1.0; // full fire
}

// Rule 3
else if ((pot1 >= 256 && pot1 <= 511) &&
         (pot2 >= 768 && pot2 <= 1023) &&
         (pot3 >= 256) &&
         (pot4 >= 512)) {
  fraction = 0.6; // medium fire
}

// Rule 4
else if ((pot1 >= 768 && pot1 <= 1023) &&
         (pot4 >= 768 && pot4 <= 1023)) {
  fraction = 0.8; // high fire
}

// Rule 5
if ((pot1 >= 0 && pot1 <= 255) &&
    ((pot2 >= 767 && pot2 <= 1023)))
     {
  fraction = 0.7; // strong fire
}

// Otherwise, fire dies out
else {
  fraction = 0.0;
}

// Optional: if fraction == 0, slowly clear existing fire
if (fraction == 0) {
  for (int i=0; i<cols; i++) {
    for (int j=0; j<rows; j++) {
      if (random(1) < 0.02) current[i][j] = false; // gradual decay
    }
  }
}

  addInitialPixels(fraction);
  gameOfLifeStep();

  noStroke();
  colorMode(RGB, 255);
  for (int i=0; i<cols; i++) {
    for (int j=0; j<rows; j++) {
      if (current[i][j]) {
        fill(255, 0, 0);
        rect(i*pixelSize, j*pixelSize, pixelSize, pixelSize);
      }
    }
  }
  colorMode(HSB, 360, 100, 100, 100);
}

void addInitialPixels(float fraction) {
  int totalCells = cols*rows;
  int targetCells = int(totalCells*fraction);
  int currentCells = 0;
  for (int i=0; i<cols; i++)
    for (int j=0; j<rows; j++)
      if (current[i][j]) currentCells++;
  int cellsToAdd = int((targetCells-currentCells)*0.02);
  cellsToAdd = max(cellsToAdd, 0);
  for (int k=0; k<cellsToAdd; k++) {
    int i = int(random(cols));
    int j = int(random(rows));
    if (!current[i][j]) {
      current[i][j] = true;
      cellColor[i][j] = color(255,0,0);
    }
  }
  int cellsToRemove = currentCells - targetCells;
  cellsToRemove = max(cellsToRemove, 0);
  for (int k=0; k<cellsToRemove; k++) {
    int i = int(random(cols));
    int j = int(random(rows));
    if (current[i][j]) current[i][j] = false;
  }
}

void gameOfLifeStep() {
  for (int i=0; i<cols; i++) {
    for (int j=0; j<rows; j++) {
      int neighbors = countNeighbors(i,j);
      if (current[i][j]) {
        next[i][j] = (neighbors==2 || neighbors==3);
      } else {
        next[i][j] = (neighbors==3);
      }
    }
  }
  boolean[][] temp = current;
  current = next;
  next = temp;
}

int countNeighbors(int x,int y) {
  int count = 0;
  for (int i=-1; i<=1; i++) {
    for (int j=-1; j<=1; j++) {
      if (i==0 && j==0) continue;
      int nx = x+i, ny = y+j;
      if (nx>=0 && nx<cols && ny>=0 && ny<rows)
        if (current[nx][ny]) count++;
    }
  }
  return count;
}

// ------------------------------------------------------------
// SERIAL
// ------------------------------------------------------------
void serialEvent(Serial p) {
  String s = trim(p.readStringUntil('\n'));
  if (s == null || s.length() == 0) return;
  try {
    String[] vals = split(s, ',');
    if (vals.length >= 4) {
      pot1 = constrain(int(vals[0]), 0, 1023);
      pot2 = constrain(int(vals[1]), 0, 1023);
      pot3 = constrain(int(vals[2]), 0, 1023);
      pot4 = constrain(int(vals[3]), 0, 1023);
    }
  } catch (Exception e) {
    println("Serial parse error: " + s);
  }
}

// ------------------------------------------------------------
// FOREST CLASSES
// ------------------------------------------------------------
class Raindrop {
  float x, y, len, speed;
  Raindrop(float x_, float y_, float len_) {
    x = x_; y = y_; len = len_;
    speed = map(len, 2, 6, 4, 10);
  }
  void fall() {
    y += speed;
    if (y > height) {
      y = random(-200, 0);
      x = random(width);
    }
  }
  void show() {
    stroke(210, 100, 100);
    strokeWeight(3);
    line(x, y, x, y + len);
  }
}

class Tree {
  float x, y, h, swayPhase;
  Tree(float x_, float y_, float h_) {
    x = x_; y = y_; h = h_;
    swayPhase = random(TWO_PI);
  }
  void show() {
    pushMatrix();
    translate(x, y);
    float sway = sin(frameCount * 0.02 + swayPhase) * radians(4);
    rotate(sway);
    stroke(30, 80, 60);
    strokeWeight(10);
    drawBranch(h, 7);
    popMatrix();
  }
  void drawBranch(float len, int depth) {
    if (len < 8 || depth <= 0) {
      noStroke();
      fill(30, 90, 50, 95);
      ellipse(0, 0, 8, 4);
      return;
    }
    stroke(30, 80, 60);
    strokeWeight(map(depth, 1, 7, 1.5, 5));
    line(0, 0, 0, -len);
    translate(0, -len);
    pushMatrix();
    rotate(radians(18));
    drawBranch(len * 0.72, depth - 1);
    popMatrix();
    pushMatrix();
    rotate(radians(-18));
    drawBranch(len * 0.72, depth - 1);
    popMatrix();
  }
}

class Mushroom {
  float x, y, s;
  float hue;      // fixed per-mushroom hue
  float bright;   // optional fixed brightness variation

  Mushroom(float x_, float y_, float s_) {
    x = x_; y = y_; s = s_;
    // store the hue once (was random(...) inside show())
    hue = random(8, 28);       // choose base hue once
    bright = random(85, 98);   // small per-mushroom brightness variation
  }

  void show(float sat) {
    pushMatrix();
    translate(x, y);
    noStroke();
    // use stored hue and brightness so color is stable between frames
    fill(hue, sat, bright, 92);
    ellipse(0, -s * 0.38, s, s * 0.5);
    fill(0, 0, 100, 95);
    rect(-s * 0.1, 0, s * 0.2, -s * 0.55, s * 0.05);
    popMatrix();
  }
}


class Leaf {
  float baseX, baseY, s, hue, angle;
  Leaf(float x_, float y_) {
    baseX = x_;
    baseY = y_;
    s = random(8, 20);
    hue = random(90, 120);
    angle = random(TWO_PI);
  }
  void show(float sat, float hueMin, float hueMax, float sMin, float sMax) {
    pushMatrix();
    translate(baseX, baseY);
    rotate(angle);
    noStroke();
    float displayHue = map(hue, 90, 120, hueMin, hueMax);
    float displaySize = map(s, 8, 20, sMin, sMax);
    fill(displayHue, sat, 90, 95);
    beginShape();
    vertex(0, 0);
    bezierVertex(displaySize * 0.5, -displaySize, displaySize, 0, 0, displaySize);
    bezierVertex(-displaySize, 0, -displaySize * 0.5, -displaySize, 0, 0);
    endShape(CLOSE);
    popMatrix();
  }
}

/*
void drawGround(float sat, float density) {
  int cell = 6;
  noStroke();
  float correctedSat = constrain(sat / 10.23, 0, 100);
  for (int gx = 0; gx < width; gx += cell) {
    for (int gy = height / 2; gy < height; gy += cell) {
      float n = noise(gx * 0.02, gy * 0.02, t * 0.08);
      if (n > 0.6 - (density * 0.05)) {
        rect(gx, gy, cell - 1, cell - 1);
      }
    }
  }
}
*/

void drawGround(float sat, float density) {
  int cell = 6;
  noStroke();
  float correctedSat = constrain(sat / 10.23, 0, 100);

  colorMode(HSB, 360, 100, 100, 100); // add alpha to HSB
  float baseHue = 30;   // brownish
  float baseBrightness = 50;

  for (int gx = 0; gx < width; gx += cell) {
    for (int gy = height / 2; gy < height; gy += cell) {
      float n = noise(gx * 0.02, gy * 0.02, t * 0.08);
      if (n > 0.6 - (density * 0.05)) {
        // Vary transparency per cell using another noise value
        float alphaNoise = noise(gx * 0.05, gy * 0.05, t * 0.1);
        float alphaVal = map(alphaNoise, 0, 1, 50, 90); // alpha between 50% and 100%
        
        fill(baseHue, correctedSat, baseBrightness, alphaVal);
        rect(gx, gy, cell - 1, cell - 1);
      }
    }
  }
}
