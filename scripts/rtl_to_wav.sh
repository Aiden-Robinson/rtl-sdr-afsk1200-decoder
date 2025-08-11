#!/bin/bash

# RTL-SDR to WAV converter script
# This script captures FM signals from RTL-SDR and converts them to WAV format

# Default values (can be overridden by command line arguments)
# Environment variables DEFAULT_FREQ and DEFAULT_SAMPLE_RATE are set in docker-compose.yml
FREQ=${1:-$DEFAULT_FREQ}
SAMPLE_RATE=${2:-$DEFAULT_SAMPLE_RATE}
DURATION=${3:-60}  # Duration in seconds
OUTPUT_DIR=${4:-"/app/output"}
OUTPUT_FILE=${5:-"rtl_capture_$(date +%Y%m%d_%H%M%S).wav"}

# Validate required environment variables
if [ -z "$FREQ" ]; then
    echo "ERROR: No frequency specified!"
    echo "Either pass frequency as first argument or ensure DEFAULT_FREQ is set in docker-compose.yml"
    exit 1
fi

if [ -z "$SAMPLE_RATE" ]; then
    echo "ERROR: No sample rate specified!"
    echo "Either pass sample rate as second argument or ensure DEFAULT_SAMPLE_RATE is set in docker-compose.yml"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Full output path
OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT_FILE"

echo "=== RTL-SDR AFSK1200 Capture Started ==="
echo "Frequency: $FREQ"
echo "Sample Rate: $SAMPLE_RATE Hz"
echo "Duration: $DURATION seconds"
echo "Output: $OUTPUT_PATH"
echo "========================================"

# Check if RTL-SDR device is available
if ! rtl_test -t; then
    echo "ERROR: No RTL-SDR device found!"
    echo "Please ensure:"
    echo "1. RTL-SDR dongle is connected"
    echo "2. Docker has USB device access"
    echo "3. Device permissions are correct"
    exit 1
fi

# Capture FM signal from RTL-SDR and convert to WAV
# -f: frequency
# -M fm: FM demodulation
# -s: sample rate for RTL-SDR
# -r: resample rate
# -g: gain (auto)
# -E dc: enable DC blocking
# -F 9: enable de-emphasis
rtl_fm -f "$FREQ" -M fm -s 48000 -r "$SAMPLE_RATE" -g auto -E dc -F 9 - | \
sox -t raw -r "$SAMPLE_RATE" -e signed -b 16 -c 1 - "$OUTPUT_PATH" trim 0 "$DURATION"

if [ $? -eq 0 ]; then
    echo "SUCCESS: Audio captured to $OUTPUT_PATH"
    echo "File size: $(du -h "$OUTPUT_PATH" | cut -f1)"
    echo "Duration: $(soxi -D "$OUTPUT_PATH" 2>/dev/null || echo "unknown") seconds"
else
    echo "ERROR: Failed to capture audio"
    exit 1
fi
