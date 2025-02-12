#!/usr/bin/env bats

load '../helpers/test_helper'

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

    # Start container for stop tests
    ./start-jellyfin.sh --debug >/dev/null 2>&1
}

# Cleanup after tests
teardown() {
    # Force stop any running containers
    docker compose -f "${TEST_TEMP_DIR}/jd.yaml" down -v 2>/dev/null || true

    # Cleanup test directories
    rm -rf "${TEST_DATA}/media"
    rm -rf "${TEST_DATA}/config"
    rm -rf "${TEST_TEMP_DIR}"
}

# Test basic stop functionality
@test "stop script should stop running container" {
    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Verify container is stopped
    run docker ps --format '{{.Names}}'
    ! [[ "$output" =~ "jd_test" ]]
}

# Test stop when container is already stopped
@test "stop script should handle already stopped container" {
    # Stop container first
    docker compose -f "${TEST_TEMP_DIR}/jd.yaml" down

    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Container is already stopped" ]]
}

# Test stop when container doesn't exist
@test "stop script should handle non-existent container" {
    # Remove container first
    docker compose -f "${TEST_TEMP_DIR}/jd.yaml" down
    docker rm jd_test 2>/dev/null || true

    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Container not found" ]]
}

# Test configuration handling
@test "stop script should handle missing configuration gracefully" {
    rm "${TEST_TEMP_DIR}/.env"
    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Environment file not found" ]]
}

# Test debug output
@test "stop script should provide detailed debug output" {
    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 0 ]
    [[ "$output" =~ "=== DEBUG INFO ===" ]]
}

# Test network cleanup
@test "stop script should cleanup network resources" {
    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Check if network is removed
    run docker network ls
    ! [[ "$output" =~ "${CONTAINER_NAME}" ]]
}

# Test volume preservation
@test "stop script should preserve mounted volumes" {
    # Create test file in media directory
    touch "${TEST_TEMP_DIR}/Volumes/TestDrive/media/test.txt"

    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Verify file still exists
    [ -f "${TEST_TEMP_DIR}/Volumes/TestDrive/media/test.txt" ]
}

# Test port cleanup
@test "stop script should free up ports" {
    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Check if port is free
    run nc -z localhost 18096
    [ "$status" -eq 1 ]
}

# Test graceful shutdown
@test "stop script should perform graceful shutdown" {
    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Check container logs for graceful shutdown message
    run docker logs jd_test 2>&1
    ! [[ "$output" =~ "killed" ]]
}

# Test cleanup of temporary files
@test "stop script should cleanup temporary files" {
    # Create test temporary file
    touch "${TEST_TEMP_DIR}/jellyfin_tmp_test"

    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Verify temporary file is removed
    [ ! -f "${TEST_TEMP_DIR}/jellyfin_tmp_test" ]
}

# Test environment variable cleanup
@test "stop script should handle environment variable cleanup" {
    run ./stop-jellyfin.sh --debug
    [ "$status" -eq 0 ]

    # Verify container environment is cleaned up
    run docker inspect jd_test 2>/dev/null
    [ "$status" -eq 1 ]
}
