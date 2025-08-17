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

# Enhanced debugging - Check environment
echo "DEBUG: Environment check..."
echo "  - Current user: $(whoami)"
echo "  - Working directory: $(pwd)"
echo "  - Available disk space: $(df -h "$OUTPUT_DIR" | tail -1 | awk '{print $4}')"
echo "  - Output directory permissions: $(ls -ld "$OUTPUT_DIR")"

# Check if required tools are available
echo "DEBUG: Tool availability check..."
for tool in rtl_test rtl_fm sox; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  ✓ $tool: $(which "$tool")"
    else
        echo "  ✗ $tool: NOT FOUND"
        exit 1
    fi
done

# Check if RTL-SDR device is available
echo "DEBUG: RTL-SDR device detection..."
if ! rtl_test -t; then
    echo "ERROR: No RTL-SDR device found!"
    echo ""
    echo "DEBUG: Additional device information..."
    echo "USB devices:"
    lsusb 2>/dev/null || echo "  lsusb not available"
    echo ""
    echo "Device files in /dev:"
    ls -la /dev/ | grep -E "(rtl|sdr|usb)" || echo "  No RTL-SDR related devices found"
    echo ""
    echo "Please ensure:"
    echo "1. RTL-SDR dongle is connected"
    echo "2. Docker has USB device access"
    echo "3. Device permissions are correct"
    echo "4. USB devices are properly mounted in container"
    exit 1
else
    echo "  ✓ RTL-SDR device detected successfully"
fi

echo "DEBUG: Starting capture process..."

# Capture signal from RTL-SDR using specified demodulation mode
echo "DEBUG: Executing demodulation mode: $DEMOD_MODE"

