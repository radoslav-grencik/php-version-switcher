#!/usr/bin/env zsh

# PHP Version Switcher (PVS) Plugin for Oh My Zsh
# Automatically switches PHP versions based on .php-version files
# Uses PATH manipulation for user-level version management

PVS_CURRENT_VERSION=""
PVS_LAST_CHECKED_DIR=""
PVS_ORIGINAL_PATH=""
PVS_INSTALL_COMMAND="sudo apt install"

# Plugin configuration - can be overridden by environment variables
PVS_VERSION_FILE="${PVS_VERSION_FILE:-.php-version}"
PVS_BIN_DIR="${PVS_BIN_DIR:-${HOME}/.local/bin/pvs}"
PVS_PHP_INSTALL_PATH="${PVS_PHP_INSTALL_PATH:-/usr/bin}"
PVS_AUTO_SWITCH="${PVS_AUTO_SWITCH:-true}"
PVS_QUIET_MODE="${PVS_QUIET_MODE:-false}"

# Color codes for output
PVS_COLOR_SUCCESS="\033[0;32m"
PVS_COLOR_ERROR="\033[0;31m"
PVS_COLOR_WARNING="\033[0;33m"
PVS_COLOR_INFO="\033[0;36m"
PVS_COLOR_RESET="\033[0m"

