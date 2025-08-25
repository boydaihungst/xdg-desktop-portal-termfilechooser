#!/usr/bin/env bash
sudo rm -f "/usr/local/lib/systemd/user/xdg-desktop-portal-termfilechooser.service"
sudo rm -f "/usr/local/lib64/systemd/user/xdg-desktop-portal-termfilechooser.service"
sudo rm -f "/usr/local/libexec/xdg-desktop-portal-termfilechooser"
sudo rm -f "/usr/local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.termfilechooser.service"
sudo rm -rf "/usr/local/share/xdg-desktop-portal-termfilechooser/"
