# Tmux Resurrect NG
Automated save and restore of `tmux` session window and pane geometry (layout and placement) along with save and restore of pane shell command line history buffers and command line history (for `bash`).

>**tmux-resurrect-ng** is only compatible with the BASH shell. If your default shell is not `bash` (e.g. zsh, ksh, csh) then this plugin is not for you; you should consider the original [pic](https://github.com/tmux-plugins/tmux-resurrect) project instead.

Okay, so that's not exactly true. As of v0.9.0, **tmux-resurrect-ng** still supports manual trigger of save and restore. But that functionality will likely be removed before v1.0.0 is reached.

##Features

Auto save and restore:

* all session window geometry (windows, panes) and order
* current working directory for each pane
* shell command line history for each pane (`bash` only)
* buffer for each pane (`bash` only)
* active and alternative session
* active and alternative window for each session
* windows with focus
* active pane for each window
* programs running within a pane (See: configuration section)
* resurrect state indicator in tmux status bar
* migration script to help you move from tmux-resurrect to tmux-resurrect-ng
* [optional]: restoring vim/neovim sessions

Auto purge (cleanup):

* old state (layout), pane history and buffer files

Easy migration from [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) to **tmux-resurrect-ng**:

* migration utility script included (See: [Migration](##Migration))

## Why?
**tmux-resurrect-ng** is a fork of the super awesome [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) project by Bruno Sutic. Where the original project has a goal aligned with saving and restoring session window geometry when prompted by the user, **tmux-resurrect-ng** natively implements fully automated save and restore, including automated purging of old files. Preserving geometry is awesome but what about saving shell history and pane buffers? This plugin handles both of those requirements!

Where [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) has been extended to also save `bash` command line history, **tmux-resurrect-ng** accomplishes this task less intrusively by integrating with the `bash` command prompt to run certain tasks as a function in the background as you work. The benefit of this implementation is that an intrusive `history` write command is never output to your terminal session. While that side effect is possibly nothing more than an annoyance in [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect), it's actually problematic for **tmux-resurrect-ng** because this plugin actually preserves the pane buffers as well! I don't know about you but I scroll back through my terminal windows just as often as I refer back to my command line history so pane buffers are important to me and the last thing I want to see is stuff that I didn't type.


#### Pane buffers vs command line history
What's the difference between the pane buffer and the command line history? Lots! The command line history is simply a log of all previous commands you've typed in. To access the command line history you need to either run the `history` command or incrementally scroll through the history (usually, using the up and down arrows on your keyboard). The pane buffer is the *visual* content of the terminal window. **tmux-resurrect-ng** preserves all ansi color codes when saving pane buffers.


## Installation
The **tmux-resurrect-ng** plugin is only supported as a manual installation at the moment (it is not currently part of the [tmux-plugins](https://github.com/tmux-plugins) project). Manual installation requires the following steps:

* Clone the **tmux-resurrect-ng** repo
* Set permissions
* Update your `.tmux.conf` file to enable status bar integration
* Update your `.bash_profile` file to enable prompt integration
* Exit tmux and kill the server
* Launch a new named session


#### Clone the repo
The appropriate place to install tmux plugins is within your `.tmux` directory under plugins:

```sh
>mkdir -p $HOME/.tmux/plugins
>git clone https://github.com/markeissler/tmux-resurrect-ng.git $HOME/.tmux/plugins/tmux-resurrect-ng
```

#### Set permissions
Permissions should already be setup adequately, but you can run the following commands to be sure:

```sh
>chown -R $USER:$USER $HOME/.tmux
>chmod 755 \
 $HOME/.tmux/plugins/tmux-resurrect-ng/scripts/check_tmux_version.sh \
 $HOME/.tmux/plugins/tmux-resurrect-ng/scripts/prompt_runner.sh \
 $HOME/.tmux/plugins/tmux-resurrect-ng/scripts/restore_auto.sh \
 $HOME/.tmux/plugins/tmux-resurrect-ng/scripts/restore.sh \
 $HOME/.tmux/plugins/tmux-resurrect-ng/scripts/save_auto.sh \
 $HOME/.tmux/plugins/tmux-resurrect-ng/scripts/save.sh \
 $HOME/.tmux/plugins/tmux-resurrect-ng/scripts/status_runner.sh \
 $HOME/.tmux/plugins/tmux-resurrect-ng/scripts/tmux_spinner.sh \
 $HOME/.tmux/plugins/tmux-resurrect-ng/command_strategies/*.sh \
 $HOME/.tmux/plugins/tmux-resurrect-ng/save_command_strategies/*.sh \
 $HOME/.tmux/plugins/tmux-resurrect-ng/strategies/*.sh
```

#### Update your .tmux.conf file
The automation offered by **tmux-resurrect-ng** is triggered by the `tmux` status bar and the `bash` prompt. Edit your .tmux.conf file by adding the following snippet to the **end** of your status-right configuration:

```sh
[#($HOME/.tmux/plugins/tmux-resurrect-ng/scripts/status_runner.sh)]
```

A complete example appears below:
```sh
set -g status-right "#(hostname -s | cut -c 1-23) #[fg=cyan][#(uptime | rev | cut -d":" -f1 | rev | sed s/,//g) ]#[default][#($HOME/.tmux/plugins/tmux-resurrect-ng/scripts/status_runner.sh)]"
```

It is recommended to also limit the width of the status-right section:
```sh
set -g status-right-length 40
```

To configure and load **tmux-resurrect-ng** add the following snippet to the **end** of your `.tmux.conf` file:


```sh
# enable tmux-resurrect-ng pane buffers
set -g @resurrect-enable-pane-buffers 'on'

# enable tmux-resurrect-ng pane history
set -g @resurrect-enable-pane-history 'on'

# load tmux-resurrect-ng
run-shell "$HOME/.tmux/plugins/tmux-resurrect-ng/resurrect-ng.tmux"
```

#### Update your .bash_profile file to enable prompt integration
The following snippet needs to be added to the bottom of your `.bash_profile` file:

```sh
# tmux-resurrect-ng prompt_runner for auto save/restore
if [[ -n "$TMUX" ]]; then
  source "$HOME/.tmux/plugins/tmux-resurrect-ng/scripts/prompt_runner.sh"
  export PROMPT_COMMAND="${PROMPT_COMMAND}${PROMPT_COMMAND:+; }tmxr_runner"
fi
```

New `bash` sessions will only load the above snippet if the TMUX environment variable has been set. When `tmux` instantiates a new pane it will add the variable to the pane's environment. The variable will not be visible outside of a tmux pane.

#### Exit tmux and kill the server
Restarting tmux completely is the easiest way to get up and running following installation:

```sh
>tmux kill-server
```

## Configuration options
Default settings are considered to be reasonable and, therefore, applicable for most users. The following settings can be adjusted if necessary:

|option|default|description|
|--------------|:---:|-------------------------------------------------|
|@resurrect-default-processes|(1)|default processes that are restored;<br />see list below |
|@resurrect-file-purge-frequency|5|number of old state/buffer/history files to keep;<br/>disable feature by setting to 0|
|@resurrect-save-auto-frequency|5|how often (in minutes) to trigger backups;<br/> disable feature by setting to 0 |
|@resurrect-enable-restore-auto|on|enable auto-restore mode|
|@resurrect-enable-pane-history|off|enable pane history save/restore|
|@resurrect-enable-pane-buffers|off|enable pane buffer save/restore|
|@resurrect-enable-pane-ansi-buffers|on|enable saving of ansi color buffers|

(1) vi, vim, nvim, emacs, man, less, more, tail, top, htop, irssi

Only common user options are listed above. Both `@resurrect-enable-pane-history` and `@resurrect-enable-pane-buffers` are disabled by default because only you know if your default shell is set to `bash`.

## Usage
The goal of **tmux-resurrect-ng** is automation.

#### Auto save
Saving of geometry is 100% automated and will occur every 5 minutes (unless configured otherwise). Saving of pane history and buffers is semi-automated: triggers will be created for panes where history or buffers files have become stale but the user needs to initiate a carriage return in each target pane to initiate history and buffer saves and consequently clear the triggers.


During normal use, as you enter commands, these carriage returns will occur as part of your activity and saving of pane history and buffers will occur unobtrusively. Triggers will not be created for panes that cannot be saved/restored. 


#### Auto restore
Restoration is 100% automated and will occur when a new named tmux session is created using a previously existing name. Window and pane geometry, history, and buffers will be restored from the last backup.

>NOTE: The **tmux-resurrect-ng** restore behavior differs from that implemented by [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect), where the latter will refuse to restore panes that have already been created by the user.

#### Auto purge
Historical backup files will be purged automatically according to the purge frequency setting.

#### Legacy manual save and restore
As of v0.9.0, **tmux-resurrect-ng** still supports manual trigger of save and restore via legacy key bindings. **This functionality will likely be removed before v1.0.0 is reached. Saved buffer files may include obtrusive calls to the history write command.**

##### Key bindings

| command | key binding       |
|---------|:-----------------:|
| save    | `prefix + Ctrl-s` |
| restore | `prefix + Ctrl-r` |

Custom key bindings can be set by adding the following to your `.tmux.conf` file:

```sh
set -g @resurrect-save 'S'
set -g @resurrect-restore 'R'
```

Then reload the `tmux` environment:

```sh
>tmux source-file $HOME/.tmux.conf
```

## Status

The **tmux-resurrect-ng** status bar feature will indicate the following states:

```sh
  [X] : tmux-resurrect-ng disabled
  [-] : enabled, pending progress
  [S] : state (geometry) (for all panes) saved and restorable
  [R] : state, buffer, history (for all panes), saved and restorable
  [?] : runtime error
  [!] : fatal (e.g. tmux version unsupported)
```

During normal operation progress will alternate between [-], [S] and [R]. When a single pane history or buffer file has become stale, status will remain on [S] until the pane's associated trigger has been cleared.

>The greater the number of panes idling at a shell prompt, the more likely it is that the status will be "stuck" on [S]. This is a limitation that will be addressed in a future release.

## Migration
Moving from [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) to **tmux-resurrect-ng** is simplified using the included migration script. The migration task is necessary only if you care about restoring previous session data before starting **tmux-resurrect-ng** for the first time. **A migration of data files is necessary because all of the file naming schemes have changed.**

The **tmux-resurrect-ng** v0.9.0 migration script supports [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) v1.5.0 and will migrate the following files:

|file                               |purpose     |
|-----------------------------------|------------|
|tmux_resurrect_TIMESTAMP.txt       |tmux state  |
|bash_history-SESSION:WINDOW.pane   |bash history|
|tmux_buffer-SESSION:WINDOW.pane    |pane buffer |

Run the migration script as follows:
```sh
>$HOME/.tmux/plugins/tmux-resurrect-ng/utilities/tmxr_migrate.sh
```

After running the migration script, original files will have been preserved in the following directory:

```sh
$HOME/.tmux/resurrect/migrated_files
```

To revert back to [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect), execute the following commands (after exiting tmux):

```sh
>tmux kill-server
>mv $HOME/.tmux/resurrect $HOME/.tmux/resurrect_NEW
>cp $HOME/.tmux/resurrect_NEW/migrated_files $HOME/.tmux/resurrect
```

Reconfigure `.tmux.conf` as needed, then restart `tmux`.

## Limitations
The **tmux-resurrect-ng** plugin is limited by functionality offered by `tmux` and the operating system itself. For the most part this means that save and restore of history and buffers can only be offered for pane shell sessions not actively running a program other than the shell itself. For example, if a pane is running the `top` command the pane geometry will be saved (so the pane itself will be restored) but until the `top` process has ended neither the pane history or buffer will be triggered for backup.

>NOTE: While the pane buffer could be saved, upon restore it would be out-of-sync with the history and potentially confusing to the user.
   
These limitations may sound...limiting...but the way we usually make use of the shell (running a command and then sitting idle, then running another command) means there are plenty of opportunities to backup.

It's also important to note that automated backups will not take place for a particular pane until the next carriage return is received at the prompt, while a trigger is in place (.trigger files are created whenever a pane history or buffer file has become stale).

## Compatibility
**tmux-resurrect-ng** has been developed and tested on OSX (10.10) and Linux (CentOS 7). The primary requirements/dependencies are:

* `bash` 4.0 or higher
* `tmux` 1.9 or higher

Shell command line history and pane buffer support is currently only supported for BASH.

## Attributions
The **tmux-resurrect-ng** `tmux` plugin was forked from the original [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) project by Bruno Sutic. Bruno has also created a lot of other useful plugins as part of his [tmux-plugins](https://github.com/tmux-plugins) project.

## License
**tmux-resurrect-ng** is licensed under the MIT open source license.
