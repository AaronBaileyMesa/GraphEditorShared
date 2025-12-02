#!/bin/bash

TARGET_DIR="/Users/handcart/Development/GraphEditor/GraphEditorShared"
OUTPUT_DIR="$HOME/Desktop/swift_context_parts"
MODEL_VARIANT="grok-4.0-heavy"

case "$MODEL_VARIANT" in
    "grok-4.1")        MAX_CHARS=7400000 ;;   # comfortably under Grok 4.1 real limit
    "grok-4.0-heavy")  MAX_CHARS=300000  ;;
    *)                 MAX_CHARS=44613   ;;
esac

echo "Exporting GraphEditorShared → $MODEL_VARIANT (max $MAX_CHARS chars/part)"
mkdir -p "$OUTPUT_DIR"
cd "$TARGET_DIR" || exit 1

# Find all .swift files
mapfile -d '' FILES < <(find . -type f -name "*.swift" -print0 | sort -z)

echo "Found ${#FILES[@]} Swift files"

common_header() {
    cat <<EOF
## GraphEditorShared – Complete Swift Source Export
Target directory: $TARGET_DIR
Generated: $(date +"%Y-%m-%d %H:%M:%S")
Model: $MODEL_VARIANT
Total files: ${#FILES[@]}

EOF
}

build_toc() {
    local n=1
    printf "Table of Contents (%d files):\n\n" "$#"
    for f in "$@"; do
        printf "%3d. %s\n" $n "${f#./}"
        ((n++))
    done
    echo
}

build_block() {
    local file="$1"
    local path="${file#./}"
    local name="$(basename "$file")"
    local modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || date -r "$file" +"%Y-%m-%d %H:%M:%S")
    cat <<EOF

--------------------------------------------------
File: $name
Path: $path
Modified: $modified

$(cat "$file")

--------------------------------------------------
EOF
}

write_part() {
    local part_num="$1"
    shift
    local batch=("$@")
    [[ ${#batch[@]} -eq 0 ]] && return

    local header=$(common_header)
    local toc=$(build_toc "${batch[@]}")
    local blocks=""
    for f in "${batch[@]}"; do
        blocks+=$(build_block "$f")
    done

    local outfile="$OUTPUT_DIR/part-$(printf "%02d" "$part_num").txt"
    printf "%s" "$header$toc$blocks" > "$outfile"
    local chars=$(wc -c < "$outfile")
    echo "→ $outfile  (${#batch[@]} files, $chars chars)"
}

# Main splitting loop – FIXED
current_batch=()
part_num=1

for file in "${FILES[@]}"; do
    current_batch+=("$file")

    # Build content to test size
    temp_header=$(common_header)
    temp_toc=$(build_toc "${current_batch[@]}")
    temp_blocks=""
    for f in "${current_batch[@]}"; do
        temp_blocks+=$(build_block "$f")
    done
    temp_content="$temp_header$temp_toc$temp_blocks"

    if (( ${#temp_content} > MAX_CHARS )); then
        # Remove the file that caused overflow
        unset 'current_batch[-1]'

        # Write the good batch
        write_part "$part_num" "${current_batch[@]}"
        ((part_num++))

        # Start new batch with the file that was too big
        current_batch=("$file")
    fi
done

# Write final batch
write_part "$part_num" "${current_batch[@]}"

echo
echo "Done! All parts are in $OUTPUT_DIR"
open "$OUTPUT_DIR"