case "$DEMOD_MODE" in
    "fm")
        RTL_SAMPLE_RATE=48000
        OUTPUT_SAMPLE_RATE=48000  # Use standard audio sample rate for FM
        echo "DEBUG: FM mode - RTL sample rate: $RTL_SAMPLE_RATE, Output sample rate: $OUTPUT_SAMPLE_RATE"
        echo "DEBUG: Command: rtl_fm -f $FREQ_HZ -M fm -s $RTL_SAMPLE_RATE -r $OUTPUT_SAMPLE_RATE -g 47 -E dc -F 9 - | sox -t raw -r $OUTPUT_SAMPLE_RATE -e signed -b 16 -c 1 - -t wav $OUTPUT_PATH trim 0 $DURATION"
        
        # Run the command with proper error handling and no binary output to terminal
        echo "DEBUG: Starting rtl_fm -> sox pipeline..."
        (rtl_fm -f "$FREQ_HZ" -M fm -s $RTL_SAMPLE_RATE -r "$OUTPUT_SAMPLE_RATE" -g 47 -E dc -F 9 - 2>/tmp/rtl_fm_capture.log | \
         sox -t raw -r "$OUTPUT_SAMPLE_RATE" -e signed -b 16 -c 1 - -t wav "$OUTPUT_PATH" trim 0 "$DURATION" 2>/tmp/sox_capture.log) &
        
        CAPTURE_PID=$!
        echo "DEBUG: Pipeline started with PID: $CAPTURE_PID"
        
        # Wait for capture to complete with timeout
        CAPTURE_TIMEOUT=$((DURATION + 10))
        echo "DEBUG: Waiting up to $CAPTURE_TIMEOUT seconds for capture to complete..."
        
        for i in $(seq 1 $CAPTURE_TIMEOUT); do
            if ! kill -0 $CAPTURE_PID 2>/dev/null; then
                echo "DEBUG: Capture process completed naturally at ${i}s"
                break
            fi
            if [ $i -eq $CAPTURE_TIMEOUT ]; then
                echo "DEBUG: Timeout reached, terminating capture process..."
                kill $CAPTURE_PID 2>/dev/null
                wait $CAPTURE_PID 2>/dev/null
            fi
            sleep 1
        done
        
        # Show any errors
        if [ -f "/tmp/rtl_fm_capture.log" ]; then
            echo "DEBUG: rtl_fm messages:"
            cat /tmp/rtl_fm_capture.log | head -10 | sed 's/^/  /'
        fi
        if [ -f "/tmp/sox_capture.log" ]; then
            echo "DEBUG: sox messages:"
            cat /tmp/sox_capture.log | head -10 | sed 's/^/  /'
        fi
        # Fix status capture that was broken by previous edit
        ;;
    "lsb")
        RTL_SAMPLE_RATE=48000
        OUTPUT_SAMPLE_RATE=48000  # Use standard audio sample rate for LSB
        echo "DEBUG: LSB mode - RTL sample rate: $RTL_SAMPLE_RATE, Output sample rate: $OUTPUT_SAMPLE_RATE"
        echo "DEBUG: Command: rtl_fm -f $FREQ_HZ -M lsb -s $RTL_SAMPLE_RATE -r $OUTPUT_SAMPLE_RATE -g 47 -E dc - | sox -t raw -r $OUTPUT_SAMPLE_RATE -e signed -b 16 -c 1 - -t wav $OUTPUT_PATH trim 0 $DURATION"
        
        (rtl_fm -f "$FREQ_HZ" -M lsb -s $RTL_SAMPLE_RATE -r $OUTPUT_SAMPLE_RATE -g 47 -E dc - 2>/tmp/rtl_fm_capture.log | \
         sox -t raw -r $OUTPUT_SAMPLE_RATE -e signed -b 16 -c 1 - -t wav "$OUTPUT_PATH" trim 0 "$DURATION" 2>/tmp/sox_capture.log) &
        wait
        ;;
    "usb")
        RTL_SAMPLE_RATE=48000
        OUTPUT_SAMPLE_RATE=48000  # Use standard audio sample rate for USB
        echo "DEBUG: USB mode - RTL sample rate: $RTL_SAMPLE_RATE, Output sample rate: $OUTPUT_SAMPLE_RATE"
        echo "DEBUG: Command: rtl_fm -f $FREQ_HZ -M usb -s $RTL_SAMPLE_RATE -r $OUTPUT_SAMPLE_RATE -g 47 -E dc - | sox -t raw -r $OUTPUT_SAMPLE_RATE -e signed -b 16 -c 1 - -t wav $OUTPUT_PATH trim 0 $DURATION"
        
        (rtl_fm -f "$FREQ_HZ" -M usb -s $RTL_SAMPLE_RATE -r "$OUTPUT_SAMPLE_RATE" -g 47 -E dc - 2>/tmp/rtl_fm_capture.log | \
         sox -t raw -r "$OUTPUT_SAMPLE_RATE" -e signed -b 16 -c 1 - -t wav "$OUTPUT_PATH" trim 0 "$DURATION" 2>/tmp/sox_capture.log) &
        wait
        ;;
    "am")
        RTL_SAMPLE_RATE=48000
        OUTPUT_SAMPLE_RATE=48000  # Use standard audio sample rate for AM
        echo "DEBUG: AM mode - RTL sample rate: $RTL_SAMPLE_RATE, Output sample rate: $OUTPUT_SAMPLE_RATE"
        echo "DEBUG: Command: rtl_fm -f $FREQ_HZ -M am -s $RTL_SAMPLE_RATE -r $OUTPUT_SAMPLE_RATE -g 47 -E dc - | sox -t raw -r $OUTPUT_SAMPLE_RATE -e signed -b 16 -c 1 - -t wav $OUTPUT_PATH trim 0 $DURATION"
        
        (rtl_fm -f "$FREQ_HZ" -M am -s $RTL_SAMPLE_RATE -r "$OUTPUT_SAMPLE_RATE" -g 47 -E dc - 2>/tmp/rtl_fm_capture.log | \
         sox -t raw -r "$OUTPUT_SAMPLE_RATE" -e signed -b 16 -c 1 - -t wav "$OUTPUT_PATH" trim 0 "$DURATION" 2>/tmp/sox_capture.log) &
        wait
        ;;
    "raw")
        # For raw I/Q data analysis - saves as complex samples (not playable audio)
        RAW_SAMPLE_RATE=2048000
        RAW_OUTPUT_PATH="${OUTPUT_PATH%.wav}.raw"
        echo "DEBUG: RAW mode - Sample rate: $RAW_SAMPLE_RATE, Output: $RAW_OUTPUT_PATH"
        echo "DEBUG: Command: timeout $DURATION rtl_sdr -f $FREQ_HZ -s $RAW_SAMPLE_RATE -g 47 - | sox -t raw -r $RAW_SAMPLE_RATE -e unsigned -b 8 -c 2 - $RAW_OUTPUT_PATH trim 0 $DURATION"
        
        (timeout "$DURATION" rtl_sdr -f "$FREQ_HZ" -s $RAW_SAMPLE_RATE -g 47 - 2>/tmp/rtl_sdr_capture.log | \
         sox -t raw -r $RAW_SAMPLE_RATE -e unsigned -b 8 -c 2 - "$RAW_OUTPUT_PATH" trim 0 "$DURATION" 2>/tmp/sox_capture.log) &
        wait
        echo "WARNING: Raw I/Q data saved to $RAW_OUTPUT_PATH (not a WAV audio file)"
        SOX_STATUS=${PIPESTATUS[1]}
        echo "WARNING: Raw I/Q data saved to $RAW_OUTPUT_PATH (not a WAV audio file)"
        ;;
    *)
        echo "ERROR: Unknown demodulation mode: $DEMOD_MODE"
        echo "Supported modes: fm, lsb, usb, am, raw"
        exit 1
        ;;
