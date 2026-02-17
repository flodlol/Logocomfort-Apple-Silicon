#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/patch-logocomfort.sh "/path/to/LOGOComfort.app"

Tip: You can drag LOGOComfort.app into Terminal to insert the path.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

app_path="${1:-}"
if [[ -z "${app_path}" ]]; then
  usage
  exit 1
fi

# Expand "~" if present
app_path="${app_path/#\~/$HOME}"

if [[ ! -d "${app_path}" ]]; then
  echo "Error: App not found: ${app_path}" >&2
  exit 1
fi

if [[ ! -f "${app_path}/Contents/Info.plist" ]]; then
  echo "Error: This doesn't look like a macOS .app bundle: ${app_path}" >&2
  exit 1
fi

macos_dir="${app_path}/Contents/MacOS"
exe_path="${macos_dir}/LOGOComfort"
backup_path="${macos_dir}/LOGOComfort-launchanywhere-x86_64"

if [[ ! -d "${macos_dir}" ]]; then
  echo "Error: Missing ${macos_dir}" >&2
  exit 1
fi

if [[ ! -e "${exe_path}" ]]; then
  echo "Error: Missing executable: ${exe_path}" >&2
  exit 1
fi

echo "Patching:"
echo "  App: ${app_path}"

if [[ -e "${backup_path}" ]]; then
  echo "Backup already exists:"
  echo "  ${backup_path}"
else
  if /usr/bin/file "${exe_path}" | /usr/bin/grep -q "Mach-O"; then
    echo "Creating backup of original launcher:"
    echo "  ${exe_path} -> ${backup_path}"
    /bin/mv "${exe_path}" "${backup_path}"
  else
    echo "Warning: ${exe_path} is not a Mach-O binary; leaving it in place (it may already be patched)." >&2
  fi
fi

cat >"${exe_path}" <<'LAUNCHER'
#!/bin/zsh
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
bundle_dir="$(cd "$script_dir/../.." && pwd)"
install_dir="$(cd "$bundle_dir/.." && pwd)"

cd "$install_dir"

log_file="/tmp/LOGOComfort-launch.log"
mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
{
  echo ""
  echo "===== $(date) ====="
  echo "launcher_version: 2026-02-17"
  echo "launcher: $0"
  echo "install_dir: $install_dir"
  echo "bundle_dir: $bundle_dir"
  echo "script_dir: $script_dir"
  echo "LOGOCOMFORT_JAVA_HOME: ${LOGOCOMFORT_JAVA_HOME:-}"
} >>"$log_file" 2>/dev/null || true

if command -v tee >/dev/null 2>&1; then
  exec > >(tee -a "$log_file") 2>&1
else
  exec >>"$log_file" 2>&1
fi

die() {
  echo "LOGOComfort launcher error: $*" >&2
  exit 1
}

alert() {
  local message="$1"
  printf '%b\n' "$message" >&2
  printf '\nLog file:\n  %s\n' "$log_file" >&2

  # If launched from Finder, stderr won't be visible; show something on screen.
  if command -v osascript >/dev/null 2>&1; then
    LOGOCOMFORT_ALERT_MESSAGE="$(printf '%b' "$message")" \
      /usr/bin/osascript -l JavaScript \
      -e 'ObjC.import("stdlib"); var msg=$.getenv("LOGOCOMFORT_ALERT_MESSAGE"); var app=Application.currentApplication(); app.includeStandardAdditions=true; app.displayAlert("LOGOComfort", {message: msg});' \
      >/dev/null 2>&1 || true
  fi

  # If we have no TTY (Finder launch), open the log to help non-technical users.
  if [[ ! -t 2 ]] && command -v open >/dev/null 2>&1; then
    /usr/bin/open -a TextEdit "$log_file" >/dev/null 2>&1 || true
  fi
}

# This LOGOComfort distribution ships Intel-only native libraries (JavaFX + serial),
# so on Apple Silicon it must run under Rosetta with an Intel (x86_64) Java 11+.
if ! /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
  alert "Rosetta is not installed. Install it with:\n  softwareupdate --install-rosetta --agree-to-license"
  exit 1
