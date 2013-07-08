#include <ruby.h>
#include <wiringPi.h>
#include <wiringShift.h>
#include <stdio.h>
#include <stdbool.h>

#define DEBUG false
#define SERIAL_TIMEOUT 1000
#define VOICE_COMMAND_TIMEOUT 10000   // Allow voice commands up to 10 seconds after the door closes

#define scanDataPin  0
#define scanLatchPin 2
#define scanClockPin 3

#define inputClockPin 12
#define inputLatchPin 13
#define inputDataPin  14

#define outputDataPin  11
#define outputLatchPin 10
#define outputClockPin 6

#define btn0 0
#define btn1 1
#define btn2 2
#define btn3 3
#define btn4 4
#define btn5 5
#define btn6 6
#define btn7 7
#define btn8 8
#define btn9 9
#define btnWeightDefrost 10
#define btnJetDefrost 11
#define btnPreset 12
#define btnTime 13
#define btnExpress 14
#define btnCancel 15
#define btnPower 16
#define btnMemory 17
#define btnClock 18
#define btnStart 19

#define newBtnHigh10s 1
#define newBtnHigh20s 2
#define newBtnHigh30s 3
#define newBtnHigh1m 4
#define newBtnHigh2m 5
#define newBtnMed10s 6
#define newBtnMed20s 7
#define newBtnMed30s 8
#define newBtnMed1m 9
#define newBtnMed2m 0
#define newBtnStart 10
#define newBtnStop 11
#define newBtn10s 12
#define newBtn10m 13
#define newBtnMed 14
#define newBtnDefrost 15
#define newBtn1s 16
#define newBtn1m 17
#define newBtnHigh 18
#define newBtnLow 19

#define doorSwitch 0x40 // B01000000
#define buttonMask 0x3F // B00111111

const int MAX_SECONDS   = 5999; // (99 * 60) + 59
const int POWER_HIGH    = 10;
const int POWER_MEDIUM  = 7;
const int POWER_LOW     = 5;
const int POWER_DEFROST = 3;
const int POWER_ZERO    = 0;

// btnMatrix[VCC Pin][GND Pin]
int btnMatrix[6][6] = {
  {-1, -1, -1, -1, -1, 19},
  {-1,  0,  1,  2,  3, -1},
  {-1,  4,  5,  6,  7, -1},
  {10,  8,  9, 12, 15, -1},
  {-1, 13, 18, 11, 16, -1},
  {17, -1, 14, -1, -1, -1}
};

char btnNames[][15] = {
  "0",
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "Weight Defrost",
  "Jet Defrost",
  "Pre-set",
  "Time",
  "Express",
  "Cancel",
  "Power",
  "Memory",
  "Clock",
  "Start"
};

char btnNamesNew[][22] = {
  "Quickstart Medium 2m",
  "Quickstart High 10s",
  "Quickstart High 20s",
  "Quickstart High 30s",
  "Quickstart High 1m",
  "Quickstart High 2m",
  "Quickstart Medium 10s",
  "Quickstart Medium 20s",
  "Quickstart Medium 30s",
  "Quickstart Medium 1m",
  "Start",
  "Stop",
  "Time 10s",
  "Time 10m",
  "Power Medium",
  "Power Defrost",
  "Time 1s",
  "Time 1m",
  "Power High",
  "Power Low"
};

uint8_t inputByte, buttonByte, scanMask;
int currentButton = -1;
int lastButton = -1;
int lastPushedButton = -1;
bool on       = false;
bool paused   = false;
bool doorOpen = false;
bool pendingStart = false;
bool buttonLock = false;

VALUE commandFromVoice = Qfalse;
int  currentPower = 0;
int  currentTime  = 0;

char serCommand, serParams;

unsigned long serialTimer, buttonTimer, countdownTimer, doorTimer;

VALUE rbMicrowaveExt, rbAudioPlayerModule;

