#!/bin/bash
set -euo pipefail

app_path="${1:-}"
if [[ -n "${app_path}" ]]; then
  app_path="${app_path/#\~/$HOME}"
fi

say() { printf '%s\n' "$*"; }

say "LOGOComfort Apple‑silicon doctor"
say "--------------------------------"
say ""

say "1) Mac CPU architecture:"
arch_name="$(/usr/bin/uname -m)"
say "   uname -m = ${arch_name}"
say ""

say "2) Rosetta:"
if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
  say "   OK (Intel apps can run)"
else
  say "   NOT INSTALLED"
  say "   Install with:"
  say "     softwareupdate --install-rosetta --agree-to-license"
fi
say ""

say "3) Intel (x86_64) Java runtimes:"
/usr/libexec/java_home -V --arch x86_64 2>&1 || true
say ""

say "4) Preferred Intel Java 11 home (what the launcher tries first):"
java11_home="$(/usr/libexec/java_home -F --arch x86_64 -v 11 2>/dev/null || true)"
if [[ -n "${java11_home}" ]]; then
  say "   ${java11_home}"
  say "   java -version:"
  /usr/bin/arch -x86_64 "${java11_home}/bin/java" -version 2>&1 | /usr/bin/sed -n '1,3p' || true
else
  say "   (none found)"
fi
say ""

if [[ -n "${app_path}" ]]; then
  say "5) App bundle check:"
  if [[ ! -d "${app_path}" ]]; then
    say "   Not found: ${app_path}"
    exit 0
  fi

  say "   App: ${app_path}"

  exe_path="${app_path}/Contents/MacOS/LOGOComfort"
  if [[ -e "${exe_path}" ]]; then
    say "   Launcher file type:"
    /usr/bin/file "${exe_path}" || true
  else
    say "   Missing launcher: ${exe_path}"
  fi

  install_dir="$(cd "${app_path}/.." && pwd)"
  glass_lib="${install_dir}/lib/javafx/lib/libglass.dylib"
  if [[ -e "${glass_lib}" ]]; then
    say "   JavaFX native lib architecture (libglass.dylib):"
    /usr/bin/file "${glass_lib}" || true
  fi
fi

say ""
say "Done."

