# Jarvis [![Version-shield]](CHANGELOG.md) [![License-shield]](LICENSE.md) ![Build-shield]

[![Banner]](http://domotiquefacile.fr/jarvis/)

> Overview & full documentation available on http://domotiquefacile.fr/jarvis/

Jarvis.sh is a lightweight configurable multi-lang voice assistant  
Meant for home automation running on [slow computers](http://domotiquefacile.fr/jarvis/content/prerequisites) (ex: Raspberry Pi)  
Installs automatically [voice recognition](http://domotiquefacile.fr/jarvis/content/stt) & [speech synthesis](http://domotiquefacile.fr/jarvis/content/tts) egines of your choice  
Highly extendable thanks to a wide catalog of [community plugins](http://domotiquefacile.fr/jarvis/plugins)

Languages supported (for voice recognition and speech synthesis):  
:fr: :gb: :us: :es: :it: :de:

### Installation

See [Requirements](http://domotiquefacile.fr/jarvis/content/prerequisites).
```shell
$> git clone https://github.com/alexylem/jarvis.git
$> cd jarvis/
$> ./jarvis.sh -i
```
>More info on the site [installation page](http://domotiquefacile.fr/jarvis/content/installation).

### Usage
```
$> jarvis
```
![App-menu]

### Command-line options
```shell
$> jarvis -h
    Main options are accessible through the application menu

    -b  run in background (no menu, continues after terminal is closed)
    -c  overrides conversation mode setting (true/false)
    -i  install and setup wizard
    -h  display this help
    -j  output in JSON (for APIs)
    -k  directly start in keyboard mode
    -l  directly listen for one command (ex: launch from physical button)
    -m  mute mode (overrides settings)
    -n  directly start jarvis without menu
    -p  install plugin, ex: jarvis -p https://github.com/alexylem/jarvis-time
    -q  quit jarvis if running in background
    -r  uninstall jarvis and its dependencies
    -s  just say something and exit, ex: jarvis -s 'hello world'
    -u  force update Jarvis and plugins (ex: use in cron)
    -v  troubleshooting mode
    -w  no colors in output
    -x  execute order, ex: jarvis -x "switch on lights"
```

### Support

http://domotiquefacile.fr/jarvis/content/support

### License

[![License-shield]](LICENSE.md) Please, refer to [LICENSE.md](https://github.com/alexylem/jarvis/blob/master/LICENSE.md) file.

<!-- Links To Images -->
[Banner]: /imgs/banners/jarvis_banner.png "Simple configurable multi-lang assistant"
[English]: /imgs/flags/us.png "English"
[French]: /imgs/flags/fr.png "French"
[App-menu]: http://domotiquefacile.fr/jarvis/sites/default/files/paste_1476635110.png
<!-- Links To MDs -->
[Changelog File]: CHANGELOG.md
[Contributing File]: CONTRIBUTING.md
[License File]: LICENSE.md
<!-- Badges URLs -->
[Build-shield]: https://img.shields.io/badge/build-passing-green.svg
[Version-shield]: https://img.shields.io/badge/version-17.04.30-blue.svg
[License-shield]: https://img.shields.io/badge/license-MIT-blue.svg