void playSound(const char *methodName) {
  rb_funcall(rbAudioPlayerModule, rb_intern(methodName), 0, NULL);
}

void printBinary(uint8_t var) {
  uint8_t mask;
  for (mask = 0x80; mask; mask >>= 1) {  // B10000000
      printf(mask & var ? "1" : "0");
  }
  printf("\n");
}

// Check voice commands
bool voiceCommandAllowed() {
  if (commandFromVoice != Qfalse) {
    return millis() - VOICE_COMMAND_TIMEOUT < doorTimer;
  }
  return true;
}

// If multiple buttons are pressed, this
// function just returns the first detected button.
// Stop pressing so many buttons at once.
int pressedButton(uint8_t vccByte, uint8_t gndByte) {
  int vcc, gnd, button;

  for (vcc = 0; vcc < 6; vcc++) {
    if (vccByte & (0x40 >> vcc)) {  // B01000000
      for (gnd = 0; gnd < 6; gnd++) {
        if (gndByte & (0x20 >> gnd)) {  // B00100000
          button = btnMatrix[vcc][gnd];
          if (button != -1) {
            return button;
          }
        }
      }
    }
  }

  return -1;
}

// Find button in matrix
bool findButton(int button, int pins[]) {
  int vcc, gnd;
  for (vcc = 0; vcc < 6; vcc++) {
    for (gnd = 0; gnd < 6; gnd++) {
      if (btnMatrix[vcc][gnd] == button) {
        pins[0] = vcc;
        pins[1] = gnd;
        return true;
      }
    }
  }
  return false;
}

void pushButton(int button) {
  int buttonPins[2];
  uint8_t vccByte, gndByte;

  if (DEBUG) {
    printf("Pressing: ");
    printf("%s", btnNames[button]);
  }

  if (findButton(button, buttonPins)) {
    // Ensure buttons aren't being pushed by multiple threads.
    while (buttonLock) { delay(25); }
    buttonLock = true;

    // VCC 1,2,3,4,5,6 = 7,6,5,4,3,2 (second register)
    // GND 1,2,3,4,5,6 = 7,6,5,4,3,2 (first register)
    vccByte = 0x40 >> buttonPins[0]; // B01000000
    gndByte = 0x40 >> buttonPins[1]; // B01000000

    // Only need a 'off' delay when pushing the same button twice
    if (lastPushedButton == button) { delay(25); }

    digitalWrite(outputLatchPin, LOW);
    shiftOut(outputDataPin, outputClockPin, MSBFIRST, vccByte);
    shiftOut(outputDataPin, outputClockPin, MSBFIRST, gndByte);
    digitalWrite(outputLatchPin, HIGH);

    // Start button needs a longer press
    delay(button == btnStart ? 64 : 25);

    digitalWrite(outputLatchPin, LOW);
    shiftOut(outputDataPin, outputClockPin, MSBFIRST, 0);
    shiftOut(outputDataPin, outputClockPin, MSBFIRST, 0);
    digitalWrite(outputLatchPin, HIGH);

    buttonLock = false;
    lastPushedButton = button;
  }
}

void setTime(int totalSeconds) {
  int minutes, seconds;

  if (totalSeconds > MAX_SECONDS) { return; }

  // Setting time will stop the microwave
  if (on) { on = false; }

  currentTime = totalSeconds;

  pushButton(btnTime);

  minutes = totalSeconds / 60;
  seconds = totalSeconds % 60;

  if (minutes != 0) {
    if (minutes / 10 != 0) {
      pushButton(minutes / 10);
    }
    pushButton(minutes % 10);
  }
  if (seconds >= 10 || minutes != 0) {
    pushButton(seconds / 10);
  }
  pushButton(seconds % 10);
}

void incrementTime(int extraSeconds) {
  if (currentTime + extraSeconds > MAX_SECONDS) { currentTime = 0; }
  setTime(currentTime + extraSeconds);
}

