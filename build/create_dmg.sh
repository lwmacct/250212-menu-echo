#!/usr/bin/env bash

__main() {
  rm -rf MenuEcho.dmg
  create-dmg \
    --volname "Application Installer" \
    --background "bg.svg" \
    --window-pos 400 200 \
    --window-size 660 400 \
    --icon-size 100 \
    --icon "MenuEcho.app" 160 185 \
    --hide-extension "MenuEcho.app" \
    --app-drop-link 500 185 \
    "MenuEcho.dmg" \
    "MenuEcho.app/"
}

__main
