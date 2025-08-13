#!/bin/bash

# RTL-SDR to WAV converter script
# This script captures signals from RTL-SDR and converts them to WAV format
# Supports multiple demodulation modes for digital signal exploration

# Default values (can be overridden by command line arguments)
# Environment variables DEFAULT_FREQ and DEFAULT_SAMPLE_RATE are set in docker-compose.yml
FREQ=${1:-$DEFAULT_FREQ}
DEMOD_MODE=${2:-"fm"}  # fm, lsb, usb, am, raw
SAMPLE_RATE=${3:-$DEFAULT_SAMPLE_RATE}
DURATION=${4:-60}  # Duration in seconds
OUTPUT_DIR=${5:-"/app/output"}
OUTPUT_FILE=${6:-"rtl_capture_$(date +%Y%m%d_%H%M%S).wav"}

# Convert frequency to Hz for rtl_fm
if [[ "$FREQ" =~ ^[0-9]+(\.[0-9]+)?[mM]$ ]]; then
    # MHz format
    FREQ_HZ=$(echo "$FREQ" | sed 's/[mM]$//')
    FREQ_HZ=$(awk "BEGIN {printf \"%.0f\", $FREQ_HZ * 1000000}")
elif [[ "$FREQ" =~ ^[0-9]+(\.[0-9]+)?[kK]$ ]]; then
    # kHz format  
    FREQ_HZ=$(echo "$FREQ" | sed 's/[kK]$//')
    FREQ_HZ=$(awk "BEGIN {printf \"%.0f\", $FREQ_HZ * 1000}")
else
    # Assume Hz
    FREQ_HZ=$FREQ
fi

echo "Tuning to frequency: $FREQ ($FREQ_HZ Hz)"

# Update parameter positions due to new DEMOD_MODE parameter
SAMPLE_RATE=${3:-$DEFAULT_SAMPLE_RATE}
DURATION=${4:-60}  # Duration in seconds
OUTPUT_DIR=${5:-"/app/output"}
OUTPUT_FILE=${6:-"rtl_capture_$(date +%Y%m%d_%H%M%S).wav"}

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

echo "=== RTL-SDR Digital Signal Capture Started ==="
echo "Frequency: $FREQ"
echo "Demodulation: $DEMOD_MODE"
echo "Sample Rate: $SAMPLE_RATE Hz"
echo "Duration: $DURATION seconds"
echo "Output: $OUTPUT_PATH"
echo "================================================"

# Check if RTL-SDR device is available
if ! rtl_test -t; then
    echo "ERROR: No RTL-SDR device found!"
    echo "Please ensure:"
    echo "1. RTL-SDR dongle is connected"
    echo "2. Docker has USB device access"
    echo "3. Device permissions are correct"
    exit 1
fi

# Capture signal from RTL-SDR using specified demodulation mode
case "$DEMOD_MODE" in
    "fm")
        RTL_SAMPLE_RATE=48000
        rtl_fm -f "$FREQ_HZ" -M fm -s $RTL_SAMPLE_RATE -r "$SAMPLE_RATE" -g 47 -E dc -F 9 - | \
        sox -t raw -r "$SAMPLE_RATE" -e signed -b 16 -c 1 - "$OUTPUT_PATH" trim 0 "$DURATION"
        ;;
    "lsb")
        RTL_SAMPLE_RATE=${SAMPLE_RATE}
        rtl_fm -f "$FREQ_HZ" -M lsb -s $RTL_SAMPLE_RATE -r $RTL_SAMPLE_RATE -g 47 -E dc - | \
        sox -t raw -r $RTL_SAMPLE_RATE -e signed -b 16 -c 1 - "$OUTPUT_PATH" trim 0 "$DURATION"
        ;;
    "usb")
        RTL_SAMPLE_RATE=48000
        rtl_fm -f "$FREQ_HZ" -M usb -s $RTL_SAMPLE_RATE -r "$SAMPLE_RATE" -g 47 -E dc - | \
        sox -t raw -r "$SAMPLE_RATE" -e signed -b 16 -c 1 - "$OUTPUT_PATH" trim 0 "$DURATION"
        ;;
    "am")
        RTL_SAMPLE_RATE=48000
        rtl_fm -f "$FREQ_HZ" -M am -s $RTL_SAMPLE_RATE -r "$SAMPLE_RATE" -g 47 -E dc - | \
        sox -t raw -r "$SAMPLE_RATE" -e signed -b 16 -c 1 - "$OUTPUT_PATH" trim 0 "$DURATION"
        ;;
    "raw")
        # For raw I/Q data analysis - saves as complex samples
        RAW_SAMPLE_RATE=2048000
        timeout "$DURATION" rtl_sdr -f "$FREQ_HZ" -s $RAW_SAMPLE_RATE -g 47 - | \
        sox -t raw -r $RAW_SAMPLE_RATE -e unsigned -b 8 -c 2 - "$OUTPUT_PATH" trim 0 "$DURATION"
        ;;
    *)
        echo "ERROR: Unknown demodulation mode: $DEMOD_MODE"
        echo "Supported modes: fm, lsb, usb, am, raw"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo "SUCCESS: Audio captured to $OUTPUT_PATH"
    echo "File size: $(du -h "$OUTPUT_PATH" | cut -f1)"
    echo "Duration: $(soxi -D "$OUTPUT_PATH" 2>/dev/null || echo "unknown") seconds"
else
    echo "ERROR: Failed to capture audio"
    exit 1
fi
