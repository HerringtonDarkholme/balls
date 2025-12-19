#!/usr/bin/env bash
#
# Bash on Balls - Model Store
#
# Provides flat-file storage (CSV/JSON) with CRUD operations
# Compatible with bash 3.2
#

# Model configuration
MODEL_DB_PATH="${APP_PATH:-./}/db"
MODEL_BACKEND="${DB_BACKEND:-csv}"

# Current model state for validation
MODEL_ERRORS=""
MODEL_VALID=true

# Initialize database directory
init_db() {
    mkdir -p "$MODEL_DB_PATH"
}

# Get path to model's data file
model_file() {
    local model="$1"
    echo "${MODEL_DB_PATH}/${model}.csv"
}

# Get path to model's counter file (for auto-increment)
counter_file() {
    local model="$1"
    echo "${MODEL_DB_PATH}/${model}.counter"
}

# Get next ID for a model
next_id() {
    local model="$1"
    local counter_path=$(counter_file "$model")
    
    local current_id=0
    if [[ -f "$counter_path" ]]; then
        current_id=$(cat "$counter_path")
    fi
    
    local next=$((current_id + 1))
    echo "$next" > "$counter_path"
    echo "$next"
}

# Get current ID without incrementing
current_id() {
    local model="$1"
    local counter_path=$(counter_file "$model")
    
    if [[ -f "$counter_path" ]]; then
        cat "$counter_path"
    else
        echo "0"
    fi
}

# Escape CSV field (handle commas and quotes)
csv_escape() {
    local value="$1"
    # If value contains comma, quote, or newline, wrap in quotes
    if [[ "$value" == *","* || "$value" == *'"'* || "$value" == *$'\n'* ]]; then
        # Double any existing quotes
        value="${value//\"/\"\"}"
        # Wrap in quotes
        value="\"$value\""
    fi
    echo "$value"
}

