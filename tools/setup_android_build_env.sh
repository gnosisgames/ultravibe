#!/usr/bin/env bash
# Source before Android exports (terminal or CI).
# Installs via: brew install openjdk@17 android-platform-tools android-commandlinetools
set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$JAVA_HOME/bin:/opt/homebrew/bin:$PATH"
