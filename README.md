# ArdEnvironment Station v1.0 WinCC-OA 3.15

#Sensor: Adafruit BME280

#Arduino: MEGA 2560 + W5500 Ethernet Shield

#Communication: i2c Protocol

SD0 -> SDA1 (brown-white)

SCK -> SCL1 (green-white/ethernet side)

5V -> Green (ethernet side)
GND-> Brown

----------------------------------------------------------------------------------------------------


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

[data]

keepLastTimeSmoothedValue = 1



#OPC DPT Creation

Manual DP creation

_OPCServer -> _ArduinoOPCServer

_OPCGroup  -> _arduino


#Disable Firewall

systemctl disable firewalld

systemctl stop firewalld

(in case of FATAL error-WCCOdata(0) connection expired in Windows WinCC-0A, delete dbase.touch file in both projec(linux+windows) and restarts projects and vm)

#OPC Arduino

1.open Arduino OPC as admin
2.configuration-> Ethernet(10.0.0.10) and Port:80
3.close
4.register as admin
5.open Arduino OPC

(in case of arduino power off or ethernet disconnect unregister and register OPC via OPC Arduino)