void setPower(int power) {
  if (power < 0 || power > 10) { return; }

  currentPower = power;

  pushButton(btnPower);

  if (power == 10) {
    pushButton(1);
    pushButton(0);
  } else {
    pushButton(power);
  }
}

// time is an int, of the form 'hhmm', without leading zeros.
// Times must be between 1:00 and 12:59
void setClock(unsigned int time) {
  if (time > 1259 || time < 100 || time % 100 > 59 ) { return; }

  pushButton(btnClock);
  pushButton(btnCancel);

  if (time >= 1000) { pushButton(1); }
  pushButton(time % 1000 / 100);
  pushButton(time % 100 / 10);
  pushButton(time % 10);

  pushButton(btnClock);
}

void start() {
  // Only start if door is closed
  if (!doorOpen) {
    if (currentTime > 0) {
      pushButton(btnStart);
      on = true;
      pendingStart = false;
      // Set door timer to 0, so that no further commands are run
      doorTimer = 0;
      // Set countdown timer to decrement time remaining
      countdownTimer = millis();
      // Only play start sound if microwave wasn't previously paused
      if (!paused) { playSound("start"); }
      paused = false;
    }
  } else {
    // Record the fact that start was pushed while the door was open.
    // Once door is closed, start the microwave.
    pendingStart = true;
  }
}

void stop() {
  pushButton(btnCancel);
  on = false;
  paused = false;
  pendingStart = false;
  currentTime = 0;
  currentPower = 0;
}

void pauseMicrowave() {
  // Can only pause when microwave is on
  if (on) {
    pushButton(btnTime);
    on = false;
    paused = true;
  }
}

void quickStart(int seconds, int power) {
  setTime(seconds);
  setPower(power);
  start();
}

uint8_t shiftIn2(int dataPin, int clockPin, int latchPin) {
  int i;
  int tmp = 0;
  uint8_t dataIn = 0;

  digitalWrite(latchPin, HIGH);
  delayMicroseconds(300);
  digitalWrite(latchPin, LOW);

  for (i = 7; i >= 0; i--) {
    digitalWrite(clockPin, LOW);
    delayMicroseconds(300);
    tmp = digitalRead(dataPin);
    if (tmp) {
      dataIn = dataIn | (1 << i);
    }
    digitalWrite(clockPin, HIGH);
    delayMicroseconds(100);
  }

  return dataIn;
}

void pushNewButton(int button) {
  // Only play button sound for time and power buttons
  switch (button) {
    case newBtn10s:
    case newBtn10m:
    case newBtn1s:
    case newBtn1m:
    case newBtnHigh:
    case newBtnMed:
    case newBtnLow:
    case newBtnDefrost:
      playSound("button");
      break;
  }

  switch (button) {
    case newBtnHigh10s: quickStart(10,  POWER_HIGH); break;
    case newBtnHigh20s: quickStart(20,  POWER_HIGH); break;
    case newBtnHigh30s: quickStart(30,  POWER_HIGH); break;
    case newBtnHigh1m:  quickStart(60,  POWER_HIGH); break;
    case newBtnHigh2m:  quickStart(120, POWER_HIGH); break;
    case newBtnMed10s:  quickStart(10,  POWER_MEDIUM); break;
    case newBtnMed20s:  quickStart(20,  POWER_MEDIUM); break;
    case newBtnMed30s:  quickStart(30,  POWER_MEDIUM); break;
    case newBtnMed1m:   quickStart(60,  POWER_MEDIUM); break;
    case newBtnMed2m:   quickStart(120, POWER_MEDIUM); break;
    case newBtn10s:     incrementTime(10); break;
    case newBtn10m:     incrementTime(600); break;
    case newBtn1s:      incrementTime(1); break;
    case newBtn1m:      incrementTime(60); break;
    // Can't set power while microwave is on
    case newBtnHigh:    if (!on) { setPower(POWER_HIGH); }; break;
    case newBtnMed:     if (!on) { setPower(POWER_MEDIUM); }; break;
    case newBtnLow:     if (!on) { setPower(POWER_LOW); }; break;
    case newBtnDefrost: if (!on) { setPower(POWER_DEFROST); }; break;
    case newBtnStart:   start(); break;
    case newBtnStop:    stop(); playSound("stop"); break;
  }
}

