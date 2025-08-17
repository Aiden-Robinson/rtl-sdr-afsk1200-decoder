#!/bin/bash

# Audio file validation script
# This script checks audio files for common issues

if [ $# -lt 1 ]; then
    echo "Usage: $0 <audio_file> [additional_files...]"
    echo "Example: $0 /app/output/session_*/capture_*.wav"
    exit 1
fi

echo "=== Audio File Validation ==="
echo "Timestamp: $(date)"
echo "============================="

for AUDIO_FILE in "$@"; do
    echo ""
    echo "Checking: $AUDIO_FILE"
    echo "$(printf '=%.0s' {1..50})"
    
    if [ ! -f "$AUDIO_FILE" ]; then
        echo "✗ File does not exist: $AUDIO_FILE"
        continue
    fi
    
    # Basic file info
    FILE_SIZE=$(stat -c%s "$AUDIO_FILE" 2>/dev/null || echo "0")
    echo "File size: $FILE_SIZE bytes ($(du -h "$AUDIO_FILE" | cut -f1))"
    echo "File type: $(file "$AUDIO_FILE")"
    echo "Permissions: $(ls -l "$AUDIO_FILE" | cut -d' ' -f1)"
    echo "Owner: $(ls -l "$AUDIO_FILE" | cut -d' ' -f3-4)"
    
    # Size validation
    if [ "$FILE_SIZE" -eq 0 ]; then
        echo "✗ ERROR: File is empty"
        continue
    elif [ "$FILE_SIZE" -lt 44 ]; then
        echo "✗ ERROR: File is smaller than WAV header size"
        continue
    elif [ "$FILE_SIZE" -lt 1000 ]; then
        echo "⚠ WARNING: File is very small, likely corrupted or incomplete"
    else
        echo "✓ File size looks reasonable"
    fi
    
    # WAV format validation
    if file "$AUDIO_FILE" | grep -q "WAVE"; then
        echo "✓ Valid WAV file format detected"
    else
        echo "⚠ WARNING: File does not appear to be WAV format"
    fi
    
    # Try to read with sox
    if command -v soxi >/dev/null 2>&1; then
        echo ""
        echo "Audio properties (soxi):"
        if soxi "$AUDIO_FILE" 2>/dev/null; then
            echo "✓ File is readable by sox"
        else
            echo "✗ ERROR: File cannot be read by sox"
            echo "Sox error output:"
            soxi "$AUDIO_FILE" 2>&1 | sed 's/^/  /'
        fi
    fi
    
    # Try to read with ffprobe if available
    if command -v ffprobe >/dev/null 2>&1; then
        echo ""
        echo "Audio properties (ffprobe):"
        if ffprobe -v quiet -show_format -show_streams "$AUDIO_FILE" 2>/dev/null; then
            echo "✓ File is readable by ffprobe"
        else
            echo "⚠ File cannot be read by ffprobe"
        fi
    fi
    
    # Hex dump of first 64 bytes to check file header
    echo ""
    echo "File header (first 64 bytes):"
    hexdump -C "$AUDIO_FILE" | head -4 | sed 's/^/  /'
    
    # Check for common WAV header issues
    HEADER=$(xxd -l 12 -p "$AUDIO_FILE" 2>/dev/null)
    if [[ "$HEADER" =~ ^52494646.*57415645 ]]; then
        echo "✓ WAV file header appears correct (RIFF...WAVE)"
    else
        echo "⚠ WARNING: WAV file header may be corrupted"
        echo "  Expected: RIFF....WAVE"
        echo "  Found: $(echo "$HEADER" | fold -w 2 | tr '\n' ' ')"
    fi
    
    # Try to play a small portion to test readability
    if command -v sox >/dev/null 2>&1; then
        echo ""
        echo "Testing playback capability (converting to null):"
        if sox "$AUDIO_FILE" -n trim 0 1 2>/dev/null; then
            echo "✓ File can be processed by sox"
        else
            echo "✗ ERROR: File cannot be processed by sox"
            echo "Sox error:"
            sox "$AUDIO_FILE" -n trim 0 1 2>&1 | sed 's/^/  /'
        fi
    fi
done

echo ""
echo "=== Validation completed ==="
