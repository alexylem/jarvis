#!/bin/bash
sudo rfkill unblock all
rfkill list all
# "52:78:23:5D:C2:D9"
BTMac=$1
hciconfig hci0 up

Btstatus=`echo info $BTMac | bluetoothctl| grep "Connected:" | sed 's/\t//g'|  sed 's/://g'`

if [ "x$Btstatus" = "xConnected yes" ];then
	echo "Already Connected"
else
	echo "Try To Reconnect"

	echo scan on | bluetoothctl
	sleep 1
	echo pair $BTMac | bluetoothctl
	sleep 1
	echo trust $BTMac | bluetoothctl
	sleep 1
	echo scan off | bluetoothctl
	sleep 1
	echo connect $BTMac | bluetoothctl
	sleep 2
	Btstatus=`echo info $BTMac | bluetoothctl| grep "Connected:" | sed 's/\t//g'|  sed 's/://g'`
	if [ "x$Btstatus" = "xConnected yes" ];then
		echo "Reconnect Connected Ok"
	else
		echo "failed to reconnect"
	fi
fi
