`say()`
-------

Public: Speak some text out loud

* $1 - text to speak

    say "hello world"
    echo hello world | say


`jv_spinner()`
--------------

Public: Displays a spinner for long running commmands

    command &; jv_spinner $!


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


`my_error()`
------------

Public: Displays a error in red
* $1 - message to display


`my_warning()`
--------------

Public: Displays a warning in yellow
* $1 - message to display


`my_success()`
--------------

Public: Displays a success in green
* $1 - message to display


`my_debug()`
------------

Public: Displays a log in gray
* $1 - message to display


`press_enter_to_continue()`
---------------------------

Public: Asks user to press enter to continue


`program_exit()`
----------------

Public: Exit properly jarvis

* $1 - Return code


`jv_build()`
------------

Internal: Build Jarvis


