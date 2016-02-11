# jarvis

Jarvis.sh is a dead simple configurable multi-lang jarvis-like bot

Meant for home automation running on slow computer (ex: Raspberry Pi)

It has almost no dependency and uses Google speech recognition & synthesis

## Install
  
```
git clone https://github.com/alexylem/jarvis.git
cd jarvis/
./jarvis -i
```
  
The install process will guide you in updating the following files:

### `jarvis-config.sh`

- Update settings: JARVIS nickname, always-on, language, your Google Speech API...
- Translate if needed some JARVIS built-in sentences
- Comment & Uncomment (or update) PLAY, LISTEN, STT & TTS wrappers according to your plateform

### `jarvis-commands` 

This is the place to define your own **custom commands**:

```
*TEST*==say "It works!"
*HELLO*==say "Hello $username"
*WHAT TIME*==say "It is `date +%H:%M`"
...
```

What is before `==` is the voice pattern to match, use `*` for any word

What is after `==` is the bash command to execute, you can use the following variables and functions:
  - say "I'm going to speak this out loud"
  - $trigger: JARVIS's nickname as defined in `jarvis-config.sh`  
  - $username: your username as defined in `jarvis-config.sh`

## Usage

To start Jarvis:
```
./jarvis.sh
```

Advanced options:
```
./jarvis.sh -h

  Usage: jarvis.sh -flags
	
	-b	build (do not use)
	-c	edit commands
	-e	edit config
	-h	display this help
	-i	install (init & edit config files)
	-k	read from keyboard instead of microphone
	-q	do not speak answer (just console)
	-r	uninstall (remove config files)
	-u	update (from git & update config files)
	-v	verbose & VU meter - recommended for troubleshooting
```
