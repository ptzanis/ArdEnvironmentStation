#include <OPC.h>
#include <Bridge.h>
#include <SPI.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME280.h>

OPCSerial myArduinoMEGA;

#define SEALEVELPRESSURE_HPA (1013.25)


Adafruit_BME280 bme; //I2C

float callbackTemperature(const char *itemID, const opcOperation opcOP, const float value){
  return bme.readTemperature();
}
float callbackPressure(const char *itemID, const opcOperation opcOP, const float value){
  return (bme.readPressure()/ 100.0F);
}
float OPCoperation(const char *itemID, const opcOperation opcOP, const float value){
  return 1;
}
float callbackHumidity(const char *itemID, const opcOperation opcOP, const float value){
  return bme.readHumidity();
}


const int LED=53;

void setup() {
pinMode(LED,OUTPUT); 

  bool status;

  bme.begin();

   if (! bme.begin()) {
        while (1);
    }
  Serial.begin(9600);
  myArduinoMEGA.setup(); 
  myArduinoMEGA.addItem("BME280.Temperature",opc_read, opc_float, callbackTemperature);
  myArduinoMEGA.addItem("BME280.Pressure",opc_read, opc_float, callbackPressure);
  myArduinoMEGA.addItem("BME280.Humidity",opc_read, opc_float, callbackHumidity);
  myArduinoMEGA.addItem("BME280.ArduinoOperation",opc_read, opc_float, OPCoperation);



}

void loop() {
  digitalWrite(LED,millis()/1024%2);
  myArduinoMEGA.processOPCCommands();
}