// args: command, param, command_from_voice?
static VALUE method_send_command(VALUE self, VALUE args) {
  VALUE command, param;
  char * cmdStr;
  char * paramStr = "";
  int i;

  long len = RARRAY_LEN(args);

  if (len > 3 || len == 0) {
    rb_raise(rb_eArgError, "wrong number of arguments");
  }

  command = rb_ary_entry(args, 0);
  cmdStr = StringValueCStr(command);

  if (len >= 2) {
    param = rb_ary_entry(args, 1);
  }

  // Voice - indicates that the command came from latent speech recognition (no keyword prefix).
  // The command will only be executed if the microwave door was recently closed.
  if (len >= 3) {
    commandFromVoice = rb_ary_entry(args, 2);
  } else {
    commandFromVoice = Qfalse;
  }

  if (strcmp(cmdStr, "button") == 0) {
    if (TYPE(param) == T_STRING) {
      paramStr = StringValueCStr(param);

      for (i = 0; i < sizeof(btnNames) / sizeof(btnNames[0]); i++) {
        if (strcmp(btnNames[i], paramStr) == 0) {
          pushButton(i);
          break;
        }
      }
    }
  }

  if (strcmp(cmdStr, "new_button") == 0) {
    if (TYPE(param) == T_STRING) {
      paramStr = StringValueCStr(param);

      for (i = 0; i < sizeof(btnNamesNew) / sizeof(btnNamesNew[0]); i++) {
        if (strcmp(btnNamesNew[i], paramStr) == 0) {
          pushNewButton(i);
          break;
        }
      }
    }
  }

  else if (strcmp(cmdStr, "clock") == 0) {
    // clock  |  1135  => Set clock to 11:35
    setClock(NUM2INT(param));
  }

  else if (strcmp(cmdStr, "time") == 0) {
    if (voiceCommandAllowed()) {
      setTime(NUM2INT(param));
    }
  }

  else if (strcmp(cmdStr, "power") == 0) {
    // power (integer or level name)
    // Integer:    6     => Set power to 6
    // Level name: high  => Set power to high (10)
    if (voiceCommandAllowed()) {
      if (TYPE(param) == T_STRING) {
        paramStr = StringValueCStr(param);
        if      (strcmp(paramStr, "high") == 0)    { setPower(POWER_HIGH); }
        else if (strcmp(paramStr, "medium") == 0)  { setPower(POWER_MEDIUM); }
        else if (strcmp(paramStr, "low") == 0)     { setPower(POWER_LOW); }
        else if (strcmp(paramStr, "defrost") == 0) { setPower(POWER_DEFROST); }
        else if (strcmp(paramStr, "off") == 0)     { setPower(POWER_ZERO); }

      } else {
        setPower(NUM2INT(param));
      }
    }
  }

  else if (strcmp(cmdStr, "start") == 0) {
    if (voiceCommandAllowed()) { start(); }
  }

  else if (strcmp(cmdStr, "stop") == 0) {
    if (voiceCommandAllowed()) { stop(); }
  }

  else if (strcmp(cmdStr, "pause") == 0) {
    pauseMicrowave();
  }

  return self;
}


VALUE method_get_info(VALUE self) {
  VALUE info = rb_hash_new();

  rb_hash_aset(info, ID2SYM(rb_intern("on")),        on       ? Qtrue : Qfalse);
  rb_hash_aset(info, ID2SYM(rb_intern("paused")),    paused   ? Qtrue : Qfalse);
  rb_hash_aset(info, ID2SYM(rb_intern("door_open")), doorOpen ? Qtrue : Qfalse);
  rb_hash_aset(info, ID2SYM(rb_intern("power")),     INT2FIX(currentPower));
  rb_hash_aset(info, ID2SYM(rb_intern("time")),      INT2FIX(currentTime));

  return info;
}


