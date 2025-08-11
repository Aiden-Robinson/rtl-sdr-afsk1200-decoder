#!/bin/bash

# AFSK1200 Decoder Script
# This script uses multimon-ng to decode AFSK1200 signals from WAV files

# Check if input file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_wav_file> [output_file]"
    echo "Example: $0 /app/output/capture.wav /app/output/decoded.txt"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-${INPUT_FILE%.*}_decoded.txt}"
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input file '$INPUT_FILE' not found!"
    exit 1
fi

echo "=== AFSK1200 Decoding Started ==="
echo "Input file: $INPUT_FILE"
echo "Output file: $OUTPUT_FILE"
echo "File size: $(du -h "$INPUT_FILE" | cut -f1)"
echo "Duration: $(soxi -D "$INPUT_FILE" 2>/dev/null || echo "unknown") seconds"
echo "=================================="

# Decode AFSK1200 using multimon-ng
# -a AFSK1200: decode AFSK1200 signals
# -t wav: input format is WAV
# -A: print all received packets
# -u: flush output immediately
echo "Decoding AFSK1200 signals..."
multimon-ng -a AFSK1200 -t wav -A -u "$INPUT_FILE" > "$OUTPUT_FILE" 2>&1

# Check if decoding was successful
if [ $? -eq 0 ]; then
    echo "SUCCESS: Decoding completed"
    
    # Count decoded packets
    PACKET_COUNT=$(grep -c "AFSK1200:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    APRS_COUNT=$(grep -c "APRS:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    
    echo "Results:"
    echo "- AFSK1200 packets: $PACKET_COUNT"
    echo "- APRS packets: $APRS_COUNT"
    echo "- Output saved to: $OUTPUT_FILE"
    
    if [ "$PACKET_COUNT" -gt 0 ] || [ "$APRS_COUNT" -gt 0 ]; then
        echo ""
        echo "=== Sample Decoded Data ==="
        head -n 20 "$OUTPUT_FILE" | grep -E "(AFSK1200|APRS):" || echo "No packets found in first 20 lines"
        echo "=========================="
    else
        echo "WARNING: No AFSK1200 or APRS packets decoded"
        echo "This could mean:"
        echo "1. No signals present in the audio"
        echo "2. Signal quality too poor"
        echo "3. Wrong frequency or modulation"
        echo "4. Audio level too low/high"
    fi
else
    echo "ERROR: Decoding failed"
    exit 1
fi

# Also try Direwolf decoder as alternative
DIREWOLF_OUTPUT="${OUTPUT_FILE%.*}_direwolf.txt"
echo ""
echo "Trying alternative decoder (Direwolf)..."
direwolf -t 0 -r 48000 -B 1200 -q d -a 100 "$INPUT_FILE" > "$DIREWOLF_OUTPUT" 2>&1

if [ $? -eq 0 ]; then
    DIREWOLF_COUNT=$(grep -c "^\[" "$DIREWOLF_OUTPUT" 2>/dev/null || echo "0")
    echo "Direwolf decoder found $DIREWOLF_COUNT potential packets"
    if [ "$DIREWOLF_COUNT" -gt 0 ]; then
        echo "Direwolf output saved to: $DIREWOLF_OUTPUT"
    fi
else
    echo "Direwolf decoder encountered issues (this is normal if no signals present)"
fi
