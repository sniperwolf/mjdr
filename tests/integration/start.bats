#!/usr/bin/env bats

# Determine helper path
if [[ -z "${BATS_HELPER_PATH:-}" ]]; then
    # When running locally
    BATS_HELPER_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")/../helpers" && pwd)"
fi

# Setup test environment
setup() {
    TEST_ROOT="${BATS_TEST_DIRNAME}/.."
    TEST_DATA="${TEST_ROOT}/fixtures"
    export TEST_TEMP_DIR="$(mktemp -d)"

    # Create test environment structure
    mkdir -p "${TEST_DATA}/media"
    mkdir -p "${TEST_DATA}/config"
    mkdir -p "${TEST_TEMP_DIR}/Volumes/TestDrive"

    # Create test environment file
    cat > "${TEST_TEMP_DIR}/.env" <<EOF
CONTAINER_NAME=jd_test
JELLYFIN_PORT=18096
JELLYFIN_HTTPS_PORT=18920
JELLYFIN_DISCOVERY_PORT=17359
JELLYFIN_DLNA_PORT=11900
USB_MOUNT_PATH=${TEST_TEMP_DIR}/Volumes/TestDrive
MEDIA_PATH=${TEST_TEMP_DIR}/Volumes/TestDrive/media
CONFIG_PATH=${TEST_TEMP_DIR}/Volumes/TestDrive/config
DOCKER_COMPOSE_FILE=${TEST_TEMP_DIR}/jd.yaml
JELLYFIN_PUBLISHED_URL=http://localhost:18096
ENABLE_HTTPS=false
ENABLE_DLNA=true
DEBUG=true
EOF

    # Create test docker-compose file
    cat > "${TEST_TEMP_DIR}/jd.yaml" <<EOF
services:
  jd:
    image: jellyfin/jellyfin:latest
    container_name: \${CONTAINER_NAME}
    volumes:
      - \${MEDIA_PATH}:/media
      - \${CONFIG_PATH}:/config
    ports:
      - \${JELLYFIN_PORT}:8096
      - \${JELLYFIN_HTTPS_PORT}:8920
      - \${JELLYFIN_DISCOVERY_PORT}:7359/udp
      - \${JELLYFIN_DLNA_PORT}:1900/udp
    environment:
      - JELLYFIN_PublishedServerUrl=\${JELLYFIN_PUBLISHED_URL}
    restart: "no"
EOF

    # Export environment variables
    export ENV_FILE="${TEST_TEMP_DIR}/.env"
    export COMPOSE_FILE="${TEST_TEMP_DIR}/jd.yaml"
}

# Cleanup after tests
teardown() {
    # Stop any running containers
    docker compose -f "${TEST_TEMP_DIR}/jd.yaml" down -v 2>/dev/null || true

    # Cleanup test directories
    rm -rf "${TEST_DATA}/media"
    rm -rf "${TEST_DATA}/config"
    rm -rf "${TEST_TEMP_DIR}"
}

# Test full startup sequence
@test "start script should complete full startup sequence" {
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Jellyfin setup completed successfully" ]]
}

# Test directory creation
@test "start script should create required directories" {
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 0 ]
    [ -d "${TEST_TEMP_DIR}/Volumes/TestDrive/media" ]
    [ -d "${TEST_TEMP_DIR}/Volumes/TestDrive/config" ]
}

# Test container creation
@test "start script should create and start container" {
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Verify container is running
    run docker ps --format '{{.Names}}'
    [[ "$output" =~ "jd_test" ]]
}

# Test port availability
@test "start script should expose correct ports" {
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Check if port is listening
    run nc -z localhost 18096
    [ "$status" -eq 0 ]
}

# Test environment variable handling
@test "start script should properly handle environment variables" {
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Check container environment
    run docker exec jd_test env
    [[ "$output" =~ "JELLYFIN_PublishedServerUrl=http://localhost:18096" ]]
}

# Test volume mounting
@test "start script should properly mount volumes" {
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Check mounted volumes
    run docker inspect jd_test
    [[ "$output" =~ "${TEST_TEMP_DIR}/Volumes/TestDrive/media:/media" ]]
    [[ "$output" =~ "${TEST_TEMP_DIR}/Volumes/TestDrive/config:/config" ]]
}

# Test restart handling
@test "start script should handle container restart properly" {
    # First start
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Second start should prompt for restart
    echo "y" | ./start-jellyfin.sh --debug

    # Check container is still running
    run docker ps --format '{{.Names}}'
    [[ "$output" =~ "jd_test" ]]
}

# Test error handling
@test "start script should handle missing configuration gracefully" {
    rm "${TEST_TEMP_DIR}/.env"
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Environment file not found" ]]
}

# Test debug output
@test "start script should provide detailed debug output" {
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 0 ]
    [[ "$output" =~ "=== DEBUG INFO ===" ]]
    [[ "$output" =~ "Docker status:" ]]
}

# Test network detection
@test "start script should detect network interfaces" {
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Network Interfaces:" ]]
}

# Test permission handling
@test "start script should set correct permissions" {
    run ./start-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Check directory permissions
    run stat -c "%a" "${TEST_TEMP_DIR}/Volumes/TestDrive/media"
    [[ "$output" =~ "755" ]]
}
