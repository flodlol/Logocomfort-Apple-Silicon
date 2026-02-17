#!/bin/bash
set -euo pipefail

SIEMENS_URL="https://support.industry.siemens.com/cs/document/109826921/logo!soft-comfort-v8-4-demo?dti=0&lc=en-GB"
JAVA_URL="https://www.azul.com/core-post-download/?endpoint=zulu&uuid=f6d9f03c-44f3-49d0-976f-e11561997a32"

say() { printf '%s\n' "$*"; }

is_macos() { [[ "${OSTYPE:-}" == "darwin"* ]]; }

ensure_rosetta() {
  if [[ "$(/usr/bin/uname -m)" != "arm64" ]]; then
    return 0
  fi
  if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    return 0
  fi
  say "Installing Rosetta 2 (one time)..."
  sudo softwareupdate --install-rosetta --agree-to-license
}

java_major_version() {
  local java_bin="$1"
  local spec_version java_major
  spec_version="$(
    /usr/bin/arch -x86_64 "$java_bin" -XshowSettings:properties -version 2>&1 |
      /usr/bin/awk -F' = ' '/^[[:space:]]*java[.]specification[.]version[[:space:]]*=/{print $2; exit}'
  )"
  spec_version="${spec_version//[[:space:]]/}"
  if [[ -z "${spec_version}" ]]; then
    return 1
  fi
  java_major="$spec_version"
  if [[ "$spec_version" == 1.* ]]; then
    java_major="${spec_version#1.}"
  fi
  java_major="${java_major%%.*}"
  printf '%s\n' "$java_major"
}

ensure_intel_java_11() {
  local java_home java_bin major

  java_home="$(/usr/libexec/java_home -F --arch x86_64 -v 11 2>/dev/null || true)"
  if [[ -z "$java_home" ]]; then
    java_home="$(/usr/libexec/java_home -F --arch x86_64 2>/dev/null || true)"
  fi

  if [[ -z "$java_home" ]]; then
    say ""
    say "Missing Intel (x86_64) Java 11+."
    say "Download/install it, then run this again:"
    say "  $JAVA_URL"
    if command -v open >/dev/null 2>&1; then open "$JAVA_URL" >/dev/null 2>&1 || true; fi
    return 1
  fi

  java_bin="$java_home/bin/java"
  if [[ ! -x "$java_bin" ]]; then
    say "Found Java home but java is missing:"
    say "  $java_bin"
    return 1
  fi

  if ! /usr/bin/arch -x86_64 "$java_bin" -version >/dev/null 2>&1; then
    say ""
    say "Your Java is not runnable as Intel (x86_64)."
    say "Install a macOS x64/Intel Java 11+ and re-run."
    say "  $JAVA_URL"
    if command -v open >/dev/null 2>&1; then open "$JAVA_URL" >/dev/null 2>&1 || true; fi
    return 1
  fi

  major="$(java_major_version "$java_bin" || true)"
  if [[ -z "$major" || "$major" -lt 11 ]]; then
    say ""
    say "Your Intel Java is too old (need 11+)."
    say "Install a macOS x64/Intel Java 11+ and re-run."
    say "  $JAVA_URL"
    if command -v open >/dev/null 2>&1; then open "$JAVA_URL" >/dev/null 2>&1 || true; fi
    return 1
  fi

  say "Intel Java OK: $java_home (major $major)"
  return 0
}

find_logocomfort_apps_in_root() {
  local root="$1"
  [[ -d "$root" ]] || return 0

  /usr/bin/find "$root" -maxdepth 6 -type f -path "*/Contents/MacOS/LOGOComfort" -print 2>/dev/null |
    while IFS= read -r exe; do
      (cd "$(dirname "$exe")/../.." && pwd)
    done
}

