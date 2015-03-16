# variables.sh
#
# requires:
#   --nothing
#

# variables preceded with "dep_" are deprecrated versions of the same var.

# global current session
TMXR_SESSION=""

#
tmxr_version="1.0.2"

# supported tmxr versions
#
# Used for auto-migrating older tmxr file formats to this version.
#
tmxr_version_list=(
  "0.9"
  "1.0"
)

# supported tmux versions
tmux_version_list=(
  "1.9a1"
)

##
# key bindings
##

default_save_key="M-s C-s"
save_option="@resurrect-save"

default_restore_key="M-r C-r"
restore_option="@resurrect-restore"

##
# general options
##

# default processes that are restored
default_proc_list_option="@resurrect-default-processes"
default_proc_list='vi vim nvim emacs man less more tail top htop irssi'

# resurrect debug mode
#
# State debug files (including history and buffer) will be written to /tmp
# and will be prefixed with "tmxr_".
#
enable_debug_mode_option="@resurrect-enable-debug-mode"
default_enable_debug_mode="off"

# User defined processes that are restored
#  'false' - nothing is restored
#  ':all:' - all processes are restored
#
# user defined list of programs that are restored:
#  'my_program foo another_program'
restore_processes_option="@resurrect-processes"
restore_processes=""

##
# strategy options
##

# Defines part of the user variable. Example usage:
#   set -g @resurrect-strategy-vim "session"
restore_process_strategy_option="@resurrect-strategy-"

inline_strategy_token="->"

pane_full_command_strategy_option="@resurrect-pane-full-command-strategy"
default_pane_full_command_strategy="ps_pane_full_command"
dep_pane_full_command_strategy_option="@resurrect-save-command-strategy"

session_etime_command_strategy_option="@resurrect-session-etime-command-strategy"
default_session_etime_command_strategy="ps_session_etime"

stat_mtime_command_strategy_option="@resurrect-stat-mtime-command-strategy"
default_stat_mtime_command_strategy="stat_mtime"

##
# state options
##

# File purge frequency
#
# Maximum number of past state/history/buffer files to maintain. Once this
# number of files has been reached, oldest files will be purged. Values less
# than 0 will be set to 0. Disable file purge with a setting of "0".
#
# The default value of "5" is considered a reasonable setting.
#
file_purge_frequency_option="@resurrect-file-purge-frequency"
default_file_purge_frequency="5"

# Auto save freqency
#
# Specified in minutes. Values less than 0 will be set to 0. Values between 1
# and 4 will be set to 5. Disable save auto with a setting of "0".
#
# The default value of "5" is considered a reasonable setting.
#
save_auto_frequency_option="@resurrect-save-auto-frequency"
default_save_auto_frequency="5"

# Auto restore previous sessions
#
# Only works with BASH.
#
enable_restore_auto_option="@resurrect-enable-restore-auto"
default_enable_restore_auto="on"

# Save pane shell history
#
# Only works with BASH.
#
enable_pane_history_option="@resurrect-enable-pane-history"
default_enable_pane_history="off"
dep_enable_pane_history_option="@resurrect-save-bash-history"

# Save pane buffers
#
# Only works with BASH. ANSI buffers are enabled by default to preserve colors.
#
enable_pane_buffers_option="@resurrect-enable-pane-buffers"
default_enable_pane_buffers="off"
dep_enable_pane_buffers_option="@resurrect-save-pane-buffers"

enable_pane_ansi_buffers_option="@resurrect-enable-pane-ansi-buffers"
default_enable_pane_ansi_buffers="on"
dep_enable_pane_ansi_buffers_option="@resurrect-enable-ansi-buffers"
