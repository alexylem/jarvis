# how YOU want to be called
username="`whoami`"

# always listening for vocal input, false to wait for keyboard trigger
# if true it will wait magic word to be said before to ask for command
# ex:
#    (waiting for magic word to be said)
#    you: Hey JARVIS?
#        JARVIS: Yes?
#            (discussion mode)
#            you: Open the door
#                JARVIS: Okay
#            you: Thanks
#                JARVIS: You're welcome
#            (> 10secs)
#    (need to say magic word again)
always_listening=true

# if always_listening is true, magic word to be said
trigger='JARVIS' # also update at top of jarvis-commands file

# after first command is executed, wait for another command to be said
# will wait again for trigger if nothing said for 10 secs
conversation_mode=true

# language
language=

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

# choice of STT engine for magic word detection (pocketsphinx|google)
trigger_stt=
# choice of STT engine for command detection (wit|google|pocketsphinx)
command_stt=
# choice of TTS engine (google|espeak|osx_say)
tts_engine=

# google speech api key http://stackoverflow.com/a/26833337
google_speech_api_key=""

# wit.ai speech api key https://wit.ai/apps/new
wit_server_access_token=""

# options for pocketsphinx (not enabled by default)
dictionary="stt_engines/pocketsphinx/jarvis-dictionary.dic"
language_model="stt_engines/pocketsphinx/jarvis-languagemodel.lm"
pocketsphinxlog="/dev/null" # can get very big on long run

# temporary folder (ex: to store cached synthesised speech)
tmp_folder="/tmp"

# JARVIS spoken sentences to be translated
hello=$(if [ $(date +%H) -lt 18 ]; then echo Bonjour; else echo Bonsoir; fi)
unknown_command="Je ne comprends pas"
command_failed="Cette commande a retourné une erreur"
