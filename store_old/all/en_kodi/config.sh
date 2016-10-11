#!/bin/bash
kodiIpEn=XXX.XXX.X.XX
kodiPortEn=XXXX

callUrlKodiEn (){
   curl -s -H "Content-Type: application/json" -X POST -d ${1} http://$kodiIpEn:$kodiPortEn/jsonrpc > /dev/null
}
