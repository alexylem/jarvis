`jv_version`
------------

Public: version of Jarvis


`jv_dir`
--------

Public: directory where Jarvis is installed


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


`platform`
----------

Public: user's platform (linux, osx)


`jv_arch`
---------

Public: user's architecture (armv7l, x86_64)


`jv_os_name`
------------

Public: user's OS name (raspbian, ubuntu, Mac OS X...)


`jv_os_version`
---------------

Public: user's OS version (8, 16.02, ...)


`jv_api`
--------

Public: indicates if called using API else normal usage


`jv_repeat_last_command()`
--------------------------

Public: Re-run last executed command. Use to create an order to repeat.

Usage:

    AGAIN*==jv_repeat_last_command


`jv_display_commands()`
-----------------------

Public: display available commands grouped by plugin name


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

Returns return code of background task

    command &; jv_spinner $!
    |/-\|\-\... (spinning bar)


`jv_read_dom()`
---------------

Public: XML Parser

Usage:

    while jv_read_dom; do
      [[ $ENTITY = "tagname" ]] && echo $CONTENT
    done < file.xml


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


`jv_info()`
-----------

Public: Displays an information in blue
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


`jv_yesno()`
------------

Public: YesNo prompt from the command line

* $1 - Question to be answered

Usage

    if jv_yesno "question?"; then...


`jv_progressbar()`
------------------

Public: display a progress bar in the terminal
* $1 - current step number
* $2 - total number of steps Usage    (usually in a loop)
    jv_progressbar $current_step $total_steps
 Output    Progress : [########################################] 100%
 Used in    jarvis-face


`jv_update()`
-------------

Public: update package/formula list


`jv_is_installed()`
-------------------

Public: indicates if a package is installed
* $1 - package to verify


`jv_install()`
--------------

Public: install packages, used for dependencies

args: list of packages to install


`jv_remove()`
-------------

Public: remove packages, used for uninstalls

args: list of packages to remove


`jv_browse_url()`
-----------------

Public: open URL in default browser


