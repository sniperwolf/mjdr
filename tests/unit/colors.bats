#!/usr/bin/env bats

load '../helpers/test_helper'

setup() {
    source "${BATS_TEST_DIRNAME}/../../libs/colors.sh"
}

@test "colors should be defined" {
    [ -n "$RED" ]
    [ -n "$GREEN" ]
    [ -n "$BLUE" ]
    [ -n "$YELLOW" ]
    [ -n "$NC" ]
}

@test "debug_print should respect DEBUG flag" {
    DEBUG=true
    run debug_print "test message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test message" ]]

    DEBUG=false
    run debug_print "test message"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "error_print should output error message" {
    run error_print "error message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$$ERROR$$" ]]
    [[ "$output" =~ "error message" ]]
}

@test "success_print should output success message" {
    run success_print "success message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$$SUCCESS$$" ]]
    [[ "$output" =~ "success message" ]]
}

@test "warning_print should output warning message" {
    run warning_print "warning message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$$WARNING$$" ]]
    [[ "$output" =~ "warning message" ]]
}

@test "info_print should output info message" {
    run info_print "info message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$$INFO$$" ]]
    [[ "$output" =~ "info message" ]]
}

@test "print_section_header should format correctly" {
    run print_section_header "Test Section"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "=== Test Section ===" ]]
}

@test "print_section_footer should format correctly" {
    run print_section_footer "Test Section"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "=== End of Test Section ===" ]]
}

@test "handle_error should exit with correct code" {
    run handle_error "test error" 42
    [ "$status" -eq 42 ]
    [[ "$output" =~ "test error" ]]
}

@test "validate_commands should detect missing commands" {
    run validate_commands "existing_command" "non_existing_command"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "parse_arguments should handle debug flag" {
    OLD_DEBUG="$DEBUG"
    DEBUG=false

    run parse_arguments "--debug"
    echo "Output: $output"
    echo "Status: $status"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Debug mode enabled" ]]

    DEBUG="$OLD_DEBUG"
}

@test "show_help should display help message" {
    run show_help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}
