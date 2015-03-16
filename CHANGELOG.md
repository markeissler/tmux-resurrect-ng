
v1.0.2 / 2015-03-16
===================
  * Added this CHANGELOG!

v1.0.1 / 2015-03-15
===================

  * Updated README for 1.0.1.
  * Added tmux_start.sh startup wrapper script.
  * Fixed running shell detection for OSX which prevented buffers and histories from being saved by prompt_command.
  * Fixed missing tmxr_version file format number for 1.0.x.

v1.0.0 / 2015-03-04
===================

  * Now REQUIRES tmux-1.9a1 (custom patch to support nested format specifiers)
  * Switched to session-based workflow. There is a now an expectation of a 1:1 relationship between a tmux client and a tmux session. On the client-side this means opening a new terminal for each session. Each client will reflect an accurate tmux-resurrect-ng status for its session.
  * Updated README for 1.0.0.
  * Supports multiple sessions in separate clients with correct tmux-resurrect-ng Implemented passing through of session_name from status_runner runtime params using tmux-1.9a1.
  * Implemented restore lock file so status_runner doesn't trigger save_auto and clobber restore progress.
  * Refactored purge triggers and actions functions and moved to new session-oriented helpers file.
  * Implemented versioning in state files to support future migration to new file format versions.
  * Implemented more efficient trigger file creation. Triggers only created now if activity has occurred in a given pane.
  * Updated migration script to accommodate rollback on failure at any migration step.
  * Moved resurrect-ng files into their own directory (instead of original resurrect dir).

v0.9.2 / 2015-02-19
===================

  * Bug fixes.
  * Added append of ansi color reset at the end of buffer file to be sure color is reset.
  * Updated PROMPT_COMMAND setup instructions (in README).

v0.9.1 / 2015-02-19
===================

  * Bug fix for buffer save when buffer contains hex.

v0.9.0 / 2015-02-16
===================

  * First releast of tmux-resurrect-ng!
  * Fixes for configuration instructions for tmux.conf and bash_profile.
  * Cleaned up default static settings for clarity.
  * Updated README, license text.
  * Updated plugin name.
  * Implemented pane 1 clobbering on restore. We now restore all panes when restoring.
  * Implemented purging of all trigger files at startup.
  * Refined determination of when it is safe to save pane buffers and history.
  * Stopped creation of triggers for panes not idling at a bash prompt.
  * Fixed checking of session time in status_runner. We should be comparing against tmux status_interval, not auto save frequency.
  * Implemented restore-auto functionality.
  * Refactored for portability and to read server config values, with static overrides for directory and buffer extension.
  * Added a script to migrate from tmux-resurrect to tmux-resurrect-ng.
  * Added auto-purging support for state, history and buffer files.
  * Added enable_debug_mode option so it can be set globally.
  * Updated to support running history and buffer dumps from prompt_runner.
  * Added prompt_runner for bash PROMPT_COMMAND.
  * Implemented less-intrusive status bar activity feedback.
  * Implemented auto-save for state/layout (resurrect) and trigger files.
  * Added ansi color support for saving and restoring pane buffers.
  * Added support for saving and restoring buffers for panes running Bash.
  * Removed pre-fork tags--our versions start at 0.9.0!

Fork from tmux-resurrect 2014-12-09
===================================
Changelog previous to fork.

  * v1.5.0, 2014-11-09
  * add support for restoring neovim sessions
  * v1.4.0, 2014-10-25
  *plugin now uses strategies when fetching pane full command. Implemented 'default' strategy.
  * save command strategy: 'pgrep'. It's here only if fallback is needed.
  * save command strategy: 'gdb'
  * rename default strategy name to 'ps'
  * create `expect` script that can fully restore tmux environment
  * fix default save command strategy ps command flags. Flags are different for FreeBSD.
  * add bash history saving and restoring (@rburny)
  * preserving layout of zoomed windows across restores (@Azrael3000)
  * v1.3.0, 2014-09-20
  * remove dependency on pgrep command. Use ps for fetching process names.
  * v1.2.1, 2014-09-02
  * tweak 'new_pane' creation strategy to fix #36
  * when running multiple tmux server and for a large number of panes (120 +) when doing a restore, some panes might not be created. When that is the case also don't restore programs for those panes.
  * v1.2.0, 2014-09-01
  * new feature: inline strategies when restoring a program
  * v1.1.0, 2014-08-31
  * bugfix: sourcing variables.sh file in save script
  * add Ctrl key mappings, deprecate Alt keys mappings.
  * v1.0.0, 2014-08-30
  * show spinner during the save process
  * add screencast script
  * make default program running list even more conservative
  * v0.4.0, 2014-08-29
  * change plugin name to tmux-resurrect. Change all the variable names.
  * v0.3.0, 2014-08-29
  * bugfix: when top is running the pane $PWD can't be saved. This was causing issues during the restore and is now fixed.
  * restoring sessions multiple times messes up the whole environment - new panes are all around. This is now fixed - pane restorations are now idempotent.
  * if pane exists from before session restore - do not restore the process within it. This makes the restoration process even more idempotent.
  * more panes within a window can now be restored
  * restore window zoom state
  * v0.2.0, 2014-08-29
  * bugfix: with vim 'session' strategy, if the session file does not exist - make sure vim does not contain -S flag
  * enable restoring programs with arguments (e.g. "rails console") and also processes that contain program name
  * improve irb restore strategy
  * v0.1.0, 2014-08-28
  * refactor checking if saved tmux session exists
  * spinner while tmux sessions are restored
  * v0.0.5, 2014-08-28
  * restore pane processes
  * user option for disabling pane process restoring
  * enable whitelisting processes that will be restored
  * expand readme with configuration options
  * enable command strategies; enable restoring vim sessions
  * update readme: explain restoring vim sessions
  * v0.0.4, 2014-08-26
  * restore pane layout for each window
  * bugfix: correct pane ordering in a window
  * v0.0.3, 2014-08-26
  * save and restore current and alternate session
  * fix a bug with non-existing window names
  * restore active pane for each window that has multiple panes
  * restore active and alternate window for each session
  * v0.0.2, 2014-08-26
  * saving a new session does not remove the previous one
  * make the directory where sessions are stored configurable
  * support only Tmux v1.9 or greater
  * display a nice error message if saved session file does not exist
  * added README
  * v0.0.1, 2014-08-26
  * started project
  * basic saving and restoring works
