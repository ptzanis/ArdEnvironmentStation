/*
 * A generic sketch for use with the Arduino OPC or Visual OPC Builder from www.st4makers.com
 */
#include <OPC.h>
#include <Bridge.h>
//#include <Ethernet.h>
#include <SPI.h>

OPCSerial myArduinoMEGA;

opcAccessRights analog_status_input[16];

int readwrite_analog(const char *itemID, const opcOperation opcOP, const int value) 
{
  byte port;
    
  OPCItemType aOPCItem = myArduinoMEGA.getOPCItem(itemID);                     

  port = atoi(&itemID[1]);
           
  if (opcOP == opc_opread) {
    if ((aOPCItem.opcAccessRight == opc_read) || (aOPCItem.opcAccessRight == opc_readwrite)) {
      
      if (analog_status_input[port] != opc_read) {
        pinMode(port, INPUT);
        analog_status_input[port] = opc_read;
      }
    
      return analogRead(port);
    }
  } 
  
}

void setup() {
  Serial.begin(9600);
  
  myArduinoMEGA.setup(); 
    
  myArduinoMEGA.addItem("_",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A0",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A1",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A2",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A3",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A4",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A5",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A5",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A6",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A7",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A8",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A9",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A10",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A11",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A12",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A13",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A14",opc_read, opc_int, readwrite_analog);
  myArduinoMEGA.addItem("A15",opc_read, opc_int, readwrite_analog);
}

void loop() {
  myArduinoMEGA.processOPCCommands();
}