esac

echo "DEBUG: Capture process completed"
echo "  - rtl_fm/rtl_sdr exit status: $CAPTURE_STATUS"
echo "  - sox exit status: $SOX_STATUS"

echo "DEBUG: Capture process completed"
echo "  - rtl_fm/rtl_sdr exit status: $CAPTURE_STATUS"
echo "  - sox exit status: $SOX_STATUS"

# Validate the output file
echo "DEBUG: Output file validation..."
if [ -f "$OUTPUT_PATH" ]; then
    FILE_SIZE=$(stat -c%s "$OUTPUT_PATH" 2>/dev/null || echo "0")
    echo "  ✓ File exists: $OUTPUT_PATH"
    echo "  - File size: $FILE_SIZE bytes ($(du -h "$OUTPUT_PATH" | cut -f1))"
    
    # Check if it's a valid WAV file
    if file "$OUTPUT_PATH" | grep -q "WAVE"; then
        echo "  ✓ Valid WAV file format detected"
        
        # Try to get audio information using sox
        if soxi "$OUTPUT_PATH" >/dev/null 2>&1; then
            echo "  ✓ WAV file is readable by sox"
            echo "  - Duration: $(soxi -D "$OUTPUT_PATH" 2>/dev/null) seconds"
            echo "  - Sample rate: $(soxi -r "$OUTPUT_PATH" 2>/dev/null) Hz"
            echo "  - Channels: $(soxi -c "$OUTPUT_PATH" 2>/dev/null)"
            echo "  - Bit depth: $(soxi -b "$OUTPUT_PATH" 2>/dev/null) bits"
        else
            echo "  ⚠ WARNING: WAV file cannot be read by sox"
            soxi "$OUTPUT_PATH" 2>&1 | head -5 | sed 's/^/    /'
        fi
    else
        echo "  ✗ ERROR: File is not a valid WAV format"
        echo "  - File type: $(file "$OUTPUT_PATH")"
    fi
    
    # Check if file size is suspiciously small
    if [ "$FILE_SIZE" -lt 1000 ]; then
        echo "  ⚠ WARNING: File size is very small ($FILE_SIZE bytes)"
        echo "  - This indicates the capture process likely failed"
        echo "  - Check rtl_fm and sox error messages above"
    fi
else
    echo "  ✗ ERROR: Output file was not created: $OUTPUT_PATH"
    echo "  - Check write permissions for: $OUTPUT_DIR"
    echo "  - Check available disk space"
    echo "  - Check rtl_fm and sox error messages above"
fi

# Overall status check
OVERALL_STATUS=0
if [ "$CAPTURE_STATUS" -ne 0 ]; then
    echo "ERROR: rtl_fm/rtl_sdr failed with exit status $CAPTURE_STATUS"
    OVERALL_STATUS=1
fi

if [ "$SOX_STATUS" -ne 0 ]; then
    echo "ERROR: sox failed with exit status $SOX_STATUS"
    OVERALL_STATUS=1
fi

if [ "$OVERALL_STATUS" -eq 0 ] && [ -f "$OUTPUT_PATH" ] && [ "$(stat -c%s "$OUTPUT_PATH" 2>/dev/null)" -gt 1000 ]; then
    echo "SUCCESS: Audio captured to $OUTPUT_PATH"
    echo "File size: $(du -h "$OUTPUT_PATH" | cut -f1)"
    echo "Duration: $(soxi -D "$OUTPUT_PATH" 2>/dev/null || echo "unknown") seconds"
else
    echo "ERROR: Failed to capture audio properly"
    echo ""
    echo "DEBUG: Troubleshooting information:"
    echo "1. Check that RTL-SDR device is properly connected"
    echo "2. Verify Docker container has USB device access"
    echo "3. Check that the frequency $FREQ is valid for your RTL-SDR"
    echo "4. Ensure sufficient disk space in $OUTPUT_DIR"
    echo "5. Try a different demodulation mode (fm, lsb, usb, am)"
    echo "6. Check for interference or weak signal strength"
    exit 1
fi
