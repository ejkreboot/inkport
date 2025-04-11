#!/usr/bin/env bats

setup() {
  export SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$SCRIPT_DIR/lib/tempjson.bash"
}

# Test the ensure_template_prefix function
@test "ensure_template_prefix with P prefix and portrait orientation" {
  result="$(ensure_template_prefix "TestTemplate" "portrait")"
  [ "$result" == "P TestTemplate" ]
}

@test "ensure_template_prefix with LS prefix and landscape orientation" {
  result="$(ensure_template_prefix "TestTemplate" "landscape")"
  [ "$result" == "LS TestTemplate" ]
}

@test "ensure_template_prefix with existing LS prefix" {
  result="$(ensure_template_prefix "LS ExistingTemplate" "portrait")"
  [ "$result" == "LS ExistingTemplate" ]
}

@test "ensure_template_prefix with existing P prefix" {
  result="$(ensure_template_prefix "P ExistingTemplate" "landscape")"
  [ "$result" == "P ExistingTemplate" ]
}

# Test the lookup_icon_code function
@test "lookup_icon_code with blank icon" {
  result="$(lookup_icon_code "blank")"
  [ "$result" == "blank" ]
}

@test "lookup_icon_code with missing ICONMAP_FILE" {
  ICONMAP_FILE="/nonexistent/file.json"
  result="$(lookup_icon_code "someIcon")"
  [ "$result" == "someIcon" ]
}

@test "lookup_icon_code with known icon" {
  ICONMAP_FILE="./test_iconmap.json"
  echo '{"someIcon": "U+0041"}' > "$ICONMAP_FILE"
  result="$(lookup_icon_code "someIcon")"
  [ "$result" == "A" ]
}

@test "lookup_icon_code with unknown icon" {
  ICONMAP_FILE="./test_iconmap.json"
  echo '{"someIcon": "U+0041"}' > "$ICONMAP_FILE"
  result="$(lookup_icon_code "unknownIcon")"
  [ "$result" == "unknownIcon" ]
}

@test "lookup_icon_code with malformed Unicode value" {
  ICONMAP_FILE="./test_iconmap.json"
  echo '{"someIcon": "U+INVALID"}' > "$ICONMAP_FILE"
  result="$(lookup_icon_code "someIcon")"
  [ "$result" == "U+INVALID" ]
}

# Test the generate_json_patch function
@test "generate_json_patch produces valid JSON" {
  local patch_json
  patch_json=$(generate_json_patch "Template1" "DisplayName1" "portrait" "someIcon" '["category1", "category2"]')
  
  # Check if the output is a valid JSON object
  echo "$patch_json" | jq . > /dev/null
  [ $? -eq 0 ]
}

@test "generate_json_patch with empty categories" {
  local patch_json
  patch_json=$(generate_json_patch "Template1" "DisplayName1" "landscape" "someIcon" '[]')

  echo "$patch_json" | jq . > /dev/null
  [ $? -eq 0 ]
}

# Test the append_to_templates_json function
@test "append_to_templates_json adds a new template" {
  local patch_json
  patch_json=$(generate_json_patch "Template1" "DisplayName1" "portrait" "someIcon" '["category1"]')

  echo '{"templates": []}' > temp.json
  append_to_templates_json "$patch_json" "temp.json"

  # Verify the template was added
  result=$(jq '.templates | length' temp.json)
  [ "$result" -eq 1 ]
}

@test "append_to_templates_json fails when resulting JSON is invalid" {
  echo '{"templates": []}' > temp.json
  # Create an invalid patch
  invalid_patch='{"name": "InvalidTemplate", "filename": "invalid.json", "iconCode": "icon", "categories":}'
  
  run append_to_templates_json "$invalid_patch" "temp.json"
  [ "$status" -eq 1 ]
}
