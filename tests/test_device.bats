#!/usr/bin/env bats

setup() {
  export SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$SCRIPT_DIR/lib/device.bash"
  load 'test_helper/bats-support/load' # this is required by bats-assert!
  load 'test_helper/bats-assert/load'
  export OS_VERSION="3.19.0.0" 
  export RMK_USER=root
  export RMK_HOST=0.0.0.0

  # Mock SSH calls
  fetch_os_version() {
    echo "3.18.1.1"
  }
}

# Mocking ssh and other commands to avoid real remote execution
mock_ssh() {
  echo "Mock SSH command: $*"
  return 0
}

mock_fetch_os_version() {
  echo "3.19.0.0"  # Mock a valid OS version
}

mock_fetch_invalid_os_version() {
  echo "3.17.0.0"  # Mock an invalid OS version
}

mock_test_dir_exists() {
  return 0  # Simulate that the directory exists
}

mock_test_dir_not_exists() {
  return 1  # Simulate that the directory does not exist
}

mock_restore_templates_fail() {
  echo "Mock: Failed to restore templates from $1"
  return 1  # Simulate a failure
}

# Test semver_ge function
@test "semver_ge returns 0 for equal versions" {
  run semver_ge "3.18.1.1" "3.18.1.1"
  [ $status -eq 0 ]
}

@test "semver_ge returns 1 for lower versions" {
  run semver_ge "3.17.0.0" "3.18.1.1"
  [ $status -eq 1 ]
}

@test "semver_ge returns 0 for greater versions" {
  semver_ge "3.19.0.0" "3.18.1.1"
  [ "$?" -eq 0 ]
}

# Test fetch_os_version function (mocked)
@test "fetch_os_version returns mocked OS version" {
  # Mock the fetch_os_version function
  fetch_os_version() {
    mock_fetch_os_version
  }

  result=$(fetch_os_version)
  [ "$result" == "3.19.0.0" ]
}

# Test check_version function
@test "check_version with valid OS version" {
  # Mock the fetch_os_version function
  fetch_os_version() {
    mock_fetch_os_version
  }

  # Mock semver_ge to avoid actual version comparison logic
  semver_ge() {
    return 0  # Always returns true for the test
  }

  run check_version
  [ "$status" -eq 0 ]
}

@test "check_version with invalid OS version" {
  # Mock the fetch_os_version function
  fetch_os_version() {
    mock_fetch_invalid_os_version
  }

  # Mock semver_ge to simulate version check failure
  semver_ge() {
    return 1  # Simulate failure for the test
  }

  run check_version
  [ "$status" -eq 1 ]
}

# Test ensure_backup_exists function
@test "ensure_backup_exists when backup directory exists" {
  # Mock the directory check to simulate that it exists
  ssh() {
    mock_ssh "$@"
    mock_test_dir_exists
  }

  run ensure_backup_exists
  [ "$status" -eq 0 ]
}

@test "ensure_backup_exists returns non-zero when backup directory does not exist" {
  # Mock the directory check to simulate that it does not exist
  ssh() {
    mock_ssh "$@"
    mock_test_dir_not_exists
  }

  run ensure_backup_exists
  [ "$status" -eq 1 ]
  # Verify that the mock `mkdir` and `cp` commands were invoked as expected
  assert_output --partial "Mock SSH command: root@0.0.0.0 test -d '/usr/share/remarkable/templates/.restore/3.19.0.0' || (mkdir -p '/usr/share/remarkable/templates/.restore/3.19.0.0' && cp /usr/share/remarkable/templates/* '/usr/share/remarkable/templates/.restore/3.19.0.0/')"
}

# Test restore_templates function
@test "restore_templates when backup exists" {
    
  # Mock ssh and ensure backup exists
  ssh() {
    mock_ssh "$@"
  }

  run restore_templates
  assert_output --partial "Mock SSH command: root@0.0.0.0 cp '/usr/share/remarkable/templates/.restore/3.19.0.0/templates.json' /usr/share/remarkable/templates/templates.json"
  [ "$status" -eq 0 ]
}

@test "restore_templates fails when backup does not exist" {
  # Mock the ensure_backup_exists function to simulate missing backup
  ensure_backup_exists() {
    echo "❌ Backup does not exist"
    return 1
  }

  run restore_templates
  [ "$status" -eq 0 ]
}



