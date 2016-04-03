#!/bin/bash
wit_STT () { # STT () {} Transcribes audio file $1 and writes corresponding text in $forder
json=`curl -XPOST 'https://api.wit.ai/speech?v=20141022' -s -L -H "Authorization: Bearer $wit_server_access_token" -H "Content-Type: audio/wav" --data-binary "@$audiofile"`
$verbose && printf "DEBUG: $json\n"
echo $json | perl -lne 'print $1 if m{"_text" : "([^"]*)"}' > $forder
}
