#!/bin/bash
if [ "$1" = "stop" ]; then
	killall 
else
	mpg123 http://streaming.radio.rtl.fr:80/rtl-1-44-96
fi
