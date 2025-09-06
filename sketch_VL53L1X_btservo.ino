#include <SoftwareSerial.h>

#include <Wire.h>
#include <VL53L1X.h>
#include <Servo.h>

// Bluetooth

#define BT_RX_PIN 2  // BluetoothモジュールのTX → ArduinoのRX (D2)
#define BT_TX_PIN 3  // BluetoothモジュールのRX → ArduinoのTX (D3)
SoftwareSerial btSerial(BT_RX_PIN, BT_TX_PIN);

VL53L1X sensor;
Servo Servo1; // 方向をむく
Servo Servo2; // トリガー往復

const int SERVO1_PIN = 6;
const int SERVO2_PIN = 7;

int currentAngle1 = 90; // 初期角度
int currentAngle2 = 0;

//サーボ2の往復
bool wasInRange = false;    // 前回の状態
bool toggle = false;        // サーボ2のトグル動作用

void setup()
{
  // PCとのシリアル通信を開始（デバッグ用）
  Serial.begin(9600); // PCのシリアルモニターに表示するためのボーレート
  while (!Serial) {
  }
  Serial.println("Arduino Starting Up..."); // 起動メッセージをPCに送信

  btSerial.begin(115200); // Bluetoothモジュールとのシリアル通信を開始
  Serial.println("Bluetooth Serial Initialized."); // PCにメッセージ送信

  Wire.begin();
  Wire.setClock(400000); // I2C高速通信

  Servo1.attach(SERVO1_PIN); // サーボをピンに接続
  Servo2.attach(SERVO2_PIN);

  Servo1.write(currentAngle1);
  Servo2.write(currentAngle2); // 初期位置（中央）

  sensor.setTimeout(500);
  if (!sensor.init())
  {
    btSerial.println("Failed to detect and initialize sensor!"); // Bluetoothにエラー送信
    Serial.println("Failed to detect and initialize sensor!"); // PCにもエラー送信
    while (1);
  }

  sensor.setDistanceMode(VL53L1X::Long);
  sensor.setMeasurementTimingBudget(50000);
  sensor.startContinuous(50);

  Serial.println("Setup Complete. Starting loop."); // PCに完了メッセージ
}

// グローバル変数
unsigned long lastTriggerTime = 0;
bool servo2Active = false;
const int triggerAngle = 180;
const int defaultAngle = 90;
const unsigned long resetDelay = 1000; // 1秒後に戻す

void loop()
{
int distance = sensor.read();
  // Bluetoothにデータを送信
  btSerial.print("Distance: ");
  btSerial.print(distance);
  btSerial.print(" mm    ");

  // デバッグ用にPCのシリアルモニターにも出力
  Serial.print("Distance: ");
  Serial.print(distance);
  Serial.print(" mm    ");


  
  bool nowInRange = (distance >= 100 && distance <= 1000);

  unsigned long currentTime = millis();

  // --- サーボ2 トリガー ---
  if (nowInRange && !wasInRange) {
    // トリガー角度へ動かす
    Servo2.write(triggerAngle);
    servo2Active = true;
    lastTriggerTime = currentTime;

    btSerial.print(" --> Trigger Servo2 to: ");
    btSerial.println(triggerAngle);
    Serial.print(" --> Trigger Servo2 to: ");
    Serial.println(triggerAngle);
  }

  // --- サーボ2 元に戻す ---
  if (servo2Active && (currentTime - lastTriggerTime >= resetDelay)) {
    Servo2.write(defaultAngle);
    servo2Active = false;

    btSerial.print(" --> Reset Servo2 to: ");
    btSerial.println(defaultAngle);
    Serial.print(" --> Reset Servo2 to: ");
    Serial.println(defaultAngle);
  }

  wasInRange = nowInRange;

  // --- サーボ1（距離に応じた角度） ---
  int angle1 = map(distance, 100, 1000, 0, 180);
  //angle1 = constrain(angle1, 0, 180);
  Servo1.write(angle1);

  btSerial.print("angle1: ");
  btSerial.println(angle1);
  Serial.print("angle1: ");
  Serial.println(angle1);

  delay(100);

  if (sensor.timeoutOccurred()) {
    btSerial.println("Sensor Timeout!");
    Serial.println("Sensor Timeout!");
  }
}