pick_first_app() {
  local start="${1:-}"
  local -a roots apps

  if [[ -n "$start" ]]; then
    start="${start/#\~/$HOME}"
    if [[ -d "$start" && -f "$start/Contents/Info.plist" ]]; then
      printf '%s\n' "$start"
      return 0
    fi
    roots+=("$start")
  fi

  roots+=("$PWD" "$HOME/Applications" "/Applications" "$HOME/Downloads")

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    apps+=("$line")
  done < <(
    for r in "${roots[@]}"; do
      find_logocomfort_apps_in_root "$r"
    done | /usr/bin/awk '!seen[$0]++'
  )

  if [[ "${#apps[@]}" -eq 0 ]]; then
    return 1
  fi

  local best_app="" best_mtime=0 mtime
  for a in "${apps[@]}"; do
    mtime="$(/usr/bin/stat -f '%m' "$a" 2>/dev/null || echo 0)"
    if [[ "$mtime" -ge "$best_mtime" ]]; then
      best_mtime="$mtime"
      best_app="$a"
    fi
  done

  printf '%s\n' "$best_app"
}

find_setup_zips_in_root() {
  local root="$1"
  [[ -d "$root" ]] || return 0
  /usr/bin/find "$root" -maxdepth 8 -type f -name "Setup.zip" -print 2>/dev/null || true
}

pick_latest_setup_zip() {
  local -a roots zips
  local best_zip="" best_mtime=0 mtime

  roots+=("$PWD" "$HOME/Downloads")

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    zips+=("$line")
  done < <(
    for r in "${roots[@]}"; do
      find_setup_zips_in_root "$r"
    done | /usr/bin/awk '!seen[$0]++'
  )

  for z in "${zips[@]:-}"; do
    mtime="$(/usr/bin/stat -f '%m' "$z" 2>/dev/null || echo 0)"
    if [[ "$mtime" -ge "$best_mtime" ]]; then
      best_mtime="$mtime"
      best_zip="$z"
    fi
  done

  [[ -n "$best_zip" ]] || return 1
  printf '%s\n' "$best_zip"
}

main() {
  if ! is_macos; then
    say "This script is for macOS."
    exit 1
  fi

  say "== LOGOComfort Apple‑silicon quick fix =="

  ensure_rosetta
  app_path="$(pick_first_app "${1:-}" || true)"

  if [[ -z "${app_path:-}" ]]; then
    say ""
    say "Still can't find LOGOComfort."
    say "Make sure you installed it using the Siemens demo:"
    say "  $SIEMENS_URL"
    say ""
    if setup_zip="$(pick_latest_setup_zip || true)"; then
      say "Installer file I found on your machine:"
      say "  $setup_zip"
      if command -v open >/dev/null 2>&1; then open -R "$setup_zip" >/dev/null 2>&1 || true; fi
      say ""
      say "Double‑click Setup.zip, then run the installer inside and finish the install."
      say "After that, run this script again."
      exit 1
    fi

    say "I looked in:"
    say "  - $PWD"
    say "  - $HOME/Applications"
    say "  - /Applications"
    say "  - $HOME/Downloads"
    say ""
    say "Typical location looks like:"
    say "  $HOME/Applications/LOGOComfort_V8.4(Demo)/LOGOComfort.app"
    say ""
    say "Then run this script again."
    if command -v open >/dev/null 2>&1; then open "$SIEMENS_URL" >/dev/null 2>&1 || true; fi
    exit 1
  fi

  say "Found app:"
  say "  $app_path"

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  SUDO=""
  if [[ ! -w "$app_path/Contents/MacOS" ]]; then
    SUDO="sudo"
  fi

  $SUDO "$script_dir/patch-logocomfort.sh" "$app_path"
  $SUDO xattr -dr com.apple.quarantine "$app_path" >/dev/null 2>&1 || true

  if ensure_intel_java_11; then
    open "$app_path" >/dev/null 2>&1 || true
    say "Done."
  else
    say ""
    say "LOGOComfort is patched, but Java is missing."
    say "Install Intel (x64/x86_64) Java 11+, then open LOGOComfort again."
    exit 1
  fi
}

main "$@"
