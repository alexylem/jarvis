#!/bin/bash
jarvis_store_browse () { # $1 (optional) space separated search terms
    local search_expr="*"
    [ -n "$1" ] && search_expr="*${1// /*}*"
    cd store/all/
    while true; do
        shopt -s nullglob # http://stackoverflow.com/questions/18884992/how-do-i-assign-ls-to-an-array-in-linux-bash
        options=($search_expr)
        shopt -u nullglob
        option="`dialog_menu 'Store' options[@]`"
        if [ -n "$option" ] && [ "$option" != "false" ]; then
            clear
            more "$option/info.md"
            my_debug "Press [Enter] to continue"
            read
            options=("Info"
                     "Install")
            while true; do
                case "`dialog_menu \"$option\" options[@]`" in
                    Info)    clear
                             more "$option/info.md"
                             my_debug "Press [Enter] to continue"
                             read
                             ;;
                    Install) cp -R "$option" ../installed
                             cd ../installed
                             $option/install.sh
                             if [[ -s "$option/config.sh" ]]; then
                                 dialog_msg "This plugin needs variables to be set"
                                 editor "$option/config.sh"
                             fi
                             dialog_msg "Installation Complete"
                             break 2;;
                    *)       break;;
                esac
            done
        else
            break
        fi
    done
    cd ../../
}

while [ "$no_menu" = false ]; do
    options=('Start Jarvis'
             'Settings'
             'Commands (what JARVIS can understand and execute)'
             'Events (what JARVIS monitors and notifies you about)'
             'Store (commands from community)'
             'Search for updates'
             'Help / Report a problem'
             'About')
    case "`dialog_menu \"Welcome to Jarvis\n$headline\" options[@]`" in
        Start*)
            while true; do
                options=('Start normally' 'Troubleshooting mode' 'Keyboard mode' 'Mute mode' 'Start as a service')
                case "`dialog_menu 'Start Jarvis' options[@]`" in
                    "Start normally")
                        break 2;;
                    "Troubleshooting mode")
                        verbose=true
                        break 2;;
                    "Keyboard mode")
                        keyboard=true
                        break 2;;
                    "Mute mode")
                        quiet=true
                        break 2;;
                    "Start as a service")
                        start_in_background
                        exit;;
                    *) break;;
                esac
            done;;
        Settings)
            while true; do
                options=('General' 'Phrases' 'Hooks' 'Audio' 'Voice recognition' 'Speech synthesis' 'Step-by-step wizard')
                case "`dialog_menu 'Configuration' options[@]`" in
                    "General")
                        while true; do
                            options=("Username ($username)" "Trigger ($trigger_mode)" "Magic word ($trigger)" "Multi-command separator ($separator)" "Conversation mode ($conversation_mode)" "Language ($language)" "Check Updates on Startup ($check_updates)")
                            case "`dialog_menu 'Configuration > General' options[@]`" in
                                Username*) configure "username";;
                                Trigger*) configure "trigger_mode";;
                                Magic*word*) configure "trigger";;
                                Multi-command*separator*) configure "separator";;
                                Conversation*) configure "conversation_mode";;
                                Language*) configure "language";;
                                Check*Updates*) configure "check_updates";;
                                *) break;;
                            esac
                        done;;
                    "Phrases")
                        while true; do
                            options=("Startup greetings ($phrase_welcome)" "Trigger reply ($phrase_triggered)" "Unknown order ($phrase_misunderstood)" "Command failed ($phrase_failed)")
                            case "`dialog_menu 'Configuration > Phrases' options[@]`" in
                                Startup*greetings*) configure "phrase_welcome";;
                                Trigger*reply*)     configure "phrase_triggered";;
                                Unknown*order*)     configure "phrase_misunderstood";;
                                Command*failed*)    configure "phrase_failed";;
                                *) break;;
                            esac
                        done;;
                    "Hooks")
                    while true; do
                        options=("Program startup" "Program exit" "Entering command mode" "Exiting command mode")
                        case "`dialog_menu 'Configuration > Hooks' options[@]`" in
                            Program*startup*) configure "program_startup";;
                            Program*exit*) configure "program_exit";;
                            Entering*) configure "entering_cmd";;
                            Exiting*) configure "exiting_cmd";;
                            *) break;;
                        esac
                    done;;
                    "Audio")
                        while true; do
                            options=("Speaker ($play_hw)" "Mic ($rec_hw)" "Volume" "Sensitivity" "Min noise duration to start ($min_noise_duration_to_start)" "Min noise perc to start ($min_noise_perc_to_start)" "Min silence duration to stop ($min_silence_duration_to_stop)" "Min silence level to stop ($min_silence_level_to_stop)" "Max noise duration to kill ($max_noise_duration_to_kill)")
                            case "`dialog_menu 'Configuration > Audio' options[@]`" in
                                Speaker*) configure "play_hw";;
                                Mic*) configure "rec_hw";;
                                Volume) if [ "$platform" == "osx" ]; then
                                            osascript <<EOM
                                                tell application "System Preferences"
                                                    activate
                                                    set current pane to pane "com.apple.preference.sound"
                                                    reveal (first anchor of current pane whose name is "output")
                                                end tell
EOM
                                        else
                                            alsamixer -c ${play_hw:3:1} -V playback || read -p "ERROR: check above"
                                        fi;;
                                Sensitivity)
                                if [ "$platform" == "osx" ]; then
                                            osascript <<EOM
                                                tell application "System Preferences"
                                                    activate
                                                    set current pane to pane "com.apple.preference.sound"
                                                    reveal (first anchor of current pane whose name is "input")
                                                end tell
