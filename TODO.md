# Installation

- [/] add to crontab @reboot - propose during install?
- [X] automatic install of pocketsphinx

# Update

- [X] automatic check of updates at launch + speak it?

# Recognition

- [ ] use lmgen to generate language_model based on command words & trigger (english only)

# Commands 

- [ ] Possibility for discussions with nested commands like:
```
*HOW ARE YOU*==say "fine and you?"
	*GOOD*==say "glad to hear"
	*BAD*==say "oh no..."
```
- [X] add an OR operator
- [X] variable Recognition
```
*REPEAT (*) AND (*)==say "(1) (2)"
```

# Voice

- [X] Cache spoken sentences not to call google translate each time

# Notifications

- [/] Add notification features such as mails, alarm, hour, easily configurable
	crontab based? difficult to write but not more difficult than command pattern...
- [ ] Human cron: DAILY at 9am (human writing into crontab) that keep crontab updated?
- [ ] Wait for silence to speak
- [ ] Detect noise after long silence to say hello again + news (once silence)

# Other

- [ ] Automate inclusion of log in bug report & create issue on GitHub
- [X] Execution in background
- [ ] -t Troubleshooting guide and step-by-step diagnosis
- [ ] Errors found in jarvis.log
    ./jarvis.sh: line 358: [: : integer expression expected
    ?./jarvis.sh: line 355: [: : integer expression expected
