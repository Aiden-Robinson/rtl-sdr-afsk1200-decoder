#!/bin/bash

# Complete Digital Signal Exploration Pipeline
# This script runs the complete pipeline from RTL-SDR capture to decoded output
# Supports multiple demodulation modes and decoder types

set -e  # Exit on any error

# Default values - configured in docker-compose.yml
FREQ=${1:-$DEFAULT_FREQ}
DEMOD_MODE=${2:-"fm"}     # fm, lsb, usb, am, raw
DURATION=${3:-60}
DECODER_TYPE=${4:-"auto"} # auto, afsk, psk, rtty, cw, fsk, all
OUTPUT_DIR=${5:-"/app/output"}
SAMPLE_RATE=${6:-$DEFAULT_SAMPLE_RATE}

# Validate required environment variables
if [ -z "$FREQ" ]; then
    echo "ERROR: No frequency specified!"
    echo "Either pass frequency as first argument or ensure DEFAULT_FREQ is set in docker-compose.yml"
    exit 1
fi

if [ -z "$SAMPLE_RATE" ]; then
    echo "ERROR: No sample rate specified!"
    echo "Either pass sample rate as fourth argument or ensure DEFAULT_SAMPLE_RATE is set in docker-compose.yml"
    exit 1
fi

# Generate unique timestamp for this session
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_DIR="$OUTPUT_DIR/session_$TIMESTAMP"

# Create session directory
mkdir -p "$SESSION_DIR"

echo "==============================================="
echo "RTL-SDR Digital Signal Exploration Pipeline"
echo "==============================================="
echo "Frequency: $FREQ"
echo "Demodulation: $DEMOD_MODE"
echo "Duration: $DURATION seconds"
echo "Decoder: $DECODER_TYPE"
echo "Sample Rate: $SAMPLE_RATE Hz"
echo "Session: $TIMESTAMP"
echo "Output Directory: $SESSION_DIR"
echo "==============================================="

# Step 1: Capture audio from RTL-SDR
echo ""
echo "STEP 1: Capturing signal from RTL-SDR..."
AUDIO_FILE="$SESSION_DIR/capture_$TIMESTAMP.wav"
if /app/scripts/rtl_to_wav.sh "$FREQ" "$DEMOD_MODE" "$SAMPLE_RATE" "$DURATION" "$SESSION_DIR" "capture_$TIMESTAMP.wav"; then
    echo "✓ Signal capture completed successfully"
else
    echo "✗ Signal capture failed"
    exit 1
fi

# Step 2: Decode digital signals
echo ""
echo "STEP 2: Decoding digital signals..."
DECODED_FILE="$SESSION_DIR/decoded_$TIMESTAMP.txt"
if /app/scripts/decode_digital.sh "$AUDIO_FILE" "$DECODED_FILE" "$DECODER_TYPE"; then
    echo "✓ Signal decoding completed successfully"
else
    echo "✗ Signal decoding failed"
    exit 1
fi

# Step 3: Parse and format output
echo ""
echo "STEP 3: Parsing decoded messages..."
PARSED_JSON="$SESSION_DIR/parsed_$TIMESTAMP.json"
PARSED_TEXT="$SESSION_DIR/parsed_$TIMESTAMP.txt"
SUMMARY_FILE="$SESSION_DIR/summary_$TIMESTAMP.txt"

python3 /app/scripts/parse_output.py "$DECODED_FILE" --format json --output "$PARSED_JSON"
python3 /app/scripts/parse_output.py "$DECODED_FILE" --format text --output "$PARSED_TEXT"
python3 /app/scripts/parse_output.py "$DECODED_FILE" --summary --output "$SUMMARY_FILE"

echo "✓ Message parsing completed successfully"

# Step 4: Display results
echo ""
echo "STEP 4: Results Summary"
echo "======================="
cat "$SUMMARY_FILE"

echo ""
echo "Pipeline completed successfully!"
echo "Session files saved in: $SESSION_DIR"
echo ""
echo "Generated files:"
echo "- Audio capture: $AUDIO_FILE"
echo "- Raw decoded: $DECODED_FILE"
echo "- Parsed JSON: $PARSED_JSON"
echo "- Parsed text: $PARSED_TEXT"
echo "- Summary: $SUMMARY_FILE"

# Check if we found any messages
MESSAGE_COUNT=$(python3 -c "
import json
try:
    with open('$PARSED_JSON', 'r') as f:
        data = json.load(f)
    print(len(data))
except:
    print(0)
")

if [ "$MESSAGE_COUNT" -gt 0 ]; then
    echo ""
    echo "🎉 Successfully decoded $MESSAGE_COUNT messages!"
    echo ""
    echo "Quick preview (first 5 messages):"
    head -n 50 "$PARSED_TEXT"
else
    echo ""
    echo "⚠️  No messages were decoded. This could be due to:"
    echo "   - No digital signals present on $FREQ"
    echo "   - Wrong demodulation mode (try: fm, lsb, usb, am)"
    echo "   - Weak signal strength"
    echo "   - Unknown or unsupported signal type"
    echo "   - Hardware issues"
    echo ""
    echo "Try adjusting:"
    echo "   - Frequency (scan around the target frequency)"
    echo "   - Demodulation mode (fm/lsb/usb/am)"
    echo "   - Duration (longer capture time)"
    echo "   - Antenna positioning"
    echo "   - RTL-SDR gain settings"
    echo "   - Decoder type (auto/all/specific)"
fi

echo ""
echo "Pipeline execution completed at $(date)"
