#!/bin/bash

#.nodes | group_by(.node.Category) | map({"category":.[0].node.Category, "count":length}) | .[] | "\(.category) (\(.count))"

menu_store_browse () { # $1 (optional) sorting, $2 (optionnal) space separated search terms
    
    local plugins=()
    local category=""
    
    if [ -n "$2" ]; then
        # Retrieve list of plugins for these search terms
        while read plugin; do
            plugins+=("$plugin")
        done <<< "$(store_search_plugins "$2")"
        category="Results"
    else
        # Select Category    
        category="`dialog_menu 'Categories' categories[@]`"
        if [ -z "$category" ] || [ "$category" == "false" ]; then
            return
        fi
        
        # Retrieve list of plugins for this Category
        while read plugin; do
            plugins+=("$plugin")
        done <<< "$(store_list_plugins "$category" "$1")"
    fi
    
    while true; do        
        # Select plugin
        local plugin_title="`dialog_menu \"$category\" plugins[@]`"
        
        [ -z "$plugin_title" ] && break
        if [ -z "$plugin_title" ] || [ "$plugin_title" == "false" ]; then
            break
        fi
        
        local plugin_url=$(store_get_field "$plugin_title" 'repo') #https://github.com/alexylem/jarvis
        
        while true; do
            # Display plugin details
            store_display_readme "$plugin_url"
            
            # Plugin menu
            local options=("Info"
                     "Install")
            case "`dialog_menu \"$plugin_title\" options[@]`" in
                Info)    continue;;
                Install) 
                         store_install_plugin "$plugin_url"
                         break 2;;
                *)       break;;
            esac
        done
    done
}

menu_store () {
    store_init
    categories=("All")
    while read line; do
        categories+=("$line")
    done <<< "$(store_get_categories)"
    
    while true; do
        shopt -s nullglob
        nb_installed=(plugins/*/)
        shopt -u nullglob
        
        options=("Installed (${#nb_installed[@]})"
                 "Update installed plugins"
                 "Search"
                 "Browse ($(store_get_nb_plugins))" # total
                 "New Plugins" #TODO X new since last visit
                 "Top Plugins" #TODO top X
                 "Install from URL" #TODO also as jarvis option argument
                 "Publish your Plugin")
        case "`dialog_menu 'Plugins' options[@]`" in
            Installed*) if [ "${#nb_installed[@]}" -gt 0 ]; then
                            cd plugins/
                            while true; do
                                shopt -s nullglob
                                options=(*)
                                shopt -u nullglob
                                local plugin="`dialog_menu 'Installed' options[@]`"
                                if [ -n "$plugin" ] && [ "$plugin" != "false" ]; then
                                    cd "$plugin"
                                    local plugin_git_url="$(git config --get remote.origin.url)"
                                    local plugin_url="${plugin_git_url%.*}"
                                    cd ../
                                    options=("Info"
                                             "Configure"
                                             "Update"
                                             "Rate"
                                             "Report an issue"
                                             "Uninstall")
                                    while true; do
                                        case "`dialog_menu \"$plugin\" options[@]`" in
                                            Info)
                                                store_display_readme "$plugin_url"
                                                ;;
                                            Configure)
                                                editor "$plugin/config.sh"
                                                ;;
                                            Update)
                                                echo "Checking for updates..."
                                                cd "$plugin"
                                                git pull &
                                               jv_spinner $!
                                               jv_press_enter_to_continue
                                                cd ../
                                                ;;
                                            Rate)
                                                dialog_msg "$(store_get_field_by_repo "$plugin_url" "url")#comment-form"
                                                ;;
                                            Report*)
                                                dialog_msg "$plugin_url/issues/new"
                                                ;;
                                            Uninstall)
                                                if dialog_yesno "Are you sure?" true >/dev/null; then
                                                    $plugin/uninstall.sh
                                                    rm -rf "$plugin"
                                                    dialog_msg "Uninstallation Complete"
                                                    break 2
                                                fi
                                                ;;
                                            *)  break;;
                                        esac
                                    done
                                else
                                    break
                                fi
                            done
                            cd ../
                        fi
                        ;;
            Update*)    jv_plugins_check_updates;;
            Search*)    local search_terms="$(dialog_input "Search in Plugins (keywords seperate with space)" "$search_terms")"
                        menu_store_browse "" "$search_terms"
                        ;;
            Browse*)    menu_store_browse;;
            New*)       menu_store_browse "date";;
            Top*)       menu_store_browse "rating";;
            Install*)   local plugin_url="$(dialog_input "Repo URL, ex: https://github.com/alexylem/time")"
                        [ -z "$plugin_url" ] && continue
                        store_install_plugin "$plugin_url"
                        ;;
            Publish*)   dialog_msg <<EOM
Why keeping your great Jarvis commands just for you?
Share them and have the whole community using them!
It's easy, and a great way to make one's contribution to the project.
Procedure to publish your commands on the Jarvis Store:
http://domotiquefacile.fr/jarvis/content/publish-your-plugin
EOM
                        ;;
            *) break;;
        esac
    done
}

while [ "$no_menu" = false ]; do
    options=('Start Jarvis'
             'Settings'
             'Commands (what JARVIS can understand and execute)'
             'Events (what JARVIS monitors and notifies you about)'
             'Plugins (commands from community)'
             'Search for updates'
             'Help / Report a problem'
             'About')
    case "`dialog_menu \" Jarvis - v$jv_version\n$headline\" options[@]`" in
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
                                     "Snowboy token ($snowboy_token)"
                                     "Snowboy train a hotword/command"
                                     "Bing key ($bing_speech_api_key)"
                                     #"Google key ($google_speech_api_key)"
                                     "Wit key ($wit_server_access_token)"
                                     "PocketSphinx dictionary ($dictionary)"
                                     "PocketSphinx language model ($language_model)"
                                     "PocketSphinx logs ($pocketsphinxlog)")
                            case "`dialog_menu 'Configuration > Voice recognition' options[@]`" in
                                Recognition*magic*word*) configure "trigger_stt";;
                                Recognition*command*)       configure "command_stt";;
                                Snowboy*sensitivity*)       configure "snowboy_sensitivity";;
                                Snowboy*token*)             configure "snowboy_token";;
                                Snowboy*train*)             stt_sb_train "$(dialog_input "Hotword / Quick Command to (re-)train" "$trigger")" true;;
                                #Google*)                   configure "google_speech_api_key";;
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
            #update_commands
            ;;
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
        Plugins*)
            menu_store
            ;;
        Help*)
            dialog_msg <<EOM
A question?
http://domotiquefacile.fr/jarvis/content/support

A problem or enhancement request?
Create a ticket on GitHub
https://github.com/alexylem/jarvis/issues/new

Just want to discuss?
http://domotiquefacile.fr/jarvis/content/disqus
EOM
            ;;
        "About") dialog_msg <<EOM
JARVIS
By Alexandre Mély

http://domotiquefacile.fr/jarvis
alexandre.mely@gmail.com
(I don't give support via email, please check Help)

JARVIS is freely distributable under the terms of the MIT license.
EOM
            ;;
        "Search for updates")
            checkupdates
            jv_plugins_check_updates
            ;;
        *) exit;;
    esac
done