# Unescape CSV field
csv_unescape() {
    local value="$1"
    # Remove surrounding quotes if present
    if [[ "$value" == \"*\" ]]; then
        value="${value#\"}"
        value="${value%\"}"
        # Unescape doubled quotes
        value="${value//\"\"/\"}"
    fi
    echo "$value"
}

# Get field names for a model (from CSV header)
model_fields() {
    local model="$1"
    local file=$(model_file "$model")
    
    if [[ -f "$file" ]]; then
        head -1 "$file"
    else
        echo "id"
    fi
}

# Initialize model file with header
init_model() {
    local model="$1"
    shift
    local fields=("id" "$@")
    
    init_db
    local file=$(model_file "$model")
    
    if [[ ! -f "$file" ]]; then
        # Create CSV header
        local header=""
        for field in "${fields[@]}"; do
            [[ -n "$header" ]] && header+=","
            header+="$field"
        done
        echo "$header" > "$file"
    fi
}

# Get all records for a model
# Returns records as lines with fields separated by |
model_all() {
    local model="$1"
    local file=$(model_file "$model")
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Read header to get field names
    local header
    header=$(head -1 "$file")
    
    # Skip header and output data
    tail -n +2 "$file" | while IFS= read -r line; do
        [[ -n "$line" ]] && echo "$line"
    done
}

# Find a record by ID
# Sets RECORD_* variables with field values
model_find() {
    local model="$1"
    local id="$2"
    local file=$(model_file "$model")
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Get header to know field names
    local header
    header=$(head -1 "$file")
    
    # Split header into field names
    local OLD_IFS="$IFS"
    IFS=','
    local fields=()
    for field in $header; do
        fields+=("$field")
    done
    IFS="$OLD_IFS"
    
    # Search for record with matching ID (first field)
    local found=false
    tail -n +2 "$file" | while IFS= read -r line; do
        # Get first field (ID)
        local line_id="${line%%,*}"
        line_id=$(csv_unescape "$line_id")
        
        if [[ "$line_id" == "$id" ]]; then
            echo "$line"
            return 0
        fi
    done
    
    return 1
}

# Parse a CSV line into RECORD_* variables
parse_record() {
    local model="$1"
    local line="$2"
    local file=$(model_file "$model")
    
    # Get header
    local header
    header=$(head -1 "$file")
    
    # Parse header fields
    local OLD_IFS="$IFS"
    IFS=','
    local fields=()
    for field in $header; do
        fields+=("$field")
    done
    IFS="$OLD_IFS"
    
    # Parse line values (simple CSV parsing)
    local values=()
    local remaining="$line"
    local in_quotes=false
    local current=""
    
    while [[ -n "$remaining" || -n "$current" ]]; do
        if [[ -z "$remaining" ]]; then
            values+=("$current")
            break
        fi
        
        local char="${remaining:0:1}"
        remaining="${remaining:1}"
        
        if [[ "$char" == '"' ]]; then
            if $in_quotes; then
                # Check for escaped quote
                if [[ "${remaining:0:1}" == '"' ]]; then
                    current+='"'
                    remaining="${remaining:1}"
                else
                    in_quotes=false
                fi
            else
                in_quotes=true
            fi
        elif [[ "$char" == ',' ]] && ! $in_quotes; then
            values+=("$current")
            current=""
        else
            current+="$char"
        fi
    done
    
    # Set RECORD_* variables
    local i=0
    for field in "${fields[@]}"; do
        local value="${values[$i]:-}"
        eval "export RECORD_${field}=\"\$value\""
        eval "export ${field}=\"\$value\""
        ((i++))
    done
}

# Create a new record
# Usage: model_create "posts" "title=Hello" "body=World"
model_create() {
    local model="$1"
    shift
    local file=$(model_file "$model")
    
    init_db
    
    # Get header / initialize file
    if [[ ! -f "$file" ]]; then
        # Build header from params
        local header="id"
        for param in "$@"; do
            local field="${param%%=*}"
            header+=",$field"
        done
        echo "$header" > "$file"
    fi
    
    local header
    header=$(head -1 "$file")
    
    # Get field names
    local OLD_IFS="$IFS"
    IFS=','
    local fields=()
    for field in $header; do
        fields+=("$field")
    done
    IFS="$OLD_IFS"
    
    # Generate new ID
    local new_id=$(next_id "$model")
    
    # Build record values
    local record="$new_id"
    
    for field in "${fields[@]:1}"; do  # Skip 'id' field
        local value=""
        # Find value from params
        for param in "$@"; do
            local p_field="${param%%=*}"
            local p_value="${param#*=}"
            if [[ "$p_field" == "$field" ]]; then
                value="$p_value"
                break
            fi
        done
        # Escape and append
        record+=",$(csv_escape "$value")"
    done
    
    # Run before_save hook if defined
    local hook_func="before_save_${model%s}"  # posts -> post
    if type "$hook_func" &>/dev/null; then
        # Set field variables for hook
        for param in "$@"; do
            local p_field="${param%%=*}"
            local p_value="${param#*=}"
            eval "export ${p_field}=\"\$p_value\""
        done
        export id="$new_id"
        
        "$hook_func"
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi
    
    # Run validation if defined
    local validate_func="validate_${model%s}"
    if type "$validate_func" &>/dev/null; then
        MODEL_ERRORS=$("$validate_func")
        if [[ -n "$MODEL_ERRORS" ]]; then
            MODEL_VALID=false
            return 1
        fi
    fi
    
    # Append record to file
    echo "$record" >> "$file"
    
    # Run after_save hook if defined
    local after_hook="after_save_${model%s}"
    if type "$after_hook" &>/dev/null; then
        "$after_hook"
    fi
    
    echo "$new_id"
    return 0
}

# Update a record by ID
# Usage: model_update "posts" "1" "title=Updated"
model_update() {
    local model="$1"
    local id="$2"
    shift 2
    local file=$(model_file "$model")
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Get header
    local header
    header=$(head -1 "$file")
    
    # Get field names
    local OLD_IFS="$IFS"
    IFS=','
    local fields=()
    for field in $header; do
        fields+=("$field")
    done
    IFS="$OLD_IFS"
    
    # Create temp file
    local tmp_file=$(mktemp)
    echo "$header" > "$tmp_file"
    
    local found=false
    
    # Process each record
    tail -n +2 "$file" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        # Get record ID
        local line_id="${line%%,*}"
        line_id=$(csv_unescape "$line_id")
        
        if [[ "$line_id" == "$id" ]]; then
            found=true
            
            # Parse existing record
            parse_record "$model" "$line"
            
            # Update fields from params
            for param in "$@"; do
                local p_field="${param%%=*}"
                local p_value="${param#*=}"
                eval "export ${p_field}=\"\$p_value\""
            done
            
            # Run before_save hook
            local hook_func="before_save_${model%s}"
            if type "$hook_func" &>/dev/null; then
                "$hook_func"
            fi
            
            # Run validation
            local validate_func="validate_${model%s}"
            if type "$validate_func" &>/dev/null; then
                MODEL_ERRORS=$("$validate_func")
                if [[ -n "$MODEL_ERRORS" ]]; then
                    MODEL_VALID=false
                    # Keep original line
                    echo "$line" >> "$tmp_file"
                    continue
                fi
            fi
            
            # Build updated record
            local updated="$id"
            for field in "${fields[@]:1}"; do
                eval "local value=\"\${$field}\""
                updated+=",$(csv_escape "$value")"
            done
            echo "$updated" >> "$tmp_file"
            
            # Run after_save hook
            local after_hook="after_save_${model%s}"
            if type "$after_hook" &>/dev/null; then
                "$after_hook"
            fi
        else
            echo "$line" >> "$tmp_file"
        fi
    done
    
    # Replace original file
    mv "$tmp_file" "$file"
    
    return 0
}

# Delete a record by ID
# Usage: model_destroy "posts" "1"
model_destroy() {
    local model="$1"
    local id="$2"
    local file=$(model_file "$model")
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Get header
    local header
    header=$(head -1 "$file")
    
    # Create temp file
    local tmp_file=$(mktemp)
    echo "$header" > "$tmp_file"
    
    local found=false
    
    # Copy all records except the one to delete
    tail -n +2 "$file" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local line_id="${line%%,*}"
        line_id=$(csv_unescape "$line_id")
        
        if [[ "$line_id" == "$id" ]]; then
            found=true
            # Run before_destroy hook if defined
            local hook_func="before_destroy_${model%s}"
            if type "$hook_func" &>/dev/null; then
                parse_record "$model" "$line"
                "$hook_func"
            fi
            # Don't include this line
        else
            echo "$line" >> "$tmp_file"
        fi
    done
    
    mv "$tmp_file" "$file"
    return 0
}

# Count records in a model
model_count() {
    local model="$1"
    local file=$(model_file "$model")
    
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    
    # Count lines minus header
    local total=$(wc -l < "$file")
    echo $((total - 1))
}

# Find records by field value
# Usage: model_where "posts" "author=John"
model_where() {
    local model="$1"
    local condition="$2"
    local file=$(model_file "$model")
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local search_field="${condition%%=*}"
    local search_value="${condition#*=}"
    
    # Get header to find field index
    local header
    header=$(head -1 "$file")
    
    local OLD_IFS="$IFS"
    IFS=','
    local fields=()
    local field_index=-1
    local i=0
    for field in $header; do
        fields+=("$field")
        if [[ "$field" == "$search_field" ]]; then
            field_index=$i
        fi
        ((i++))
    done
    IFS="$OLD_IFS"
    
    if [[ $field_index -eq -1 ]]; then
        return 1
    fi
    
    # Search records
    tail -n +2 "$file" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        parse_record "$model" "$line"
        eval "local value=\"\${$search_field}\""
        
        if [[ "$value" == "$search_value" ]]; then
            echo "$line"
        fi
    done
}

# Validate presence of a field
validate_presence() {
    local field="$1"
    eval "local value=\"\${$field}\""
    
    if [[ -z "$value" ]]; then
        echo "${field} can't be blank"
        return 1
    fi
    return 0
}

# Validate minimum length
validate_length_min() {
    local field="$1"
    local min="$2"
    eval "local value=\"\${$field}\""
    
    if [[ ${#value} -lt $min ]]; then
        echo "${field} must be at least ${min} characters"
        return 1
    fi
    return 0
}

# Validate maximum length
validate_length_max() {
    local field="$1"
    local max="$2"
    eval "local value=\"\${$field}\""
    
    if [[ ${#value} -gt $max ]]; then
        echo "${field} must be at most ${max} characters"
        return 1
    fi
    return 0
}

# Get validation errors
model_errors() {
    echo "$MODEL_ERRORS"
}

# Check if model is valid
model_valid() {
    $MODEL_VALID
}

# Reset validation state
reset_validation() {
    MODEL_ERRORS=""
    MODEL_VALID=true
}
