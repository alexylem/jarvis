# how YOU want to be called
username="`whoami`"

# always listening for vocal input, false to wait for keyboard trigger
always_listening=true

# wait magic word to be said before to ask for command
# need always_listening to be true
# ex:
#	(waiting for magic word to be said)
#	you: Hey JARVIS?
#		JARVIS: Yes?
#			(discussion mode)
#			you: Open the door
#				JARVIS: Okay
#			you: Thanks
#				JARVIS: You're welcome
#			(> 10secs)
#	(need to say magic word again)
trigger_mode=true

# if trigger_mode is true, magic word to be said
trigger='JARVIS' # also update at top of jarvis-commands file

# welcome message to be said
welcome="Que puis-je faire pour vous?"

# google speech api key http://stackoverflow.com/a/26833337
google_speech_api_key="YOUR_GOOGLE_SPEECH_API_KEY"

# language
language="fr_FR" # en_EN for english

# execute all matching commands (default only first match)
all_matches=false

# check updates on startup (needs git)
check_updates=true

# hw:X,X of speakers, false for default
play_hw=false
# hw:X,X of microhpone, false for default
rec_hw=false

# sox auto-recording tresholds
min_noise_duration_to_start="0.1" # default 0.1
min_noise_perc_to_start="1%" # default 1%
min_silence_duration_to_stop="0.5" # default 0.5
min_silence_level_to_stop="1%" # default 1%
max_noise_duration_to_kill="10" # default 10

# choice of STT engine for magic word detection (google|pocketsphinx)
trigger_stt=google
# choice of STT engine for command detection (google|pocketsphinx)
command_stt=google

# options for pocketsphinx (not enabled by default)
dictionary="pocketsphinx-dictionary.dic"
language_model="pocketsphinx-languagemodel.lm"
pocketsphinxlog="/dev/null" # can get very big on long run

# JARVIS spoken sentences to be translated
hello=$(if [ $(date +%H) -lt 18 ]; then echo Bonjour; else echo Bonsoir; fi)
unknown_command="Je n'ai pas compris"
command_failed="Cette commande a retourné une erreur"
