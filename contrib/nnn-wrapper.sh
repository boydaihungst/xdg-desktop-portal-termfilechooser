#!/usr/bin/env bash

set -x
# This wrapper script is invoked by xdg-desktop-portal-termfilechooser.
#
# See `ranger-wrapper.sh` for the description of the input arguments and the output format.

cleanup() {
    if [ "$save" = "1" ] && [ ! -s "$out" ] && [ -f "$path" ]; then
        /usr/bin/rm "$path" || :
    fi
    if [ -f "$tmpfile" ]; then
        /usr/bin/rm -f "$tmpfile" || :
    fi
    if [ -f "$TMPFILE_SELECTED_DIR" ]; then
        /usr/bin/rm -f "$TMPFILE_SELECTED_DIR" || :
    fi
}
trap cleanup EXIT HUP INT QUIT ABRT TERM

multiple="$1"
directory="$2"
save="$3"
path="$4"
out="$5"
# termcmd="x-terminal-emulator -e"
termcmd="${TERMCMD:-/usr/bin/kitty --title termfilechooser}"
cmd="/usr/bin/nnn"
# -S [-s <session_file_name>] saves the last visited dir location and opens it on next startup

# See also: https://github.com/jarun/nnn/wiki/Basic-use-cases#file-picker

# nnn has no equivalent of ranger's:
# `--cmd`
# .. and no other way to show a message text on startup. So, no way to show instructions in nnn itself, like it is done in ranger-wrapper.
# nnn also does not show previews (needs a plugin and a keypress). So, the save instructions in `$path` file are not shown automatically.
# `--show-only-dirs`
# `--choosedir`
# - To select then upload all files in a folder: Go inside of the folder then quit.

# Even though nnn has session manager. We still use our own method to save last_selected file/folder.
# Because nnn select tmpfile (to strict only select "placeholder" file, when save = 1), which will save tmpfile path to session,
# instead of real selected file/folder.
# change this to "/tmp/xxxxxxx/.last_selected" if you only want to save last selected location
# in session (flushed after reset device)
last_selected_path_cfg="${XDG_STATE_HOME:-$HOME/.local/state}/xdg-desktop-portal-termfilechooser/last_selected"
/usr/bin/mkdir -p "$(/usr/bin/dirname "$last_selected_path_cfg")"
if [ ! -f "$last_selected_path_cfg" ]; then
    /usr/bin/touch "$last_selected_path_cfg"
fi
last_selected="$(/usr/bin/cat "$last_selected_path_cfg")"

# Restore last selected path
if [ -d "$last_selected" ]; then
    save_to_file=""
    if [ "$save" = "1" ]; then
        save_to_file="$(/usr/bin/basename "$path")"
        path="${last_selected}/${save_to_file}"
    else
        path="${last_selected}"
    fi
fi
if [ -z "$path" ]; then
    path="$HOME"
fi

if [ "$save" = "1" ]; then
    tmpfile=$(/usr/bin/mktemp)

    # Save/download file
    /usr/bin/printf '%s' 'xdg-desktop-portal-termfilechooser saving files tutorial

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!                 === WARNING! ===                 !!!
!!! The contents of *whatever* file you open last in !!!
!!! yazi will be *overwritten*!                    !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Instructions:
1) Move this file wherever you want.
2) Rename the file if needed.
3) Confirm your selection by opening the file, for
   example by pressing <Enter>.

Notes:
1) This file is provided for your convenience. You can
	 only choose this placeholder file otherwise the save operation aborted.
2) If you quit yazi without opening a file, this file
   will be removed and the save operation aborted.
' >"$path"
    # -a create new FIFO, -P to show preview if they exist
    # Ref: https://github.com/jarun/nnn/wiki/Live-previews
    set -- -p "$tmpfile" "$path"
else
    set -- -p "$out" "$path"
fi

command="$termcmd -- $cmd"
for arg in "$@"; do
    # escape double quotes
    escaped=$(/usr/bin/printf "%s" "$arg" | /usr/bin/sed 's/"/\\"/g')
    # escape spaces
    command="$command \"$escaped\""
done
if [ "$directory" = "1" ]; then
    # data will be `cd "/dir/path"`
    TMPFILE_SELECTED_DIR=$(/usr/bin/mktemp)
    /usr/bin/env NNN_TMPFILE="$TMPFILE_SELECTED_DIR" /usr/bin/sh -c "$command"
    if [ "$directory" = "1" ] && [ -f "$TMPFILE_SELECTED_DIR" ]; then
        LAST_SELECTED_DIR=$(cat "$TMPFILE_SELECTED_DIR")
        LAST_SELECTED_DIR="${LAST_SELECTED_DIR#cd \'}"
        LAST_SELECTED_DIR="${LAST_SELECTED_DIR%\'}"
        /usr/bin/echo "$LAST_SELECTED_DIR" >"$out"
    fi
else
    /usr/bin/sh -c "$command"
fi

# Moving selected file from $tmpfile to $out if selected file is valid placeholder file.
if [ "$save" = "1" ] && [ -s "$tmpfile" ]; then
    selected_file=$(/usr/bin/head -n 1 "$tmpfile")
    # Check if selected file is placeholder file
    if [ -f "$selected_file" ] && /usr/bin/grep -qi "^xdg-desktop-portal-termfilechooser saving files tutorial" "$selected_file"; then
        /usr/bin/cat "$tmpfile" >"$out"
    fi
fi

# Saving last selected directory, even when save = 1 and selected file isn't valid placeholder file.
if [ -s "$tmpfile" ] || [ -s "$out" ]; then
    if [ -s "$out" ]; then
        selected_path=$(head -n 1 <"$out")
    elif [ -s "$tmpfile" ]; then
        selected_path=$(head -n 1 <"$tmpfile")
    fi
    if [ -d "$selected_path" ]; then
        echo "$selected_path" >"$last_selected_path_cfg"
    elif [ -f "$selected_path" ]; then
        dirname "$selected_path" >"$last_selected_path_cfg"
    fi
fi
