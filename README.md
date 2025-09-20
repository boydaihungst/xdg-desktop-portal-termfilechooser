# xdg-desktop-portal-termfilechooser (Fork)

<!-- toc -->

- [Work best with org.freedesktop.FileManager1.common](#work-best-with-orgfreedesktopfilemanager1common)
- [Alternative](#alternative)
- [Installation](#installation)
  - [Build using package manager](#build-using-package-manager)
  - [Build from source](#build-from-source)
    - [Dependencies](#dependencies)
    - [Download the source](#download-the-source)
    - [Build](#build)
- [Configuration](#configuration)
  - [Disable the original file picker portal](#disable-the-original-file-picker-portal)
  - [Systemd service](#systemd-service)
  - [For yazi only (Optional)](#for-yazi-only-optional)
- [Test](#test)
  - [Troubleshooting](#troubleshooting)
- [For developers](#for-developers)
- [Usage](#usage)
- [Documentation](#documentation)
- [License](#license)

<!-- tocstop -->

[xdg-desktop-portal] backend for choosing files with your favorite file chooser.
By default, it will use the [yazi](https://github.com/sxyazi/yazi) file manager, but this is customizable.
Based on [xdg-desktop-portal-wlr] (xdpw).

## Work best with org.freedesktop.FileManager1.common

Having trouble with "Open in Folder" in your web browser’s download manager — where it doesn’t highlight the downloaded file or respect your file manager configuration? If so, check out this file manager D-Bus service. There's a preview section to help you understand what it does:
https://github.com/boydaihungst/org.freedesktop.FileManager1.common

By combining `xdg-desktop-portal-termfilechooser` with `org.freedesktop.FileManager1.common`,
you'll get a file-opening experience similar to macOS and Windows.

## Alternative

[https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser](https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser)

## Installation

### Build using package manager

For Arch:

```sh
yay -S xdg-desktop-portal-termfilechooser-boydaihungst-git
```

### Build from source

#### Dependencies

On apt-based systems:

```sh
sudo apt install xdg-desktop-portal build-essential ninja-build meson libinih-dev libsystemd-dev scdoc
```

For Arch, see the dependencies in the [AUR package](https://aur.archlinux.org/packages/xdg-desktop-portal-termfilechooser-boydaihungst-git#pkgdeps).

#### Download the source

```sh
git clone https://github.com/boydaihungst/xdg-desktop-portal-termfilechooser
```

#### Build

- Remove legacy files:

  ```sh
  cd xdg-desktop-portal-termfilechooser
  chmod +x remove_legacy_file.sh && sudo remove_legacy_file.sh
  ```

- Then check and update if you are using any old version of wrapper script: `$HOME/.config/xdg-desktop-portal-termfilechooser/ANY-wrapper.sh`
  If you use wrapper scripts from `/usr/share/xdg-desktop-portal-termfilechooser/ANY-wrapper.sh`, then it always up to date.

- Build and install:

  ```sh
  meson build --prefix=/usr
  ninja -C build
  sudo ninja -C build install
  ```

## Configuration

Copy the `config` and any of the wrapper scripts in `contrib` dir to `~/.config/xdg-desktop-portal-termfilechooser`.
Edit the `config` file to set your preferred terminal emulator and file manager applications.

For terminal emulator. You can set the `TERMCMD` environment variable instead of edit wrapper file.
So you only need to copy `config`. By default wrappers is placed at `/usr/share/xdg-desktop-portal-termfilechooser/`

Example:

- `$HOME/.profile`
- `.bashrc`

  ```sh
  # use wezterm intead of kitty
  export TERMCMD="wezterm start --always-new-process"
  ```

- `$HOME/.config/xdg-desktop-portal-termfilechooser/config` or `$XDG_CONFIG_HOME/xdg-desktop-portal-termfilechooser/config`
  Use yazi wrapper instead of ranger wrapper:

  ```dosini
  [filechooser]
  cmd=/usr/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
  default_dir=$HOME
  ```

- Use custom yazi wrapper instead of default wrapper:

  ```dosini
  [filechooser]
  cmd=$HOME/.config/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
  default_dir=$HOME
  ```

- or

  ```dosini
  [filechooser]
  cmd=$XDG_CONFIG_HOME/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
  default_dir=$HOME
  ```

The `default_dir` is used in case where the app, which triggers download/upload or select file/folder, doesn't suggested location to save/open file/directory or suggested a relative path to its CWD, which we can't access from dbus message.  
For example in firefox it's `$HOME` the first time, after successfully selected/saved file, it will remember the last selected location.
This location is suggested by the app (e.g. firefox), not by xdg-desktop-portal-termfilechooser itself. Normally, it remember the last selected location based on file extension.

### Disable the original file picker portal

- If your xdg-desktop-portal version is >= [`1.18.0`](https://github.com/flatpak/xdg-desktop-portal/releases/tag/1.18.0), then you can specify the portal for FileChooser in `~/.config/xdg-desktop-portal/portals.conf` file (see the [flatpak docs](https://flatpak.github.io/xdg-desktop-portal/docs/portals.conf.html) and [ArchWiki](https://wiki.archlinux.org/title/XDG_Desktop_Portal#Configuration)):

  ```sh
  # Get version of xdg-desktop-portal
  xdg-desktop-portal --version
  # If xdg-desktop-portal not on $PATH, try:
  /usr/libexec/xdg-desktop-portal --version

  # OR, if it says file not found
  /usr/libexec/xdg-desktop-portal --version
  # OR
  /usr/lib64/xdg-desktop-portal --version
  # OR
  /usr/lib64/xdg-desktop-portal --version
  ```

  ```dosini
  [preferred]
  org.freedesktop.impl.portal.FileChooser=termfilechooser
  ```

- If your `xdg-desktop-portal --version` is older, you can remove `FileChooser` from `Interfaces` of the `{gtk;kde;…}.portal` files:

  ```sh
  find /usr/share/xdg-desktop-portal/portals -name '*.portal' -not -name 'termfilechooser.portal' \
  -exec grep -q 'FileChooser' '{}' \; \
  -exec sudo sed -i'.bak' 's/org\.freedesktop\.impl\.portal\.FileChooser;\?//g' '{}' \;
  ```

### Systemd service

- Restart the portal service:

  ```sh
  systemctl --user restart xdg-desktop-portal.service
  ```

### For yazi only (Optional)

If you use yazi-wrapper.sh, you could install [boydaihungst/hover-after-moved.yazi](https://github.com/boydaihungst/hover-after-moved.yazi).
So when you move placeholder file to other directory, yazi will auto hover over it.
The placeholder file is created by termfilechooser when you save/download a file.

## Test

```sh
GTK_USE_PORTAL=1  zenity --file-selection
GTK_USE_PORTAL=1  zenity --file-selection --directory
GTK_USE_PORTAL=1  zenity --file-selection  --multiple

# Change `USER` to your `username`:
GTK_USE_PORTAL=1  zenity --file-selection  --save  --filename='/home/USER/save_file_$.txt
```

and additional options: `--multiple`, `--directory`, `--save`.

#### Troubleshooting

- After editing termfilechooser's config, restart its service:

  ```sh
  systemctl --user restart xdg-desktop-portal-termfilechooser.service
  ```

- Debug the termfilechooser:

  ```sh
  systemctl --user stop xdg-desktop-portal-termfilechooser.service
  /usr/libexec/xdg-desktop-portal-termfilechooser -l TRACE -r
  ```

  Or, if it says `No such file or directory`:

  ```sh
  # Run command below to get the location of xdg-desktop-portal-termfilechooser, which is ExecStart=COMMAND
  systemctl --user status xdg-desktop-portal-termfilechooser.service.
  /path/to/xdg-desktop-portal-termfilechooser -l TRACE -r
  ```

  This way the output from the wrapper scripts (e.g. `yazi-wrapper.sh`) will be written to the same terminal.
  Then try to reproduce the bug. Finally, upload create an issue and upload logs,
  app use xdg-open to open/save file and the custom wrapper script if you use it.

- Since [this merge request in GNOME](https://gitlab.gnome.org/GNOME/gtk/-/merge_requests/4829), `GTK_USE_PORTAL=1` seems to be replaced with `GDK_DEBUG=portals`.

- See also: [Troubleshooting section in ArchWiki](https://wiki.archlinux.org/title/XDG_Desktop_Portal#Troubleshooting).

## For developers

- Stop service: `systemctl --user stop xdg-desktop-portal-termfilechooser.service`
- Build and run in debug mode: `meson build --prefix=/usr --reconfigure && ninja -C build && ./build/xdg-desktop-portal-termfilechooser  -l TRACE -r`
- Monitor dbus message: `dbus-monitor --session "interface='org.freedesktop.portal.FileChooser'"`
- Explain what the values from dbus message for: https://github.com/flatpak/xdg-desktop-portal/blob/main/data/org.freedesktop.portal.FileChooser.xml

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
