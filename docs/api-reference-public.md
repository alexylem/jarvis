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


`jv_sanitize()`
---------------

Public: Rremoves accents, lowercase, strip special chars and optionally replace spaces with underscores
* $1 - (required) string to sanitize
* $2 - (optional) character to replace spaces with

Echoes the sanitized string

    $> jv_sanitize "Caractères Spéciaux?"
    caracteres speciaux


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


