# ArdEnvironment Station v1.0 WinCC-OA

#Sensor: Adafruit BME280

#Arduino: MEGA 2560 + W5500 Ethernet Shield

#Communication: i2c Protocol

SD0 -> SDA
SCK -> SCL

 #Static IPs:
 * Arduino : 10.0.0.10
 * FieldPoint: 10.0.0.5
 * Linux: 10.0.0.4
 * Windows 10.0.0.1
 * 
 (Subnet: 255.255.255.0)

#Config File (Windows Project)

OPC DA Client -> -num 10 -event 10.0.0.4 -data 10.0.0.4
[opc_10]
server="ArduinoOPCServer""ArduinoOPCServer.2"



#OPC DPT Creation

Manual DP creation
_OPCServer -> _ArduinoOPCServer
_OPCGroup  -> _arduino


#Disable Firewall

systemctl disable firewalld
systemctl stop firewalld


