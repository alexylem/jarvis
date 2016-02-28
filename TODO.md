# Installation

- [ ] add to crontab @reboot - propose during install? Or Service?

# Update

- [X] compare old and update to check if updateconf is needed (using .old?), then remove all .old
- [X] automatic check of updates at launch + speak it?

# Recognition

- [X] low beep with timeout reached

# Commands 

- [ ] Possibility for discussions with nested commands like:
```
*HOW ARE YOU*==say "fine and you?"
	*GOOD*==say "glad to hear"
	*BAD*==say "oh no..."
```
- [X] add an OR operator
- [ ] remind me to...
- [X] check command return code and say if something went wrong

# Voice

- [X] Cache spoken sentences not to call google translate each time

# Notifications

- [/] Add notification features such as mails, alarm, hour, easily configurable
	crontab based? difficult to write but not more difficult than command pattern...
- [ ] Human cron: DAILY at 9am (human writing into crontab) that keep crontab updated?

# Other

- [ ] Automate inclusion of log in bug report & create issue on GitHub