# Logging function
pvs_log() {
  # Skip logging in quiet mode unless it's an error
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

# Store original PATH on first load
pvs_store_original_path() {
  if [[ -z "$PVS_ORIGINAL_PATH" ]]; then
    PVS_ORIGINAL_PATH="$PATH"
  fi
}

# Get current PHP version
pvs_get_current_version() {
  if command -v php >/dev/null 2>&1; then
    php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;"
  else
    echo "none"
  fi
}

# Get all available PHP versions
pvs_get_available_versions() {
  local versions=()
  for php_bin in ${PVS_PHP_INSTALL_PATH}/php[0-9]*; do
    if [[ -x "$php_bin" ]]; then
      local version=$(echo "$php_bin" | grep -oP 'php\K[0-9]+\.[0-9]+')
      if [[ -n "$version" ]]; then
        versions+=("$version")
      fi
    fi
  done
  echo "${versions[@]}" | tr ' ' '\n' | sort -V | tr '\n' ' '
}

# Get newest available PHP version
pvs_get_newest_version() {
  local versions=($(pvs_get_available_versions))
  if [[ ${#versions[@]} -gt 0 ]]; then
    echo "${versions[-1]}"
  else
    echo ""
  fi
}

# Check if PHP version is installed
pvs_is_version_installed() {
  local version=$1
  [[ -x "${PVS_PHP_INSTALL_PATH}/php$version" ]]
}

# Create a temporary directory for PHP version links
pvs_get_php_bin_dir() {
  echo "$PVS_BIN_DIR"
}

# Setup PHP version in PATH
pvs_setup_php_path() {
  local version=$1
  local php_bin_dir=$(pvs_get_php_bin_dir)

  # Create directory if it doesn't exist
  mkdir -p "$php_bin_dir"

  # Remove old php symlink
  rm -f "$php_bin_dir/php"

  # Create new symlink
  ln -sf "${PVS_PHP_INSTALL_PATH}/php$version" "$php_bin_dir/php"

  # Update PATH to include our bin directory first
  export PATH="$php_bin_dir:$PVS_ORIGINAL_PATH"
}

# Switch to specific PHP version
pvs_switch_to_version() {
  local version=$1

  if [[ -z "$version" ]]; then
    pvs_log "error" "No version specified"
    return 1
  fi

  # Check if version is installed
  if ! pvs_is_version_installed "$version"; then
    pvs_log "error" "PHP $version is not installed at ${PVS_PHP_INSTALL_PATH}/php$version"
    pvs_log "info" "Install it with: $PVS_INSTALL_COMMAND php$version"
    return 1
  fi

  # Setup PATH for this version
  pvs_setup_php_path "$version"

  # Verify the switch was successful
  local new_version=$(pvs_get_current_version)
  if [[ "$new_version" == "$version" ]]; then
    PVS_CURRENT_VERSION="$version"
    pvs_log "success" "Switched to PHP $version"
    return 0
  else
    pvs_log "error" "Failed to switch to PHP $version (got $new_version)"
    return 1
  fi
}

# Find .php-version file in current directory or parent directories
pvs_find_version_file() {
  local dir="$PWD"

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/$PVS_VERSION_FILE" ]]; then
      echo "$dir/$PVS_VERSION_FILE"
      return 0
    fi
    dir=$(dirname "$dir")
  done

  return 1
}

# Read version from .php-version file
pvs_read_version_file() {
  local version_file=$1

  if [[ -f "$version_file" ]]; then
    local version=$(cat "$version_file" | grep -oP '^[0-9]+\.[0-9]+' | head -1)
    if [[ -n "$version" ]]; then
      echo "$version"
      return 0
    fi
  fi

  return 1
}

# Main function to handle version switching
pvs_handle_version_switch() {
  local target_version=""
  local version_file=""
  local should_log=false

  # Try to find .php-version file
  version_file=$(pvs_find_version_file)

  if [[ -n "$version_file" ]]; then
    target_version=$(pvs_read_version_file "$version_file")
    if [[ -n "$target_version" ]]; then
      should_log=true
      pvs_log "info" "Found $PVS_VERSION_FILE with PHP $target_version"
    fi
  fi

  # If no version file found, check environment variable
  if [[ -z "$target_version" && -n "$PHP_DEFAULT_VERSION" ]]; then
    target_version="$PHP_DEFAULT_VERSION"
    pvs_log "info" "Using default PHP version from environment: $target_version"
    should_log=true
  fi

  # If still no version, use newest available (silently)
  if [[ -z "$target_version" ]]; then
    target_version=$(pvs_get_newest_version)
  fi

  # If we have a target version, switch to it
  if [[ -n "$target_version" ]]; then
    local current_version=$(pvs_get_current_version)
    if [[ "$current_version" != "$target_version" ]]; then
      pvs_switch_to_version "$target_version"
    elif [[ "$should_log" == "true" ]]; then
      pvs_log "info" "Already using PHP $current_version"
    fi
  else
    pvs_log "warning" "No PHP versions found"
  fi
}

# Hook function for directory changes
pvs_chpwd_hook() {
  # Skip if auto-switch is disabled
  if [[ "$PVS_AUTO_SWITCH" != "true" ]]; then
    return
  fi

  # Only check if we've changed directories
  if [[ "$PWD" != "$PVS_LAST_CHECKED_DIR" ]]; then
    PVS_LAST_CHECKED_DIR="$PWD"
    pvs_handle_version_switch
  fi
}

# Utility Functions

# Manually switch to specific version
pvs_switch() {
  local version=$1

  if [[ -z "$version" ]]; then
    pvs_log "error" "Usage: pvs_switch <version>"
    pvs_log "info" "Example: pvs_switch 8.2"
    return 1
  fi

  # Validate version format
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    pvs_log "error" "Invalid version format. Use format like: 8.2"
    return 1
  fi

  pvs_switch_to_version "$version"
}

# Create .php-version file with specified version
pvs_use() {
  local version=$1

  if [[ -z "$version" ]]; then
    pvs_log "error" "Usage: pvs_use <version>"
    pvs_log "info" "Example: pvs_use 8.1"
    return 1
  fi

  # Validate version format
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
    pvs_log "error" "Invalid version format. Use format like: 8.1"
    return 1
  fi

  # Check if version is available
  if ! pvs_is_version_installed "$version"; then
    pvs_log "error" "PHP $version is not installed at ${PVS_PHP_INSTALL_PATH}/php$version"
    pvs_log "info" "Install it with: $PVS_INSTALL_COMMAND php$version"
    return 1
  fi

  # Create .php-version file
  echo "$version" >"$PVS_VERSION_FILE"
  pvs_log "success" "Created $PVS_VERSION_FILE with PHP $version"

  # Switch to the version immediately
  pvs_switch_to_version "$version"
}

# Show current status and available versions
pvs_info() {
  echo "PHP Version Switcher Status"
  echo "==========================="
  echo ""

  local current_version=$(pvs_get_current_version)
  echo "Current PHP version: $current_version"

  local current_php_path=$(which php 2>/dev/null)
  echo "Current PHP path: ${current_php_path:-"not found"}"

  echo "PHP symlinks stored in: $(pvs_get_php_bin_dir)"

  local version_file=$(pvs_find_version_file)
  if [[ -n "$version_file" ]]; then
    local file_version=$(pvs_read_version_file "$version_file")
    echo "Version file: $version_file ($file_version)"
  else
    echo "Version file: Not found"
  fi

  if [[ -n "$PHP_DEFAULT_VERSION" ]]; then
    echo "Default version (env): $PHP_DEFAULT_VERSION"
  else
    echo "Default version (env): Not set"
  fi

  echo ""
  echo "Available PHP versions:"
  local versions=($(pvs_get_available_versions))
  for version in "${versions[@]}"; do
    local php_path="${PVS_PHP_INSTALL_PATH}/php$version"
    if [[ "$version" == "$current_version" ]]; then
      echo "  * $version ($php_path)"
    else
      echo "    $version ($php_path)"
    fi
  done

  echo ""
  echo "Configuration (environment variables):"
  echo "- PVS_VERSION_FILE: $PVS_VERSION_FILE"
  echo "- PVS_BIN_DIR: $PVS_BIN_DIR"
  echo "- PVS_PHP_INSTALL_PATH: $PVS_PHP_INSTALL_PATH"
  echo "- PVS_AUTO_SWITCH: $PVS_AUTO_SWITCH"
  echo "- PVS_QUIET_MODE: $PVS_QUIET_MODE"
  echo "- PHP_DEFAULT_VERSION: ${PHP_DEFAULT_VERSION:-"not set"}"
}

# Show help
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
  echo "# PHP installation path (default: /usr/bin)"
  echo "export PVS_PHP_INSTALL_PATH='/usr/bin'"
  echo ""
  echo "# Auto-switch when changing directories (default: true)"
  echo "export PVS_AUTO_SWITCH=true"
  echo ""
  echo "# Quiet mode - less verbose output (default: false)"
  echo "export PVS_QUIET_MODE=false"
  echo ""
  echo "# Default PHP version when no .php-version file found"
  echo "export PHP_DEFAULT_VERSION=8.1"

  echo ""
  echo "Available commands:"
  echo "- pvs_switch <version> # Manually switch version"
  echo "- pvs_use <version>    # Create .php-version file and switch"
  echo "- pvs_info             # Show current status"
  echo "- pvs_help             # Show this help"
  echo ""
  echo "How it works:"
  echo "- Creates symlinks in $(pvs_get_php_bin_dir)"
  echo "- Prepends that directory to PATH"
  echo "- No system modifications required"
}

# Initialize plugin
pvs_init() {
  # Store original PATH
  pvs_store_original_path

  # Create bin directory
  mkdir -p "$(pvs_get_php_bin_dir)"

  # Add the hook to chpwd_functions if it's not already there
  if [[ ! " ${chpwd_functions[@]} " =~ " pvs_chpwd_hook " ]]; then
    chpwd_functions+=(pvs_chpwd_hook)
  fi

  # Handle initial load
  pvs_handle_version_switch
}

# Initialize the plugin
pvs_init
