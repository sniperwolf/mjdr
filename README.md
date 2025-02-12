# MJDR (My Jellyfin Docker Runner)

[![Test and Coverage](https://github.com/sniperwolf/mjdr/actions/workflows/test.yml/badge.svg)](https://github.com/sniperwolf/mjdr/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/sniperwolf/mjdr/branch/main/graph/badge.svg)](https://codecov.io/gh/sniperwolf/mjdr)

MJDR is a shell-based tool designed to manage Jellyfin media server in Docker containers. It provides an
easy-to-use interface for starting, stopping, and managing your Jellyfin instance with proper error handling and system
checks.

## Features

- Cross-platform support (Linux, macOS, Windows with WSL/Git Bash)
- Automatic network detection and configuration
- System requirements verification
- Easy backup and restore functionality
- Debug mode for troubleshooting
- QR code generation for mobile access
- Comprehensive error handling
- ShellCheck compliant code

## Prerequisites

- Docker (20.10.0 or newer)
- Docker Compose V2
- Jellyfin Docker image
- Bash shell (4.0 or newer)

## Installation

1. Clone the repository:

```bash
git clone https://github.com/sniperwolf/mjdr.git
cd mjdr
```

2. Install dependencies and setup development environment:

```bash
make install
```

3. Create your ".env" file:

```bash
cp .env.example .env
```

4. Edit the ".env" file with your configuration:

```bash

# Container configuration

CONTAINER_NAME=jd
JELLYFIN_PORT=8096
JELLYFIN_HTTPS_PORT=8920
JELLYFIN_DISCOVERY_PORT=7359
JELLYFIN_DLNA_PORT=1900

# Path configuration - Unix/MacOS example

#USB_MOUNT_PATH=/Volumes/MediaDrive
#MEDIA_PATH=/Volumes/MediaDrive/media
#CONFIG_PATH=/Volumes/MediaDrive/config
#DOCKER_COMPOSE_FILE=/Users/username/mjdr/jd.yaml

# Path configuration - Windows example

USB_MOUNT_PATH=D:/MediaDrive
MEDIA_PATH=D:/MediaDrive/media
CONFIG_PATH=D:/MediaDrive/config
DOCKER_COMPOSE_FILE=C:/Users/username/mjdr/jd.yaml

# Network configuration

JELLYFIN_PUBLISHED_URL=http://localhost:8096

# Optional features

ENABLE_HTTPS=false
ENABLE_DLNA=true

```

## Usage

### Using Make Commands

The project includes a Makefile for common operations:

```bash
# Show available commands
make help

# Install dependencies
make install

# Run tests
make test

# Run specific test suites
make test-unit
make test-integration

# Run linting (ShellCheck)
make lint

# Generate coverage report
make coverage

# Start Jellyfin
make start

# Stop Jellyfin
make stop

# Start in debug mode
make debug

# Clean temporary files
make clean
```

### Manual Usage

If you prefer not to use Make, you can run the scripts directly:

### Starting Jellyfin

```bash
./start-jellyfin.sh
# or with debug mode
./start-jellyfin.sh --debug
```

### Stopping Jellyfin

```bash
./stop-jellyfin.sh
# or with debug mode
./stop-jellyfin.sh --debug
```

## Project Structure

```
mjdr/
├── libs/                   # Library modules
│   ├── colors.sh           # Color definitions and basic utilities
│   ├── docker.sh           # Docker operations
│   ├── filesystem.sh       # Filesystem operations
│   ├── network.sh          # Network detection and configuration
│   ├── os_detect.sh        # OS detection and system checks
│   └── ui.sh               # User interface functions
├── tests/                  # Test files
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   ├── fixtures/           # Test fixtures
│   └── helpers/            # Test helpers
├── start-jellyfin.sh       # Main startup script
├── stop-jellyfin.sh        # Main shutdown script
├── jd.yaml                 # Docker Compose configuration
├── .env                    # Your custom environment configuration
├── .env.example            # Example environment configuration
├── Makefile                # Make commands for common operations
└── README.md               # This file
```

## Development

### Running Tests

The project uses BATS (Bash Automated Testing System) for testing:

```bash
# Install test dependencies
make install

# Run all tests
make test

# Run specific test suites
make test-unit
make test-integration

# Generate coverage report
make coverage
```

### Adding New Shell Scripts

When adding new shell scripts, remember to make them executable and track the permission in git:

```bash
chmod +x script.sh
git add --chmod=+x script.sh
```

### Coding Standards

- All shell scripts must pass ShellCheck validation
- Follow the existing code style and documentation patterns
- Add comments for complex operations
- Update documentation when adding new features
- Write meaningful commit messages

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch ("git checkout -b feature/amazing-feature")
3. Make your changes
4. Run tests and linting:

```bash
make test
```

5. Commit your changes ("git commit -m 'feat: add amazing feature'")
6. Push to the branch ("git push origin feature/amazing-feature")
7. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Jellyfin](https://jellyfin.org/) for the amazing media server
- [ShellCheck](https://www.shellcheck.net/) for the static analysis tool
- [BATS](https://github.com/bats-core/bats-core) for the testing framework
- All contributors who help improve this project

## Support

If you encounter any problems or have suggestions, please:

1. Check the debug output using "--debug" flag
2. Check the [Issues](https://github.com/sniperwolf/mjdr/issues) page
3. Open a new issue if needed
