# how YOU want to be called
username=`whoami`

# always listening for vocal input, false to wait for keyboard trigger
always_listening=true

# wait magic word to be said before to ask for command
# need always_listening to be true
# ex:
#   you: Hey JARVIS?
#		JARVIS: Yes?
#			you: Open the door
#				JARVIS: Okay
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

# JARVIS sentences to be translated
hello=$(if [ $(date +%H) -lt 18 ]; then echo Bonjour; else echo Bonsoir; fi)
bye_helper="Dites 'Au revoir' pour quitter." # must be defined in jarvis-commands
unknown_command="Je n'ai pas compris"
command_failed="Cette commande a retourné une erreur"
