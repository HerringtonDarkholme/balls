#!/usr/bin/env bash
#
# Unit Tests: Model Store
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../test_helper.sh"
source "$PROJECT_ROOT/lib/model.sh"

echo "Running Model Tests..."
echo ""

# Setup temp db for testing
setup_temp_dir
MODEL_DB_PATH="$TEMP_DIR/db"
mkdir -p "$MODEL_DB_PATH"

# Test: Database initialization
test_start "init_db creates db directory"
rm -rf "$MODEL_DB_PATH"
init_db
if [[ -d "$MODEL_DB_PATH" ]]; then
    test_pass
else
    test_fail
fi

# Test: Auto-increment ID
test_start "next_id returns 1 for new model"
rm -f "$MODEL_DB_PATH/posts.counter"
result=$(next_id "posts")
if [[ "$result" == "1" ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "next_id increments"
result1=$(next_id "posts")
result2=$(next_id "posts")
if [[ "$result1" == "2" ]] && [[ "$result2" == "3" ]]; then
    test_pass
else
    test_fail "Got $result1, $result2"
fi

# Test: CSV escaping
test_start "csv_escape handles commas"
result=$(csv_escape "hello,world")
if [[ "$result" == '"hello,world"' ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "csv_escape handles quotes"
result=$(csv_escape 'say "hello"')
if [[ "$result" == '"say ""hello"""' ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "csv_escape leaves simple text unchanged"
result=$(csv_escape "hello")
if [[ "$result" == "hello" ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: Model initialization
test_start "init_model creates CSV with header"
rm -f "$MODEL_DB_PATH/articles.csv"
init_model "articles" "title" "body" "author"
if [[ -f "$MODEL_DB_PATH/articles.csv" ]]; then
    header=$(head -1 "$MODEL_DB_PATH/articles.csv")
    if [[ "$header" == "id,title,body,author" ]]; then
        test_pass
    else
        test_fail "Header: $header"
    fi
else
    test_fail "File not created"
fi

# Test: Create record
test_start "model_create adds record to CSV"
rm -f "$MODEL_DB_PATH/posts.csv" "$MODEL_DB_PATH/posts.counter"
init_model "posts" "title" "body"
id=$(model_create "posts" "title=Hello" "body=World")
if [[ "$id" == "1" ]]; then
    test_pass
else
    test_fail "ID: $id"
fi

test_start "model_create stores data correctly"
content=$(cat "$MODEL_DB_PATH/posts.csv")
if [[ "$content" == *"1,Hello,World"* ]]; then
    test_pass
else
    test_fail "$content"
fi

test_start "model_create auto-increments ID"
id2=$(model_create "posts" "title=Second" "body=Post")
if [[ "$id2" == "2" ]]; then
    test_pass
else
    test_fail "ID: $id2"
fi

# Test: Read all records
test_start "model_all returns all records"
result=$(model_all "posts")
line_count=$(echo "$result" | wc -l)
if [[ $line_count -eq 2 ]]; then
    test_pass
else
    test_fail "Lines: $line_count"
fi

# Test: Find by ID
test_start "model_find returns record"
result=$(model_find "posts" "1")
if [[ "$result" == "1,Hello,World" ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "model_find returns empty for missing ID"
result=$(model_find "posts" "999")
if [[ -z "$result" ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: Parse record
test_start "parse_record sets field variables"
parse_record "posts" "1,Test Title,Test Body"
if [[ "$id" == "1" ]] && [[ "$title" == "Test Title" ]] && [[ "$body" == "Test Body" ]]; then
    test_pass
else
    test_fail "id=$id, title=$title, body=$body"
fi

test_start "parse_record handles quoted values"
# Add a record with comma
model_create "posts" "title=With, Comma" "body=Text"
result=$(model_find "posts" "3")
parse_record "posts" "$result"
if [[ "$title" == "With, Comma" ]]; then
    test_pass
else
    test_fail "title=$title"
fi

# Test: Update record
test_start "model_update modifies record"
model_update "posts" "1" "title=Updated Title"
result=$(model_find "posts" "1")
if [[ "$result" == *"Updated Title"* ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "model_update preserves other fields"
parse_record "posts" "$(model_find "posts" "1")"
if [[ "$body" == "World" ]]; then
    test_pass
else
    test_fail "body=$body"
fi

# Test: Delete record
test_start "model_destroy removes record"
count_before=$(model_count "posts")
model_destroy "posts" "2"
count_after=$(model_count "posts")
if [[ $count_after -eq $((count_before - 1)) ]]; then
    test_pass
else
    test_fail "Before: $count_before, After: $count_after"
fi

test_start "model_destroy removes correct record"
result=$(model_find "posts" "2")
if [[ -z "$result" ]]; then
    test_pass
else
    test_fail "Record still exists: $result"
fi

# Test: Count records
test_start "model_count returns correct count"
count=$(model_count "posts")
if [[ "$count" == "2" ]]; then
    test_pass
else
    test_fail "Count: $count"
fi

# Test: Find by field value
test_start "model_where finds matching records"
rm -f "$MODEL_DB_PATH/users.csv" "$MODEL_DB_PATH/users.counter"
init_model "users" "name" "role"
model_create "users" "name=Alice" "role=admin"
model_create "users" "name=Bob" "role=user"
model_create "users" "name=Carol" "role=admin"

results=$(model_where "users" "role=admin")
count=$(echo "$results" | wc -l)
if [[ $count -eq 2 ]]; then
    test_pass
else
    test_fail "Found $count records"
fi

# Test: Validation helpers
test_start "validate_presence fails for empty field"
title=""
result=$(validate_presence "title")
if [[ $? -ne 0 ]] && [[ "$result" == *"can't be blank"* ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "validate_presence passes for non-empty field"
title="Hello"
result=$(validate_presence "title")
if [[ $? -eq 0 ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "validate_length_min fails for short value"
name="Hi"
result=$(validate_length_min "name" 5)
if [[ $? -ne 0 ]]; then
    test_pass
else
    test_fail "$result"
fi

test_start "validate_length_min passes for long enough value"
name="Hello World"
result=$(validate_length_min "name" 5)
if [[ $? -eq 0 ]]; then
    test_pass
else
    test_fail "$result"
fi

# Test: Hooks
test_start "before_save hook is called"
rm -f "$MODEL_DB_PATH/hooks.csv" "$MODEL_DB_PATH/hooks.counter"
init_model "hooks" "value"
HOOK_CALLED=""
before_save_hook() {
    HOOK_CALLED="yes"
}
model_create "hooks" "value=test"
if [[ "$HOOK_CALLED" == "yes" ]]; then
    test_pass
else
    test_fail "Hook not called"
fi

# Test: Model with validation
test_start "model_create fails validation"
rm -f "$MODEL_DB_PATH/items.csv" "$MODEL_DB_PATH/items.counter"
init_model "items" "title"
# Validation function: validate_<singular> where items -> item
validate_item() {
    [[ -z "$title" ]] && echo "Title can't be blank"
}
title=""
result=$(model_create "items" "title=")
exit_code=$?
# Check that validation errors were set
if [[ -n "$MODEL_ERRORS" ]] || [[ $exit_code -ne 0 ]]; then
    test_pass
else
    test_fail "Should have failed validation (exit=$exit_code, errors=$MODEL_ERRORS)"
fi

# Cleanup
cleanup_temp_dir

test_summary
exit $?
