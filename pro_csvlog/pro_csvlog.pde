import controlP5.*;
import processing.serial.*;

// Processingの設定
ControlP5 cp5;
Serial myPort;
PFont jpFont;
PrintWriter output;

boolean isMeasuring = false;
String bluetoothStatus = "Not connected"; // Bluetoothの接続状態表示

DropdownList portList;
DropdownList baudList;

String selectedPort = "";
int selectedBaud = 115200;

// センサとサーボのデータ
float distance; // 距離センサ (mm単位で受け取るのでfloat)
int servo1Angle = 0;
int servo2Angle = 0;

void setup() {
  size(800, 500); // Bluetoothの設定画面のサイズ
  cp5 = new ControlP5(this);

  // 日本語フォントの設定
  //jpFont = loadFont("MS-Gothic-16.vlw");
 // textFont(jpFont);

  String[] ports = Serial.list();
  println("Available ports:", ports);

  // ポート選択ドロップダウンリスト
  portList = cp5.addDropdownList("Select Port")
                .setPosition(50, 30)
                .setSize(150, 200)
                .setItemHeight(20)
                .setBarHeight(20);
  for (int i = 0; i < ports.length; i++) {
    portList.addItem(ports[i], i);
  }

  // ボーレート選択ドロップダウンリスト
  baudList = cp5.addDropdownList("Select Baud")
                .setPosition(220, 30)
                .setSize(100, 100)
                .setItemHeight(20)
                .setBarHeight(20);
  baudList.addItem("9600", 9600);
  baudList.addItem("115200", 115200);
  baudList.setValue(115200); // Arduinoに合わせて初期値を115200に設定

  // 各種ボタン
  cp5.addButton("connectBluetooth")
     .setLabel("Bluetooth connecting")
     .setPosition(50, 250)
     .setSize(150, 40);

  cp5.addButton("startMeasurement")
     .setLabel("start")
     .setPosition(220, 250)
     .setSize(150, 40);

  cp5.addButton("stopMeasurement")
     .setLabel("finish")
     .setPosition(400, 250)
     .setSize(150, 40);

  cp5.addButton("disconnectBluetooth")
     .setLabel("Bluetooth dsiconnecting")
     .setPosition(570, 250)
     .setSize(150, 40);
}

void draw() {
  background(240); // 背景色
  fill(0); // 文字色
  textSize(18); // 文字サイズ
  text("Bluetooth status: " + bluetoothStatus, 350, 80);

  // 計測中で、かつポートが接続されており、受信データがある場合に読み込み
  if (isMeasuring && myPort != null && myPort.available() > 0) {
    readSerialData();
  }

  // 測定値とサーボ角度の表示
  textSize(24); // 大きな文字で表示
  text("distance: " + distance + " mm", 350, 140);
  text("servo1 angle: " + servo1Angle, 350, 180);
  text("servo2 angle: " + servo2Angle, 350, 220);
}

void readSerialData() {
  try {
    // 1行分のデータを読み込む
    String line = myPort.readStringUntil('\n');
    if (line != null) {
      line = trim(line); // 前後の空白を削除
      // Arduinoからの出力形式を考慮してパース
      // 例: "Distance: 250 mm      angle1: 90" のような形式を想定
      // まず "Distance: " と " mm      angle1: " で分割

      if (line.contains("Distance: ") && line.contains("mm") && line.contains("angle1: ")) {
        // 距離の抽出
        int distStartIndex = line.indexOf("Distance: ") + "Distance: ".length();
        int distEndIndex = line.indexOf(" mm");
        if (distStartIndex != -1 && distEndIndex != -1 && distEndIndex > distStartIndex) {
          String distStr = line.substring(distStartIndex, distEndIndex).trim();
          distance = float(distStr);
        }

        // サーボ1の角度の抽出
        int angle1StartIndex = line.indexOf("angle1: ") + "angle1: ".length();
        if (angle1StartIndex != -1) {
          String angle1Str = line.substring(angle1StartIndex).trim();
          servo1Angle = int(angle1Str);
        }
      }
      
      // サーボ2のトリガーメッセージの検出
      // 例: " --> Trigger Servo2 to: 0"
      if (line.contains("Trigger Servo2 to: ")) {
        int angle2StartIndex = line.indexOf("Trigger Servo2 to: ") + "Trigger Servo2 to: ".length();
        String angle2Str = line.substring(angle2StartIndex).trim();
        servo2Angle = int(angle2Str);
      }

      // ログファイルへの書き込み
      if (output != null) {
        String currentTime = nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
        // Arduinoの出力形式に合わせて、ログのフォーマットを調整
        output.println(currentTime + "," + distance + "," + servo1Angle + "," + servo2Angle);
      }
    }
  } catch (Exception e) {
    println("date analytics error: " + e.getMessage());
  }
}

// ドロップダウンの選択処理
void controlEvent(ControlEvent theEvent) {
  if (theEvent.isFrom(portList)) {
    int index = int(theEvent.getValue());
    selectedPort = Serial.list()[index];
    println("Selected Port:", selectedPort);
  }
  if (theEvent.isFrom(baudList)) {
    selectedBaud = int(theEvent.getValue());
    println("Select Baud Rate:", selectedBaud);
  }
}

// ボタン処理
void connectBluetooth() {
  if (selectedPort != null && selectedPort.length() > 0 && myPort == null) {
    try {
      myPort = new Serial(this, selectedPort, selectedBaud);
      myPort.clear();
      bluetoothStatus = "Connecting";
      println("Connection successful:", selectedPort, selectedBaud);
    } catch (Exception e) {
      println("Connection failed: " + e.getMessage());
      bluetoothStatus = "Connection failed";
    }
  } else {
    println("The port is not selected or is already connected.");
  }
}

void startMeasurement() {
  if (myPort != null) {
    isMeasuring = true;
    // ログファイル名にタイムスタンプを付与
    String timestamp = nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_" +
                       nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
    output = createWriter("sensor_log_" + timestamp + ".csv");
    // ログファイルのヘッダー行
    output.println("Time,Distance(mm),angleServo1,angleServo2");
    println("Start measurement");
  } else {
    println("Bluetooth Disconnnected");
  }
}

void stopMeasurement() {
  isMeasuring = false;
  
  if (output != null) {
    output.flush();  // バッファを保存
    output.close();  // ファイルを閉じる
    output = null;
  }
  
  println("Measurement End");
}

void disconnectBluetooth() {
  if (myPort != null) {
    myPort.stop();
    myPort = null;
    bluetoothStatus = "Not connected";
    isMeasuring = false;
    println("Disconnecting from Bluetooth");
  }
}
