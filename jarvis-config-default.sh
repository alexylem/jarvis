# Instructions
# 1) Update if needed config variables section
# 2) Translate if needed language variables
# 2) Comment and uncomment Main Function section according to your plateform

####################
# Config Variables #
####################

# how YOU want to be called
username=`whoami`

# always listening for vocal input, false to wait for keyboard trigger
always_listening=false

# if always_listening is true, wait magic word to be said wihtin the voice command
# example 1:
#   you: Hey JARVIS?
#		JARVIS: Yes?
#			you: Open the door
#				JARVIS: Done
# example 2:
# 	you: JARVIS Open the door
# 		JARVIS: Done
# example 3:
# 	you: ... Oups I left opened the garage door...
# 		(no reaction, unless set to false => Done)
trigger_mode=true

# if trigger_mode is true, magic word to be said
trigger='JARVIS' # also update at bottom of jarvis-commands file

# welcome message to be said
welcome="Que puis-je faire pour vous?"

# google speech api key http://stackoverflow.com/a/26833337
google_speech_api_key="YOUR_GOOGLE_SPEECH_API_KEY"

# language
language="fr_FR" # en_EN for english

# execute all matching commands (default only first match)
all_matches=false

######################
# Language Variables #
######################
hello=$(if [ $(date +%H) -lt 18 ]; then echo Bonjour; else echo Bonsoir; fi)
bye_helper="Dites 'Au revoir' pour quitter." # must be defined in jarvis-commands
unknown_command="Je n'ai pas compris"

##################
# Main Functions #
##################

# Prototype of main functions: (Do not uncomment)
# LISTEN () {} Listens microhpone and record to audio file $1 when sound if detected until silence
# STT () {} Transcribes audio file $1 and sets corresponding text in $order
# TTS () {} Speaks text $1
# PLAY () {} Play audio file $1

# MacOSX
#http://sourceforge.net/projects/sox/files/sox/14.4.2/
PLAY () { play -q $1; }
LISTEN () { 
	local quiet=''
	$verbose || quiet='-q'
	PLAY beep-high.wav
	rec -V1 $quiet -r 16000 -c 1 $1 rate 32k silence 1 0.1 1% 1 1.0 1%; 
	PLAY beep-low.wav
}
STT () {
	
	json=`wget -q --post-file $1 --header="Content-Type: audio/x-flac; rate=16000" -O - "http://www.google.com/speech-api/v2/recognize?client=chromium&lang=$language&key=$google_speech_api_key"`
	$verbose && echo JSON: "$json"
	order=`echo $json | perl -lne 'print $1 if m{"transcript":"([^"]*)"}'`
}
TTS () { /usr/bin/say -v Thomas $1; } # see available voices with "say -v ?"

# Linux
#LISTEN () { rec $1 rate 32k silence 1 0.1 3% 1 3.0 3%; }
#STT () { echo "Test transcription of $1"; }
#TTS () { mpg321 "http://translate.google.com/translate_tts?tl=fr&client=tw-ob&q=$(rawurlencode '$1')" }
#PLAY () { aplay "$1"; }
