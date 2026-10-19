#!/bin/bash
export ANDROID_HOME=/opt/android-sdk
SM=$(ls $ANDROID_HOME/cmdline-tools/*/bin/sdkmanager | head -1)
yes | $SM --licenses >/dev/null 2>&1
$SM --list_installed 2>&1 | grep -i platform
$SM "platforms;android-37.0" 2>&1 | tail -3
ls $ANDROID_HOME/platforms
