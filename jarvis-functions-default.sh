##################
# Main Functions #
##################

# How to install sox?
# MacOSX: http://sourceforge.net/projects/sox/files/sox/14.4.2/
# Linux: "sudo apt-get install sox"

PLAY () { # PLAY () {} Play audio file $1
	$play_hw && local play_export="AUDIODEV=$play_hw AUDIODRIVER=alsa" || local play_export=''
	$play_export play -V1 -q $1; 
}
LISTEN () { # LISTEN () {} Listens microhpone and record to audio file $1 when sound is detected until silence
	$verbose && local quiet='' || local quiet='-q'
	$rec_hw && local rec_export="AUDIODEV=$rec_hw AUDIODRIVER=alsa" || local rec_export=''
	$rec_export rec -V1 $quiet -r 16000 -c 1 -b 16 $1 rate 32k silence 1 $min_noise_duration_to_start $min_noise_perc_to_start 1 $min_silence_duration_to_stop $min_silence_level_to_stop trim 0 $max_noise_duration_to_kill
}
STT () { # STT () {} Transcribes audio file $1 and sets corresponding text in $order
	#if $bypass; then # trigger already detected, transcoding command
		json=`wget -q --post-file $1 --header="Content-Type: audio/l16; rate=16000" -O - "http://www.google.com/speech-api/v2/recognize?client=chromium&lang=$language&key=$google_speech_api_key"`
		$verbose && echo JSON: "$json"
		order=`echo $json | perl -lne 'print $1 if m{"transcript":"([^"]*)"}'`
	#else # checking trigger
	#	order=`LD_LIBRARY_PATH=/usr/local/lib PKG_CONFIG_PATH=/usr/local/lib/pkgconfig pocketsphinx_continuous -lm ~/language_model.lm -dict ~/dictionary.dic -logfn $DIR/jarvis-pocketsphinx.log -infile $1`
	#fi
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
