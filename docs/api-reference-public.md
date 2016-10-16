`say()`
-------

Public: Speak some text out loud

* $1 - text to speak

    $> say "hello world"
    OR
    $> echo hello world | say
    Jarvis: hello world


`jv_spinner()`
--------------

Public: Displays a spinner for long running commmands

    command &; jv_spinner $!
    |/-\|\-\... (spinning bar)


`jv_sanitize()`
---------------

Public: Rremoves accents, lowercase, strip special chars and optionally replace spaces with underscores

* $1 - (required) string to sanitize
* $2 - (optional) character to replace spaces with

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

    $> jv_press_enter_to_continue
    Press [Enter] to continue


`jv_exit()`
-----------

Public: Exit properly jarvis

* $1 - Return code


