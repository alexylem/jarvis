# build

- [ ] Simulate keystroke to comment & commit

# Installation

- [ ] add to crontab @reboot - propose during install?

# Update

- [X] compare old and update to check if updateconf is needed (using .old?), then remove all .old
- [ ] automatic check of updates at launch + speak it?

# Recognition

- [/] low beep with timeout reached

# Commands 

- [ ] Possibility for discussions with nested commands like:
```
*HOW ARE YOU*==say "fine and you?"
	*GOOD*==say "glad to hear"
	*BAD*==say "oh no..."
```
- [/] add an OR operator
- [ ] remind me to...

# Execution

- [X] check command return code and say if something went wrong

# Planification

- [ ] Add notification features such as mails, alarm, hour, easily configurable
	crontab based? difficult to write but not more difficult than command pattern...
	or DAILY at 9am (human writing into crontab) that keep crontab updated?
	issue is how to use internal functions such as say of username?
	say should be published outside and called via $DIR/say ? which sources jarvis-functions for TTS ?

# Speak
