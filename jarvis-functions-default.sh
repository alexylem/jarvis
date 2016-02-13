##################
# Main Functions #
##################

# How to install sox?
# MacOSX: http://sourceforge.net/projects/sox/files/sox/14.4.2/
# Linux: "sudo apt-get install sox"

PLAY () { # PLAY () {} Play audio file $1
	play -V1 -q $1; 
}
LISTEN () { # LISTEN () {} Listens microhpone and record to audio file $1 when sound if detected until silence
	local quiet=''
	$verbose || quiet='-q'
	rec -V1 $quiet -r 16000 -c 1 $1 rate 32k silence 1 0.1 1% 1 1.0 1% trim 0 10
}
STT () { # STT () {} Transcribes audio file $1 and sets corresponding text in $order
	json=`wget -q --post-file $1 --header="Content-Type: audio/x-flac; rate=16000" -O - "http://www.google.com/speech-api/v2/recognize?client=chromium&lang=$language&key=$google_speech_api_key"`
	$verbose && echo JSON: "$json"
	order=`echo $json | perl -lne 'print $1 if m{"transcript":"([^"]*)"}'`
}
TTS () { # TTS () {} Speaks text $1
	if [[ "$platform" == "osx" ]]; then
		# MaxOSX: using built'in say function
		voice=`/usr/bin/say -v ? | grep $language | awk '{print $1}'`
		/usr/bin/say -v $voice $1;
	else
		# Linux: using google translate speech synthesis
		encoded=`rawurlencode "$1"`
		mpg123 -q "http://translate.google.com/translate_tts?tl=fr&client=tw-ob&q=$encoded"
	fi
}
