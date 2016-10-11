#!/bin/bash
kodiIpFr=XXX.XXX.X.X
kodiPortFr=XXXX

callUrlKodiFr (){
   curl -s -H "Content-Type: application/json" -X POST -d ${1} http://$kodiIpFr:$kodiPortFr/jsonrpc > /dev/null
}
