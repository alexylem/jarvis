`jv_version`
------------

Public: version of Jarvis


`username`
----------

Public: the name of the user


`trigger`
---------

Public: the name of Jarvis (the hotword)


`order`
-------

Public: the transcribed voice order


`language`
----------

Public: the user's language in Jarvis settings

Ex: `en_GB` Use `${language:0:2}` to only get `en`


`jv_repeat_last_command()`
--------------------------

Public: Re-run last executed command. Use to create an order to repeat.

Usage:

    AGAIN*==jv_repeat_last_command


`jv_print_json()`
-----------------

Internal: Print JSON key value pair
* $1 - key
* $2 - value


`jv_display_commands()`
-----------------------

Public: display available commands grouped by plugin name


`jv_add_timestamps()`
---------------------

Internal: add timestamps to log file

Usage

    script.sh | jv_add_timestamps >> file.log


`say()`
-------

Public: Speak some text out loud
* $1 - text to speak

Returns nothing

    $> say "hello world"
    Jarvis: hello world


`jv_curl()`
-----------

Public: Call HTTP requests

It displays errors if request fails When ran in troubleshooting mode, it will display request & response
* $@ - all arguments you would give to curl

Returns the return code of curl

    $> *COMMAND*==jv_curl "http://192.168.1.1/action" && say "Done"


`jv_spinner()`
--------------

Public: Displays a spinner for long running commmands

Returns nothing

    command &; jv_spinner $!
    |/-\|\-\... (spinning bar)


`jv_read_dom()`
---------------

Public: XML Parser

Usage:

    while jv_read_dom; do
      [[ $ENTITY = "tagname" ]] && echo $CONTENT
    done < file.xml


`update_alsa()`
---------------

Internal: Updates alsa user config at ~/.asoundrc
* $1 - play_hw
* $2 - rec_hw


`jv_sanitize()`
---------------

Public: Rremoves accents, lowercase, strip special chars and optionally replace spaces with underscores
* $1 - (required) string to sanitize
* $2 - (optional) character to replace spaces with

Echoes the sanitized string

    $> jv_sanitize "Caractères Spéciaux?"
    caracteres speciaux


`jv_message()`
--------------

Internal: Display a message in color
* $1 - message to display
* $2 - message type (error/warning/success/debug)
* $3 - color to use


`jv_error()`
------------

Public: Displays a error in red
* $1 - message to display


`jv_warning()`
--------------

Public: Displays a warning in yellow
* $1 - message to display


`jv_success()`
--------------

Public: Displays a success in green
* $1 - message to display


`jv_debug()`
------------

Public: Displays a log in gray
* $1 - message to display


`jv_press_enter_to_continue()`
------------------------------

Public: Asks user to press enter to continue

Returns nothing

    $> jv_press_enter_to_continue
    Press [Enter] to continue


`jv_exit()`
-----------

Public: Exit properly jarvis
* $1 - Return code

Returns nothing


`jv_check_updates()`
--------------------

Internal: check updates and pull changes from github
* $1 - path of git folder to check, default current dir
* $2 - don't ask confirmation, default false


`jv_jarvis_updated`
-------------------

inform jarvis is updated to ask for restart


`jv_config_changed`
-------------------

save user configuration if config.sh file changed on repo (only for plugins)


`jv_plugins_check_updates()`
----------------------------

Internal: runs jv_check_updates for all plugins
* $1 - don't ask confirmation, default false


`jv_plugins_order_rebuild()`
----------------------------

Internal: Rebuild plugins_order.txt following added/removed plugins


`jv_ga_send_hit()`
------------------

Internal: send hit to Google Analytics on /jarvis.sh This is to anonymously evaluate the global usage of Jarvis app by users

Run asynchrously to avoid slowdown

    $> ( jv_ga_send_hit & )


`jv_build()`
------------

Internal: Build Jarvis

Returns nothing


`jv_update_config()`
--------------------

Internal: apply needed local config modifications following updates of Jarvis


