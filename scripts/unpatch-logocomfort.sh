#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/unpatch-logocomfort.sh "/path/to/LOGOComfort.app"
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

app_path="${app_path/#\~/$HOME}"

if [[ ! -d "${app_path}" ]]; then
  echo "Error: App not found: ${app_path}" >&2
  exit 1
fi

macos_dir="${app_path}/Contents/MacOS"
exe_path="${macos_dir}/LOGOComfort"
backup_path="${macos_dir}/LOGOComfort-launchanywhere-x86_64"

if [[ ! -e "${backup_path}" ]]; then
  echo "Error: Backup not found:" >&2
  echo "  ${backup_path}" >&2
  echo "" >&2
  echo "This app may not be patched, or the backup was removed." >&2
  exit 1
fi

echo "Restoring original launcher:"
echo "  App: ${app_path}"

if [[ -e "${exe_path}" ]]; then
  restore_backup="${exe_path}.apple-silicon-launcher.bak"
  echo "Keeping current file as:"
  echo "  ${restore_backup}"
  /bin/mv "${exe_path}" "${restore_backup}"
fi

/bin/mv "${backup_path}" "${exe_path}"
/bin/chmod +x "${exe_path}" || true

echo ""
echo "Done."
echo "LOGOComfort is restored to its original launcher."

