#include <OPC.h>
#include <Ethernet2.h>
#include <Bridge.h>
#include <SPI.h>
#include <Wire.h>
#include <Adafruit_ADS1015.h>

 Adafruit_ADS1115 ads;  


//    OPC
OPCEthernet aOPCEthernet;
byte mac[] = { 0x90, 0xA2, 0xDA, 0x0E, 0xAD, 0x8D };
IPAddress ip(10,0, 0, 11);
IPAddress subnet(255,255,255,0);
const int listen_port = 80;

const int LED=53;


// create a callback function for the OPCItem

float callbackA0(const char *itemID, const opcOperation opcOP, const float value){
  return ads.readADC_SingleEnded(0);
}

float callbackA1(const char *itemID, const opcOperation opcOP, const float value){
  return ads.readADC_SingleEnded(1);
}

float callbackA2(const char *itemID, const opcOperation opcOP, const float value){
  return ads.readADC_SingleEnded(2);
}

float callbackA3(const char *itemID, const opcOperation opcOP, const float value){
  return ads.readADC_SingleEnded(3);
}



  


void setup() {

  pinMode(LED,OUTPUT); 
  // The ADC input range (or gain) can be changed via the following
  // functions, but be careful never to exceed VDD +0.3V max, or to
  // exceed the upper and lower limits if you adjust the input range!
  // Setting these values incorrectly may destroy your ADC!
  //                                                                ADS1015  ADS1115
  //                                                                -------  -------
  // ads.setGain(GAIN_TWOTHIRDS);  // 2/3x gain +/- 6.144V  1 bit = 3mV      0.1875mV (default)
   ads.setGain(GAIN_ONE);        // 1x gain   +/- 4.096V  1 bit = 2mV      0.125mV
  // ads.setGain(GAIN_TWO);        // 2x gain   +/- 2.048V  1 bit = 1mV      0.0625mV
  // ads.setGain(GAIN_FOUR);       // 4x gain   +/- 1.024V  1 bit = 0.5mV    0.03125mV
  // ads.setGain(GAIN_EIGHT);      // 8x gain   +/- 0.512V  1 bit = 0.25mV   0.015625mV
  // ads.setGain(GAIN_SIXTEEN);    // 16x gain  +/- 0.256V  1 bit = 0.125mV  0.0078125mV
  ads.begin();

   /*
   * OPCNet Object initialization
   */  
  aOPCEthernet.setup(listen_port,mac,ip);
       
  aOPCEthernet.addItem("A0",opc_read, opc_float, callbackA0);
  aOPCEthernet.addItem("A1",opc_read, opc_float, callbackA1);
  aOPCEthernet.addItem("A2",opc_read, opc_float, callbackA2);
  aOPCEthernet.addItem("A3",opc_read, opc_float, callbackA3);
  
}

void loop() 
{
     digitalWrite(LED,millis()/1024%2);
     aOPCEthernet.processOPCCommands();

}