fi

java_home_x86_64="${LOGOCOMFORT_JAVA_HOME:-}"
if [[ -z "${java_home_x86_64}" ]]; then
  java_home_x86_64="$(
    /usr/libexec/java_home -F --arch x86_64 -v 11 2>/dev/null || true
  )"
fi

if [[ -z "${java_home_x86_64}" ]]; then
  java_home_x86_64="$(
    /usr/libexec/java_home -F --arch x86_64 2>/dev/null || true
  )"
fi

if [[ -z "${java_home_x86_64}" ]]; then
  alert "LOGOComfort needs an Intel (x86_64) Java 11+ runtime on Apple Silicon.\n\nReason: this app bundle includes Intel-only native libraries under:\n  lib/javafx/lib/*.dylib\n  bin/librxtxSerial.jnilib\n\nFix:\n  1) Install a macOS x86_64 JDK/JRE 11+\n  2) Re-run LOGOComfort\n\nTip: verify macOS can see it with:\n  /usr/libexec/java_home -V --arch x86_64"
  exit 1
fi

echo "java_home_x86_64: $java_home_x86_64"

java_bin="$java_home_x86_64/bin/java"
if [[ ! -x "$java_bin" ]]; then
  die "Found JAVA_HOME ($java_home_x86_64) but $java_bin is missing or not executable."
fi

echo "java_bin: $java_bin"

if ! /usr/bin/arch -x86_64 "$java_bin" -version >/dev/null 2>&1; then
  alert "The configured Java at:\n  $java_bin\nis not runnable as Intel (x86_64).\n\nInstall an Intel (x86_64) JDK 11+, or set LOGOCOMFORT_JAVA_HOME to one."
  exit 1
fi

spec_version="$(
  /usr/bin/arch -x86_64 "$java_bin" -XshowSettings:properties -version 2>&1 |
    /usr/bin/awk -F' = ' '/^[[:space:]]*java[.]specification[.]version[[:space:]]*=/{print $2; exit}'
)"
spec_version="${spec_version//[[:space:]]/}"
java_major=""
if [[ -n "${spec_version}" ]]; then
  if [[ "${spec_version}" == 1.* ]]; then
    java_major="${spec_version#1.}"
    java_major="${java_major%%.*}"
  else
    java_major="${spec_version%%.*}"
  fi
fi

echo "java.specification.version: ${spec_version:-unknown}"
echo "java_major: ${java_major:-unknown}"

if [[ -z "${java_major}" ]] || [[ "${java_major}" -lt 11 ]]; then
  alert "LOGOComfort needs an Intel (x86_64) Java 11+ runtime on Apple Silicon.\n\nDetected Java:\n  ${java_bin}\n  java.specification.version=${spec_version:-unknown}\n\nFix:\n  - Install a macOS x86_64 JDK/JRE 11+ (Temurin/Adoptium or Azul Zulu x64)\n  - Or set LOGOCOMFORT_JAVA_HOME to a x86_64 JDK 11+ folder"
  exit 1
fi

classpath=".:lib/*:lib/cloud/8.4.0.1/*:LOGOComfort.app/Contents/Resources/Java/lax.jar:LOGOComfort.app/Contents/Resources/Java/linking.zip"

exec arch -x86_64 "$java_bin" \
  -Xms128M \
  -Xmx768M \
  -Xss7m \
  -Djava.library.path="bin:lib/javafx/lib" \
  -Dsun.java2d.uiScale.enabled=false \
  --module-path "lib/javafx/lib" \
  --add-modules javafx.base,javafx.controls,javafx.fxml,javafx.graphics,javafx.media,javafx.swing,javafx.web \
  -cp "$classpath" \
  Start \
  "$@"
LAUNCHER

/bin/chmod +x "${exe_path}"

echo ""
echo "Done."
echo "You can now open LOGOComfort normally."
echo "If something still fails, check:"
echo "  /tmp/LOGOComfort-launch.log"

