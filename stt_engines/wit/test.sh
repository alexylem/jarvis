#!/bin/bash
TOKEN="D5MM7DI6M6DMFNYRV6TH3XSZEBNYD4EJ"
audiofile="`pwd`/test.wav"
jarvis -l $audiofile
echo "Transcribing..."
json=`curl -XPOST 'https://api.wit.ai/speech?v=20141022' -s -L -H "Authorization: Bearer $TOKEN" -H "Content-Type: audio/wav" --data-binary "@$audiofile"`
#echo "json=$json"
result="`echo $json | perl -lne 'print $1 if m{"_text" : "([^"]*)"}'`"
echo "result=$result"