EOM
                                        else
                                            alsamixer -c ${rec_hw:3:1} -V capture || read -p "ERROR: check above"
                                        fi;;
                                *duration*start*) configure "min_noise_duration_to_start";;
                                *perc*start*) configure "min_noise_perc_to_start";;
                                *duration*stop*) configure "min_silence_duration_to_stop";;
                                *level*stop*) configure "min_silence_level_to_stop";;
                                *duration*kill*) configure "max_noise_duration_to_kill";;
                                *) break;;
                            esac
                        done;;
                    "Voice recognition")
                        while true; do
                            options=("Recognition of magic word ($trigger_stt)"
                                     "Recognition of commands ($command_stt)"
                                     "Snowboy sensitivity ($snowboy_sensitivity)"
                                     "Bing key ($bing_speech_api_key)"
                                     #"Google key ($google_speech_api_key)"
                                     "Wit key ($wit_server_access_token)"
                                     "PocketSphinx dictionary ($dictionary)"
                                     "PocketSphinx language model ($language_model)"
                                     "PocketSphinx logs ($pocketsphinxlog)")
                            case "`dialog_menu 'Configuration > Voice recognition' options[@]`" in
                                Recognition*magic*word*) configure "trigger_stt";;
                                Recognition*command*)       configure "command_stt";;
                                Snowboy*)                   configure "snowboy_sensitivity";;
                                #Google*)                    configure "google_speech_api_key";;
                                Wit*)                       configure "wit_server_access_token";;
                                Bing*key*)                  configure "bing_speech_api_key";;
                                PocketSphinx*dictionary*)   configure "dictionary";;
                                PocketSphinx*model*)        configure "language_model";;
                                PocketSphinx*logs*)         configure "pocketsphinxlog";;
                                *) break;;
                            esac
                        done;;
                    "Speech synthesis")
                        while true; do
                            options=("Speech engine ($tts_engine)" "OSX voice ($osx_say_voice)" "Cache folder ($tmp_folder)")
                            case "`dialog_menu 'Configuration > Speech synthesis' options[@]`" in
                                Speech*engine*) configure "tts_engine";;
                                OSX*voice*)     configure "osx_say_voice";;
                                Cache*folder*)  configure "tmp_folder";;
                                *) break;;
                            esac
                        done;;
                    "Step-by-step wizard")
                        wizard;;
                    *) break;;
                esac
            done
            configure "save";;
        Commands*)
            editor jarvis-commands
            update_commands;;
        Events*)
            dialog_msg <<EOM
WARNING: JARVIS currently uses Crontab to schedule monitoring & notifications
This will erase crontab entries you may already have, check with:
	crontab -l
If you already have crontab rules defined, add them to JARVIS events:
	crontab -l >> jarvis-events
Press [Ok] to start editing Event Rules
EOM
            editor jarvis-events &&
            crontab jarvis-events -i;;
        Store*)
            while true; do
                shopt -s nullglob
                nb_installed=(store/installed/*/)
                nb_all=(store/all/*/)
                shopt -u nullglob
                options=("Installed (${#nb_installed[@]})"
                         "Search"
                         "Browse (${#nb_all[@]})"
                         "Publish")
                case "`dialog_menu 'Store' options[@]`" in
                    Installed*) if [ "${#nb_installed[@]}" -gt 0 ]; then
                                    cd store/installed/
                                    while true; do
                                        shopt -s nullglob
                                        options=(*)
                                        shopt -u nullglob
                                        option="`dialog_menu 'Installed' options[@]`"
                                        if [ -n "$option" ] && [ "$option" != "false" ]; then
                                            options=("Info"
                                                     "Configure"
                                                     "Uninstall")
                                            while true; do
                                                case "`dialog_menu \"$option\" options[@]`" in
                                                    Info)      clear
                                                               more "$option/info.md"
                                                               my_debug "Press [Enter] to continue"
                                                               read
                                                               ;;
                                                    Configure) editor "$option/config.sh";;
                                                    Uninstall)
                                                            if dialog_yesno "Are you sure?" true >/dev/null; then
                                                                "$option"/uninstall.sh
                                                                rm -rf "$option"
                                                                dialog_msg "Uninstallation Complete"
                                                                break 2
                                                            fi
                                                            ;;
                                                    *)       break;;
                                                esac
                                            done
                                        else
                                            break
                                        fi
                                    done
                                    cd ../../
                                fi
                                ;;
                    Search*)    search_terms=`dialog_input "Search in Store (seperate keywords with space)" "$search_terms"`
                                jarvis_store_browse "$search_terms"
                                ;;
                    Browse*)    jarvis_store_browse
                                ;;
                    Publish*)   dialog_msg <<EOM
Why keeping your great Jarvis commands just for you?
Share them and have the whole community using them!
It's easy, and a great way to make one's contribution to the project.
Procedure to publish your commands on the Jarvis Store:
https://github.com/alexylem/jarvis/wiki/store
EOM
                                ;;
                    *) break;;
                esac
            done;;
        Help*)
            dialog_msg <<EOM
A question?
https://github.com/alexylem/jarvis/wiki/support

A problem or enhancement request?
Create a ticket on GitHub
https://github.com/alexylem/jarvis/issues/new

Just want to discuss?
https://disqus.com/home/discussion/coinche/jarvis/
EOM
            ;;
        "About") dialog_msg <<EOM
JARVIS
By Alexandre Mély

https://github.com/alexylem/jarvis/wiki
alexandre.mely@gmail.com
(I don't give support via email, please check Help)

JARVIS is freely distributable under the terms of the MIT license.
EOM
            ;;
        "Search for updates")
            checkupdates;;
        *) exit;;
    esac
done
