#!/usr/bin/env bash

set -x
# This wrapper script is invoked by xdg-desktop-portal-termfilechooser.
#
# See `ranger-wrapper.sh` for the description of the input arguments and the output format.

cleanup() {
    if [ -f "$tmpfile" ]; then
        /usr/bin/rm "$tmpfile" || :
    fi
    if [ "$save" = "1" ] && [ ! -s "$out" ]; then
        /usr/bin/rm "$path" || :
    fi
}
trap cleanup EXIT HUP INT QUIT ABRT TERM

multiple="$1"
directory="$2"
save="$3"
path="$4"
out="$5"
cmd="/usr/bin/nnn"
if [ "$save" = "1" ]; then
    TITLE="Save File:"
elif [ "$directory" = "1" ]; then
    TITLE="Select Directory:"
else
    TITLE="Select File:"
fi

termcmd="${TERMCMD:-/usr/bin/kitty}"
# See also: https://github.com/jarun/nnn/wiki/Basic-use-cases#file-picker

# nnn has no equivalent of ranger's:
# `--cmd`
# .. and no other way to show a message text on startup. So, no way to show instructions in nnn itself, like it is done in ranger-wrapper.
# nnn also does not show previews (needs a plugin and a keypress). So, the save instructions in `$path` file are not shown automatically.
# `--show-only-dirs`
# `--choosedir`
# - To select then upload all files in a folder: Go inside of the folder then quit.

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
elif [ "$directory" = "1" ]; then
    # data will has the format: `cd '/absolute/path/to/folder'`
    tmpfile=$(/usr/bin/mktemp)
    set -- "$path"
else
    set -- -p "$out" "$path"
fi

if [ "$directory" = "1" ]; then
    /usr/bin/env NNN_TMPFILE="$tmpfile" $termcmd --title "$TITLE" -- $cmd "$@"
else
    $termcmd --title "$TITLE" -- $cmd "$@"
fi

if [ "$directory" = "1" ] && [ -s "$tmpfile" ]; then
    # convert from `cd '/absolute/path/to/folder'` to `/absolute/path/to/folder`
    selected_dir=$(/usr/bin/head -n 1 "$tmpfile")
    selected_dir="${selected_dir#cd \'}"
    selected_dir="${selected_dir%\'}"
    /usr/bin/echo "$selected_dir" >"$out"
fi

# case save file
if [ "$save" = "1" ] && [ -s "$tmpfile" ]; then
    selected_file=$(/usr/bin/head -n 1 "$tmpfile")
    # Check if selected file is placeholder file
    if [ -f "$selected_file" ] && /usr/bin/grep -qi "^xdg-desktop-portal-termfilechooser saving files tutorial" "$selected_file"; then
        /usr/bin/echo "$selected_file" >"$out"
        path="$selected_file"
    fi
fi
