# xdg-desktop-portal-termfilechooser

<!--toc:start-->

- [xdg-desktop-portal-termfilechooser](#xdg-desktop-portal-termfilechooser)
  - [Installation](#installation)
    - [Dependencies](#dependencies)
    - [Download the source](#download-the-source)
    - [Build](#build)
    - [Config files](#config-files)
    - [Disable the original file picker portal](#disable-the-original-file-picker-portal)
    - [Systemd service](#systemd-service)
    - [Test](#test)
      - [Troubleshooting](#troubleshooting)
  - [Usage](#usage)
  - [Documentation](#documentation)
  - [License](#license)
      <!--toc:end-->

[xdg-desktop-portal] backend for choosing files with your favorite file chooser.
By default, it will use the [yazi](https://github.com/sxyazi/yazi) file manager, but this is customizable.
Based on [xdg-desktop-portal-wlr] (xdpw).

### Have problem with "open in folder" in web browser download manager, which doesn't horver over downloaded file, or load file manager config?

If so, check out this file manager dbus service, there is a the preview section to understand what it does:
https://github.com/boydaihungst/org.freedesktop.FileManager1.common

`xdg-desktop-portal-termfilechooser` + `org.freedesktop.FileManager1.common` make you will have the same experience like in macos/windows.

## ~~Deprecated~~ Alternative:

[https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser](https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser)

## Installation

### Build using package manager

For Arch:

    yay -S xdg-desktop-portal-termfilechooser-boydaihungst-git

### Build from source

#### Dependencies

On apt-based systems:

    sudo apt install xdg-desktop-portal build-essential ninja-build meson libinih-dev libsystemd-dev scdoc

For Arch, see the dependencies in the [AUR package](https://aur.archlinux.org/packages/xdg-desktop-portal-termfilechooser-boydaihungst-git#pkgdeps).

#### Download the source

    git clone https://github.com/boydaihungst/xdg-desktop-portal-termfilechooser

#### Build

    cd xdg-desktop-portal-termfilechooser
    meson build
    ninja -C build
    ninja -C build install  # run with superuser privileges

On Debian, move the `termfilechooser.portal` file:

    sudo mv /usr/local/share/xdg-desktop-portal/portals/termfilechooser.portal /usr/share/xdg-desktop-portal/portals/

## Configuration

Copy the `config` and any of the wrapper scripts in `contrib` dir to `~/.config/xdg-desktop-portal-termfilechooser`. Edit the `config` file to set your preferred terminal emulator and file manager applications.

For terminal emulator. You can set the `TERMCMD` environment variable instead of edit wrapper file. So you only need to copy `config`. By default wrappers
is placed at `/usr/local/share/xdg-desktop-portal-termfilechooser/`

Example:

- `$HOME/.profile`
- `.bashrc`

```sh
# use wezterm intead of kitty
export TERMCMD="wezterm start --always-new-process"
```

- `$HOME/.config/xdg-desktop-portal-termfilechooser/config` or `$XDG_CONFIG_HOME/xdg-desktop-portal-termfilechooser/config`
  Use yazi wrapper instead of ranger wrapper:

      [filechooser]
      cmd=/usr/local/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
      default_dir=$HOME

  Use custom yazi wrapper instead of default wrapper:

      [filechooser]
      cmd=$HOME/.config/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
      default_dir=$HOME

      or

      [filechooser]
      cmd=$XDG_CONFIG_HOME/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
      default_dir=$HOME

`default_dir` is where the app, which triggers download/upload or select file/folder, suggested to save file.
For example in firefox it's `$HOME` the first time, after successfully selected/saved file, it will remember the last selected location. This location is suggested by the app (e.g. firefox), not by xdg-desktop-portal-termfilechooser itself.

### Disable the original file picker portal

If your xdg-desktop-portal version

    xdg-desktop-portal --version
    # If xdg-desktop-portal not on $PATH, try:
    /usr/libexec/xdg-desktop-portal --version
    # OR, if it says file not found
    /usr/lib64/xdg-desktop-portal --version

is >= [`1.18.0`](https://github.com/flatpak/xdg-desktop-portal/releases/tag/1.18.0), then you can specify the portal for FileChooser in `~/.config/xdg-desktop-portal/portals.conf` file (see the [flatpak docs](https://flatpak.github.io/xdg-desktop-portal/docs/portals.conf.html) and [ArchWiki](https://wiki.archlinux.org/title/XDG_Desktop_Portal#Configuration)):

    [preferred]
    org.freedesktop.impl.portal.FileChooser=termfilechooser

If your `xdg-desktop-portal --version` is older, you can remove `FileChooser` from `Interfaces` of the `{gtk;kde;…}.portal` files:

    find /usr/share/xdg-desktop-portal/portals -name '*.portal' -not -name 'termfilechooser.portal' \
    	-exec grep -q 'FileChooser' '{}' \; \
    	-exec sudo sed -i'.bak' 's/org\.freedesktop\.impl\.portal\.FileChooser;\?//g' '{}' \;

### Systemd service

Restart the portal service:

    systemctl --user restart xdg-desktop-portal.service

## Test

    GTK_USE_PORTAL=1  zenity --file-selection
    GTK_USE_PORTAL=1  zenity --file-selection --directory
    GTK_USE_PORTAL=1  zenity --file-selection  --multiple

    Change `USER` to your `username`
    GTK_USE_PORTAL=1  zenity --file-selection  --save  --filename='/home/USER/save_file_$.txt

and additional options: `--multiple`, `--directory`, `--save`.

#### Troubleshooting

- After editing termfilechooser's config, restart its service:
  `systemctl --user restart xdg-desktop-portal-termfilechooser.service`

- The termfilechooser's executable can also be launched directly:

      systemctl --user stop xdg-desktop-portal-termfilechooser.service
      /usr/local/libexec/xdg-desktop-portal-termfilechooser -l TRACE -r

  or, if it says file/folder not found:

      systemctl --user stop xdg-desktop-portal-termfilechooser.service
      /usr/lib64/xdg-desktop-portal-termfilechooser -l TRACE -r

  This way the output from the wrapper scripts (e.g. `ranger-wrapper.sh`) will be written to the same terminal. This is handy for using e.g. `set -x` in the scripts during debugging.
  When termfilechooser runs as a `systemd` service, its output can be viewer with `journalctl`.
  Increase `-n 1000` (lines) to show more lines

      journalctl -e -f --user -n 1000 -u xdg-desktop-portal-termfilechooser.service

- Since [this merge request in GNOME](https://gitlab.gnome.org/GNOME/gtk/-/merge_requests/4829), `GTK_USE_PORTAL=1` seems to be replaced with `GDK_DEBUG=portals`.

- See also: [Troubleshooting section in ArchWiki](https://wiki.archlinux.org/title/XDG_Desktop_Portal#Troubleshooting).

## Usage

Firefox has a setting in its `about:config` to always use XDG desktop portal's file chooser: set `widget.use-xdg-desktop-portal.file-picker` to `1`. See [https://wiki.archlinux.org/title/Firefox#XDG_Desktop_Portal_integration](https://wiki.archlinux.org/title/Firefox#XDG_Desktop_Portal_integration).

## Documentation

See `man 5 xdg-desktop-portal-termfilechooser`.

## License

MIT

[xdg-desktop-portal](https://github.com/flatpak/xdg-desktop-portal)
[original author: GermainZ](https://github.com/GermainZ/xdg-desktop-portal-termfilechooser)
[xdg-desktop-portal-wlr](https://github.com/emersion/xdg-desktop-portal-wlr)
[ranger](https://github.com/ranger/ranger/)
[yazi](https://github.com/sxyazi/yazi/)
[lf](https://github.com/gokcehan/lf)
[fzf](https://github.com/junegunn/fzf)
[nnn](https://github.com/jarun/nnn)
[vifm](https://github.com/vifm/vifm)
