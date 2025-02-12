#!/bin/bash

# File: libs/docker.sh
# Description: Docker management and container operations
# This file should be sourced by other scripts

# Load dependencies if not already loaded
if [ -z "$NC" ]; then
    # shellcheck source=./colors.sh
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi
if [ -z "$OS" ]; then
    # shellcheck source=./os_detect.sh
    source "$(dirname "${BASH_SOURCE[0]}")/os_detect.sh"
fi

# Docker configuration defaults
readonly DOCKER_COMPOSE_VERSION="2"
readonly DOCKER_MIN_VERSION="20.10.0"
CONTAINER_STATUS=""

# Function to check Docker installation and version
check_docker_installation() {
    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        error_print "Docker is not installed"
        return 1
    fi

    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        error_print "Docker daemon is not running"
        return 1
    fi

    # Get Docker version
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    debug_print "Docker version: ${docker_version}"

    # Compare versions
    if ! verify_version "${docker_version}" "${DOCKER_MIN_VERSION}"; then
        error_print "Docker version ${docker_version} is below minimum required version ${DOCKER_MIN_VERSION}"
        return 1
    fi

    success_print "Docker installation verified"
    return 0
}

# Function to verify version numbers
# Args: $1 - current version, $2 - minimum version
verify_version() {
    local current="$1"
    local minimum="$2"

    if [ "$(printf '%s\n' "$minimum" "$current" | sort -V | head -n1)" = "$minimum" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check Docker Compose installation
check_docker_compose() {
    # Check for Docker Compose V2 plugin
    if ! docker compose version >/dev/null 2>&1; then
        error_print "Docker Compose V2 plugin is not available"
        return 1
    fi

    success_print "Docker Compose verified"
    return 0
}

# Function to validate docker-compose.yml file
# Args: $1 - path to docker-compose file
validate_compose_file() {
    local compose_file="$1"

    if [ ! -f "$compose_file" ]; then
        error_print "Docker Compose file not found: ${compose_file}"
        return 1
    fi

    # Validate compose file
    if ! docker compose -f "$compose_file" config >/dev/null 2>&1; then
        error_print "Invalid Docker Compose file"
        return 1
    fi

    success_print "Docker Compose file validated"
    return 0
}

# Function to get container status
# Args: $1 - container name
# Returns: Container status (running, stopped, not_found)
get_container_status() {
    local container_name="$1"
    local status="not_found"

    # Check if container is running
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"; then
        status="running"
    # Check if container exists but is stopped
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"; then
        status="stopped"
    fi

    debug_print "Container status for ${container_name}: ${status}"
    CONTAINER_STATUS="$status"
    echo "$status"
    return 0
}

# Function to start container
# Args: $1 - compose file
start_container() {
    local compose_file="$1"

    debug_print "Starting container using compose file: ${compose_file}"

    if ! docker compose -f "$compose_file" up -d; then
        error_print "Failed to start container"
        return 1
    fi

    success_print "Container started successfully"
    return 0
}

# Function to stop container
# Args: $1 - compose file
stop_container() {
    local compose_file="$1"

    debug_print "Stopping container using compose file: ${compose_file}"

    if ! docker compose -f "$compose_file" down; then
        error_print "Failed to stop container"
        return 1
    fi

    success_print "Container stopped successfully"
    return 0
}

# Function to get container logs
# Args: $1 - container name, $2 - number of lines (default: 100)
get_container_logs() {
    local container_name="$1"
    local lines="${2:-100}"

    debug_print "Getting last ${lines} lines of logs for container ${container_name}"

    docker logs --tail "$lines" "$container_name" 2>&1
}

# Function to check container health
# Args: $1 - container name
check_container_health() {
    local container_name="$1"
    local health_status

    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)

    case "$health_status" in
        healthy)
            success_print "Container is healthy"
            return 0
            ;;
        unhealthy)
            error_print "Container is unhealthy"
            return 1
            ;;
        starting)
            warning_print "Container health check is still running"
            return 2
            ;;
        *)
            warning_print "Container has no health check configured"
            return 3
            ;;
    esac
}

# Function to wait for container readiness
# Args: $1 - container name, $2 - timeout in seconds (default: 60)
wait_for_container() {
    local container_name="$1"
    local timeout="${2:-60}"
    local start_time
    start_time=$(date +%s)

    while true; do
        if [ "$(($(date +%s) - start_time))" -ge "$timeout" ]; then
            error_print "Timeout waiting for container to be ready"
            return 1
        fi

        if docker logs "$container_name" 2>&1 | grep -q "Main: Startup complete"; then
            success_print "Container is ready"
            return 0
        fi

        sleep 2
    done
}

# Function to cleanup Docker resources
cleanup_docker() {
    debug_print "Cleaning up Docker resources"

    # Remove unused containers
    docker container prune -f >/dev/null 2>&1

    # Remove unused networks
    docker network prune -f >/dev/null 2>&1

    # Remove unused volumes (careful with this one)
    if [ "$DEBUG" = true ]; then
        docker volume prune -f >/dev/null 2>&1
    fi
}

# Execute check if script is sourced
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    error_print "This script should be sourced, not executed directly."
    exit 1
fi

# Export all functions and variables
export DOCKER_COMPOSE_VERSION DOCKER_MIN_VERSION CONTAINER_STATUS
export -f check_docker_installation verify_version check_docker_compose
export -f validate_compose_file get_container_status
export -f start_container stop_container get_container_logs
export -f check_container_health wait_for_container cleanup_docker