// Can't do an infinite loop in C, or the Ruby interpreter gets locked up
VALUE method_touchpad_loop(VALUE self) {
  int validReading = 0;

  inputByte = 0;
  //              B00000010              B01000000
  for (scanMask = 0x2; scanMask <= 0x40; scanMask <<= 1) {
    digitalWrite(scanLatchPin, LOW);
    shiftOut(scanDataPin, scanClockPin, MSBFIRST, scanMask);
    digitalWrite(scanLatchPin, HIGH);

    // printf("scanMask:\n");
    // printBinary(scanMask);

    validReading = 0;
    while (validReading == 0) {
      // Ignore first bit (floating)
      inputByte = shiftIn2(inputDataPin, inputClockPin, inputLatchPin) & 0x7F; // B01111111
      delay(2);
      if (inputByte == (shiftIn2(inputDataPin, inputClockPin, inputLatchPin) & 0x7F))
        validReading = 1;
    }

    // printf("inputByte:\n");
    // printBinary(inputByte);

    // 1 = closed, 0 = open
    if (!(inputByte & doorSwitch)) {
      // Stop if door is opened
      if (on) { stop(); }
      if (!doorOpen) {
        if (DEBUG) { printf("Door is now open.\n"); }
        doorOpen = true;
      }
    } else {
      // Set door state if door is now closed
      if (doorOpen) {
        if (DEBUG) { printf("Door is now closed.\n"); }
        doorOpen = false;
        doorTimer = millis(); // Allow voice commands up to 7 seconds after door was closed

        // Check to see if start was pressed while door was open
        // If so, start the microwave now.
        if (pendingStart) { start(); }
      }
    }

    buttonByte = inputByte & buttonMask;

    if (buttonByte != 0) {
      currentButton = pressedButton(scanMask, buttonByte);

      if (currentButton != -1 && currentButton != lastButton) {
        pushNewButton(currentButton);

        lastButton = currentButton;
      }

      buttonTimer = millis();
    } else {
      // Debounce buttons with 100ms delay
      if (lastButton != -1 && millis() - 100 > buttonTimer) {
        lastButton = -1;
        buttonTimer = 0;
      }
    }
  }

  if (on) {
    // Decrement time counter every 1000ms
    if (millis() - 1000 > countdownTimer) {
      countdownTimer = millis();
      currentTime -= 1;
      if (currentTime <= 0) {
        stop();
        playSound("finished");
      }
    }
  }

  delay(10);

  return self;
}

// The initialization method for this module
void Init_microwave() {
  if (wiringPiSetup() == -1)
    printf("wiringPi setup failed!\n");

  // Set pin modes
  pinMode(scanDataPin,    OUTPUT);
  pinMode(scanLatchPin,   OUTPUT);
  pinMode(scanClockPin,   OUTPUT);

  pinMode(inputDataPin,   INPUT);
  pinMode(inputLatchPin,  OUTPUT);
  pinMode(inputClockPin,  OUTPUT);

  pinMode(outputDataPin,  OUTPUT);
  pinMode(outputLatchPin, OUTPUT);
  pinMode(outputClockPin, OUTPUT);

  // Setup class
  rbMicrowaveExt = rb_define_class("MicrowaveExt", rb_cObject);
  rb_define_method(rbMicrowaveExt, "touchpad_loop", method_touchpad_loop, 0);
  rb_define_method(rbMicrowaveExt, "send_command", method_send_command, -2);
  rb_define_method(rbMicrowaveExt, "get_info", method_get_info, 0);

  rbAudioPlayerModule = rb_const_get(rb_cObject, rb_intern("AudioPlayer"));
}
