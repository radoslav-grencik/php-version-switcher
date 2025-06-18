#!/usr/bin/env zsh

# PHP Version Switcher (PVS) Plugin for Oh My Zsh
# Automatically switches PHP versions based on .php-version files
# Uses PATH manipulation for user-level version management

PVS_LAST_CHECKED_DIR=""
PVS_INSTALL_COMMAND="sudo apt install"

PVS_VERSION_FILE="${PVS_VERSION_FILE:-.php-version}"
PVS_BIN_DIR="${PVS_BIN_DIR:-${HOME}/.local/bin/pvs}"
PVS_PHP_INSTALL_DIR="${PVS_PHP_INSTALL_DIR:-/usr/bin}"
PVS_AUTO_SWITCH="${PVS_AUTO_SWITCH:-true}"
PVS_QUIET_MODE="${PVS_QUIET_MODE:-false}"

PVS_COLOR_SUCCESS="\033[0;32m"
PVS_COLOR_ERROR="\033[0;31m"
PVS_COLOR_WARNING="\033[0;33m"
PVS_COLOR_INFO="\033[0;36m"
PVS_COLOR_RESET="\033[0m"

_pvs_log() {
  if [[ "$PVS_QUIET_MODE" == "true" && "$1" != "error" ]]; then
    return
  fi

  local level=$1
  shift
  local message="$@"

  case $level in
  "success")
    echo -e "${PVS_COLOR_SUCCESS}[PVS]${PVS_COLOR_RESET} $message"
    ;;
  "error")
    echo -e "${PVS_COLOR_ERROR}[PVS ERROR]${PVS_COLOR_RESET} $message"
    ;;
  "warning")
    echo -e "${PVS_COLOR_WARNING}[PVS WARNING]${PVS_COLOR_RESET} $message"
    ;;
  "info")
    echo -e "${PVS_COLOR_INFO}[PVS]${PVS_COLOR_RESET} $message"
    ;;
  *)
    echo "[PVS] $message"
    ;;
  esac
}

# -------------------------------------------------------- #

_pvs_validate_version_format() {
  local version=$1

  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    return 1
  fi

  return 0
}

