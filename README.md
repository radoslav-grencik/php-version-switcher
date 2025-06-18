# PHP Version Switcher (PVS)

PHP Version Switcher (PVS) Plugin for [Oh My Zsh](https://github.com/robbyrussell/oh-my-zsh). Automatically
switches PHP versions based on `.php-version` files. Uses PATH manipulation for user-level version management.

## Install

```sh
cd ~/.oh-my-zsh/custom/plugins
git clone https://github.com/radoslav-grencik/php-version-switcher.git php-version-switcher
```

Edit `~/.zshrc` to enable the plugin:

```sh
plugins=(... php-version-switcher)
```

Reload the shell.

## Usage

### Switching versions

To switch to a specific version, use `pvs_use [version]`:

```sh
pvs_use     # switch to version defined in .php-version file or default version when no .php-version file found
pvs_use 8.2 # switch to specific version
```

### Creating .php-version files

To create a `.php-version` file with a specific version, use `pvs_local <version>`:

```sh
pvs_local 8.2
```

This will create a `.php-version` file with the specified version.

### Showing current status

To show the current status, use `pvs_info`:

```sh
pvs_info
```

This will show the current PHP version, the current PHP path, and the version file.

### Showing help

To show the help, use `pvs_help`:

```sh
pvs_help
```

This will show the available commands and configuration options.

## Configuration

The plugin can be configured with environment variables. The following variables can be set:

- `PVS_VERSION_FILE`: Version file name (default: `.php-version`)
- `PVS_BIN_DIR`: Directory for PHP symlinks (default: `~/.local/bin/pvs`)
- `PVS_PHP_INSTALL_DIR`: PHP installation directory (default: `/usr/bin`)
- `PVS_AUTO_SWITCH`: Auto-switch when changing directories (default: `true`)
- `PVS_QUIET_MODE`: Quiet mode - less verbose output (default: `false`)
- `PHP_DEFAULT_VERSION`: Default PHP version when no `.php-version` file found

## License

This project is licensed under the [MIT License](LICENSE).
