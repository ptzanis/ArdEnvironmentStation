#include <OPC.h>
#include <Ethernet2.h>
#include <Bridge.h>
#include <SPI.h>
#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME280.h>

/*
 OPC
 */
OPCEthernet aOPCEthernet;
byte mac[] = { 0x90, 0xA2, 0xDA, 0x0E, 0xAD, 0x8D };
IPAddress ip(10,0, 0, 10);
IPAddress subnet(255,255,255,0);
const int listen_port = 80;

/*
BME280
*/

//#define BME_SCK 5
//#define BME_MISO 4
//#define BME_MOSI 3
//#define BME_CS 2

#define SEALEVELPRESSURE_HPA (1013.25)


Adafruit_BME280 bme; //I2C
//Adafruit_BME280 bme(BME_CS, BME_MOSI, BME_MISO, BME_SCK); // software SPI
/*
 * create a callback function for the OPCItem
 */
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

  /*
   * OPCNet Object initialization
   */  
  aOPCEthernet.setup(listen_port,mac,ip);
       
  aOPCEthernet.addItem("BME280.Temperature",opc_read, opc_float, callbackTemperature);
  aOPCEthernet.addItem("BME280.Pressure",opc_read, opc_float, callbackPressure);
  aOPCEthernet.addItem("BME280.Humidity",opc_read, opc_float, callbackHumidity);
  aOPCEthernet.addItem("BME280.ArduinoOperation",opc_read, opc_float, OPCoperation);



}

void loop() {

  digitalWrite(LED,millis()/1024%2);
   aOPCEthernet.processOPCCommands();

  printValues();
}

void printValues() {   
    Serial.print("Temperature = ");
    Serial.print(bme.readTemperature());
    Serial.println(" *C");

    Serial.print("Pressure = ");

    Serial.print(bme.readPressure() / 100.0F);
    Serial.println(" hPa");

    Serial.print("Approx. Altitude = ");
    Serial.print(bme.readAltitude(SEALEVELPRESSURE_HPA));
    Serial.println(" m");

    Serial.print("Humidity = ");
    Serial.print(bme.readHumidity());
    Serial.println(" %");

    Serial.println();
}