_pvs_get_available_versions() {
  local -a versions=()

  for php_bin in ${PVS_PHP_INSTALL_DIR}/php[0-9]*.[0-9]*; do
    [[ -x "$php_bin" ]] || continue

    local version=${php_bin##*/php}

    versions+=("$version")
  done

  if [[ ! ${#versions[@]} -gt 0 ]]; then
    _pvs_log "error" "No PHP versions found"

    return 1
  fi

  printf '%s\n' "${versions[@]}" | sort -V | paste -sd' '
}

_pvs_get_current_version() {
  local php_path=$(command -v php)

  if [[ -x "$php_path" ]]; then
    "$php_path" -r "echo PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION . PHP_EOL;" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

_pvs_get_default_version() {
  if [[ -n "$PHP_DEFAULT_VERSION" ]]; then
    if ! _pvs_validate_version_format "$PHP_DEFAULT_VERSION"; then
      _pvs_log "error" "Invalid PHP_DEFAULT_VERSION format. Use format like 8.2"

      return 1
    fi

    echo "$PHP_DEFAULT_VERSION"

    return 0
  fi

  local versions=($(_pvs_get_available_versions))

  if [[ ${#versions[@]} -gt 0 ]]; then
    echo "${versions[-1]}"
  else
    echo ""
  fi
}

_pvs_get_version_from_file() {
  local dir="$PWD"

  while [[ "$dir" != "/" ]]; do
    local version_file="$dir/$PVS_VERSION_FILE"

    if [[ -f "$version_file" && -r "$version_file" ]]; then
      local version=$(grep -oP '^[0-9]+\.[0-9]+' "$version_file" | head -1 | tr -d '[:space:]')

      if [[ -n "$version" ]]; then
        echo "$version $version_file"

        return 0
      else
        _pvs_log "error" "Invalid version format in $version_file. Use format like 8.2"
        return 1
      fi
    fi

    dir=${dir%/*}
    [[ -z "$dir" ]] && dir="/"
  done

  return 1
}

_pvs_update_path() {
  mkdir -p "$PVS_BIN_DIR"

  local version=$1
  local php_symlink="$PVS_BIN_DIR/php"
  local target_php="${PVS_PHP_INSTALL_DIR}/php$version"

  [[ -L "$php_symlink" ]] && rm -f "$php_symlink"

  if ! ln -sf "$target_php" "$php_symlink"; then
    _pvs_log "error" "Failed to create symlink to $target_php"

    return 1
  fi

  local clean_path=""
  local IFS=':'

  for path_entry in $PATH; do
    if [[ "$path_entry" != "$PVS_BIN_DIR" ]]; then
      clean_path+="$path_entry:"
    fi
  done

  clean_path="${clean_path%:}"

  export PATH="$PVS_BIN_DIR:$clean_path"
}

# -------------------------------------------------------- #

_pvs_switch_to_version() {
  local version=$1

  if [[ -z "$version" ]]; then
    _pvs_log "error" "No version specified"

    return 1
  fi

  if [[ ! -x "${PVS_PHP_INSTALL_DIR}/php$version" ]]; then
    _pvs_log "error" "PHP $version is not installed at ${PVS_PHP_INSTALL_DIR}/php$version"
    _pvs_log "info" "Install it with: $PVS_INSTALL_COMMAND php$version"

    return 1
  fi

  _pvs_update_path "$version"

  local current_version=$(_pvs_get_current_version)

  if [[ "$current_version" != "$version" ]]; then
    _pvs_log "error" "Failed to switch to PHP $version (got $current_version)"

    return 1
  fi

  _pvs_log "success" "Switched to PHP $version"

  return 0
}

_pvs_auto_switch_version() {
  read version version_file < <(_pvs_get_version_from_file)

  if [[ -n "$version" ]]; then
    _pvs_log "info" "Found version file: $version_file ($version)"
  fi

  if [[ -z "$version" ]]; then
    version=$(_pvs_get_default_version)
  fi

  if [[ -n "$version" ]]; then
    local current_version=$(_pvs_get_current_version)

    if [[ "$current_version" == "$version" ]]; then
      if [[ -n "$version_file" ]]; then
        _pvs_log "info" "Already using PHP $current_version"
      fi

      return 0
    fi

    _pvs_switch_to_version "$version"
  else
    _pvs_log "warning" "No PHP versions found"
  fi
}

_pvs_chpwd_hook() {
  if [[ "$PVS_AUTO_SWITCH" != "true" ]]; then
    return
  fi

  if [[ "$PWD" != "$PVS_LAST_CHECKED_DIR" ]]; then
    PVS_LAST_CHECKED_DIR="$PWD"

    _pvs_auto_switch_version
  fi
}

# ------------------- Utility functions ------------------ #

pvs_use() {
  local version=$1
  local log=""

  if [[ -n "$version" ]]; then
    log="Using PHP version: $version"
  fi

  if [[ -z "$version" ]]; then
    read version version_file < <(_pvs_get_version_from_file)

    if [[ -n "$version" ]]; then
      log="Using PHP version from: $version_file ($version)"
    fi
  fi

  if [[ -z "$version" ]]; then
    version=$(_pvs_get_default_version)

    if [[ -n "$version" ]]; then
      log="Using default PHP version: $version"
    fi
  fi

  if [[ -z "$version" ]]; then
    _pvs_log "error" "No PHP versions found"

    return 1
  fi

  if ! _pvs_validate_version_format "$version"; then
    _pvs_log "error" "Invalid version format. Use format like 8.2"

    return 1
  fi

  _pvs_log "info" "$log"

  local current_version=$(_pvs_get_current_version)

  if [[ "$current_version" == "$version" ]]; then
    _pvs_log "info" "Already using PHP $current_version"

    return 0
  fi

  _pvs_switch_to_version "$version"
}

pvs_local() {
  local version=$1

  if [[ -z "$version" ]]; then
    _pvs_log "error" "Usage: pvs_local <version>"
    _pvs_log "info" "Example: pvs_local 8.2"

    return 1
  fi

  version="${version//[[:space:]]/}"

  if ! _pvs_validate_version_format "$version"; then
    _pvs_log "error" "Invalid version format. Use format like 8.2"

    return 1
  fi

  echo "$version" >"$PVS_VERSION_FILE"

  _pvs_log "success" "Created version file: $PVS_VERSION_FILE ($version)"
}

pvs_info() {
  echo "PHP Version Switcher Info"
  echo "========================="
  echo ""

  local current_version=$(_pvs_get_current_version)
  local default_version=$(_pvs_get_default_version)
  read file_version version_file < <(_pvs_get_version_from_file)

  echo "Current PHP version: ${current_version:-"none"}"

  echo "Default PHP version: ${default_version:-"none"}"

  echo "PHP symlinks stored in: $PVS_BIN_DIR"

  if [[ -n "$file_version" ]]; then
    echo "Version file: $version_file ($file_version)"
  else
    echo "Version file: not found"
  fi

  echo ""
  echo "Available PHP versions:"

  local versions=($(_pvs_get_available_versions))

  for version in "${versions[@]}"; do
    local php_path="${PVS_PHP_INSTALL_DIR}/php$version"

    if [[ "$version" == "$current_version" ]]; then
      if [[ "$version" == $default_version ]]; then
        echo "  * $version ($php_path) (default)"
      else
        echo "  * $version ($php_path)"
      fi
    else
      if [[ "$version" == $default_version ]]; then
        echo "    $version ($php_path) (default)"
      else
        echo "    $version ($php_path)"
      fi
    fi
  done

  echo ""
  echo "Configuration (environment variables):"
  echo "- PVS_VERSION_FILE: $PVS_VERSION_FILE"
  echo "- PVS_BIN_DIR: $PVS_BIN_DIR"
  echo "- PVS_PHP_INSTALL_DIR: $PVS_PHP_INSTALL_DIR"
  echo "- PVS_AUTO_SWITCH: $PVS_AUTO_SWITCH"
  echo "- PVS_QUIET_MODE: $PVS_QUIET_MODE"
  echo "- PHP_DEFAULT_VERSION: ${PHP_DEFAULT_VERSION:-"not set (newest available version)"}"
}

pvs_help() {
  echo "PHP Version Switcher Help"
  echo "========================="
  echo ""

  echo "Environment variables for configuration:"
  echo ""
  echo "# Version file name (default: .php-version)"
  echo "export PVS_VERSION_FILE='.php-version'"
  echo ""
  echo "# Directory for PHP symlinks (default: ~/.local/bin/pvs)"
  echo "export PVS_BIN_DIR=\"\$HOME/.local/bin/pvs\""
  echo ""
  echo "# PHP installation directory (default: /usr/bin)"
  echo "export PVS_PHP_INSTALL_DIR='/usr/bin'"
  echo ""
  echo "# Auto-switch when changing directories (default: true)"
  echo "export PVS_AUTO_SWITCH=true"
  echo ""
  echo "# Quiet mode - less verbose output (default: false)"
  echo "export PVS_QUIET_MODE=false"
  echo ""
  echo "# Default PHP version when no $PVS_VERSION_FILE file found"
  echo "export PHP_DEFAULT_VERSION=8.2"

  echo ""
  echo "Available commands:"
  echo "- pvs_use [version]   # Manually switch version"
  echo "- pvs_local <version> # Create $PVS_VERSION_FILE file"
  echo "- pvs_info            # Show current status"
  echo "- pvs_help            # Show this help"
  echo ""
  echo "How it works:"
  echo "- Creates symlinks in $PVS_BIN_DIR"
  echo "- Prepends that directory to PATH"
  echo "- No system modifications required"
}

# -------------------------- Run ------------------------- #

if ! printf '%s\n' "${chpwd_functions[@]}" | grep -qFx _pvs_chpwd_hook; then
  chpwd_functions+=(_pvs_chpwd_hook)
fi

_pvs_auto_switch_version
