#!/bin/bash

# Digital Signal Decoder Script
# This script tries multiple decoders to identify and decode digital signals

# Check if input file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_wav_file> [output_file] [decoder_type]"
    echo "Decoder types: auto, afsk, psk, rtty, cw, fsk, all"
    echo "Example: $0 /app/output/capture.wav /app/output/decoded.txt auto"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-${INPUT_FILE%.*}_decoded.txt}"
DECODER_TYPE="${3:-auto}"
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input file '$INPUT_FILE' not found!"
    exit 1
fi

# Validate input file
echo "DEBUG: Input file validation..."
FILE_SIZE=$(stat -c%s "$INPUT_FILE" 2>/dev/null || echo "0")
echo "  - File exists: $INPUT_FILE"
echo "  - File size: $FILE_SIZE bytes ($(du -h "$INPUT_FILE" | cut -f1))"

# Check if it's a valid audio file
if file "$INPUT_FILE" | grep -q "WAVE\|audio"; then
    echo "  ✓ Audio file format detected"
    
    # Try to get audio information
    if command -v soxi >/dev/null 2>&1 && soxi "$INPUT_FILE" >/dev/null 2>&1; then
        echo "  ✓ Audio file is readable"
        echo "  - Duration: $(soxi -D "$INPUT_FILE" 2>/dev/null) seconds"
        echo "  - Sample rate: $(soxi -r "$INPUT_FILE" 2>/dev/null) Hz"
        echo "  - Channels: $(soxi -c "$INPUT_FILE" 2>/dev/null)"
        echo "  - Bit depth: $(soxi -b "$INPUT_FILE" 2>/dev/null) bits"
    else
        echo "  ⚠ WARNING: Audio file cannot be read properly"
        if command -v soxi >/dev/null 2>&1; then
            soxi "$INPUT_FILE" 2>&1 | head -3 | sed 's/^/    /'
        fi
    fi
else
    echo "  ⚠ WARNING: File does not appear to be a valid audio file"
    echo "  - File type: $(file "$INPUT_FILE")"
fi

# Check if file size is too small
if [ "$FILE_SIZE" -lt 1000 ]; then
    echo "  ⚠ WARNING: Input file is very small ($FILE_SIZE bytes)"
    echo "  - This suggests the audio capture failed"
    echo "  - Decoding will likely produce no results"
fi

echo "=== Digital Signal Decoding Started ==="
echo "Input file: $INPUT_FILE"
echo "Output file: $OUTPUT_FILE"
echo "Decoder type: $DECODER_TYPE"
echo "File size: $(du -h "$INPUT_FILE" | cut -f1)"
echo "Duration: $(soxi -D "$INPUT_FILE" 2>/dev/null || echo "unknown") seconds"
echo "========================================"

# Initialize results
> "$OUTPUT_FILE"
TOTAL_DECODED=0

# Function to try AFSK decoders
try_afsk() {
    echo "Trying AFSK1200 decoder (multimon-ng)..."
    echo "DEBUG: Running multimon-ng -a AFSK1200 -t wav -A -u \"$INPUT_FILE\""
    
    # Run multimon-ng with debugging
    multimon-ng -a AFSK1200 -t wav -A -u "$INPUT_FILE" >> "$OUTPUT_FILE" 2>&1
    MULTIMON_STATUS=$?
    
    echo "DEBUG: multimon-ng exit status: $MULTIMON_STATUS"
    
    AFSK_COUNT=$(grep -c "AFSK1200:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo "  - AFSK1200 packets: $AFSK_COUNT"
    
    # Show some multimon-ng output for debugging
    if [ -s "$OUTPUT_FILE" ]; then
        echo "DEBUG: multimon-ng output (first 10 lines):"
        head -10 "$OUTPUT_FILE" | sed 's/^/  /'
    fi
    
    echo "Trying Direwolf APRS decoder..."
    DIREWOLF_OUTPUT="${OUTPUT_FILE%.*}_direwolf.txt"
    echo "DEBUG: Running direwolf -t 0 -r 48000 -B 1200 -q d -a 100 \"$INPUT_FILE\""
    
    # Run direwolf with debugging
    direwolf -t 0 -r 48000 -B 1200 -q d -a 100 "$INPUT_FILE" > "$DIREWOLF_OUTPUT" 2>&1
    DIREWOLF_STATUS=$?
    
    echo "DEBUG: direwolf exit status: $DIREWOLF_STATUS"
    
    DIREWOLF_COUNT=$(grep -c "^\[" "$DIREWOLF_OUTPUT" 2>/dev/null || echo "0")
    if [ "$DIREWOLF_COUNT" -gt 0 ]; then
        echo "  - Direwolf packets: $DIREWOLF_COUNT"
        cat "$DIREWOLF_OUTPUT" >> "$OUTPUT_FILE"
    else
        echo "  - Direwolf packets: 0"
        # Show direwolf errors/warnings for debugging
        if [ -s "$DIREWOLF_OUTPUT" ]; then
            echo "DEBUG: direwolf output (first 10 lines):"
            head -10 "$DIREWOLF_OUTPUT" | sed 's/^/  /'
        fi
    fi
    
    TOTAL_DECODED=$((TOTAL_DECODED + AFSK_COUNT + DIREWOLF_COUNT))
}

# Function to try PSK decoders
try_psk() {
    echo "Trying PSK31/PSK63 decoder (multimon-ng)..."
    multimon-ng -a PSK31 -t wav -A -u "$INPUT_FILE" >> "$OUTPUT_FILE" 2>&1
    PSK31_COUNT=$(grep -c "PSK31:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo "  - PSK31 packets: $PSK31_COUNT"
    
    multimon-ng -a PSK63 -t wav -A -u "$INPUT_FILE" >> "$OUTPUT_FILE" 2>&1
    PSK63_COUNT=$(grep -c "PSK63:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo "  - PSK63 packets: $PSK63_COUNT"
    
    TOTAL_DECODED=$((TOTAL_DECODED + PSK31_COUNT + PSK63_COUNT))
}

# Function to try RTTY decoder
try_rtty() {
    echo "Trying RTTY decoder (multimon-ng)..."
    multimon-ng -a RTTY -t wav -A -u "$INPUT_FILE" >> "$OUTPUT_FILE" 2>&1
    RTTY_COUNT=$(grep -c "RTTY:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo "  - RTTY packets: $RTTY_COUNT"
    
    TOTAL_DECODED=$((TOTAL_DECODED + RTTY_COUNT))
}

# Function to try CW decoder
try_cw() {
    echo "Trying CW (Morse Code) decoder..."
    # Use multimon-ng for CW if available
    multimon-ng -a MORSE_CW -t wav -A -u "$INPUT_FILE" >> "$OUTPUT_FILE" 2>&1 || true
    CW_COUNT=$(grep -c "MORSE:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo "  - CW messages: $CW_COUNT"
    
    TOTAL_DECODED=$((TOTAL_DECODED + CW_COUNT))
}

# Function to try FSK decoders
try_fsk() {
    echo "Trying FSK decoders (multimon-ng)..."
    
    # Try different FSK modes
    for mode in FSK9600 FSK4800 FSK2400 FSK1200; do
        multimon-ng -a "$mode" -t wav -A -u "$INPUT_FILE" >> "$OUTPUT_FILE" 2>&1 || true
        COUNT=$(grep -c "$mode:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
        echo "  - $mode packets: $COUNT"
        TOTAL_DECODED=$((TOTAL_DECODED + COUNT))
    done
}

# Function to try all decoders
try_all() {
    echo "Trying all available decoders..."
    try_afsk
    try_psk
    try_rtty
    try_cw
    try_fsk
    
    echo "Trying additional multimon-ng modes..."
    # Try other modes that might be available
    for mode in POCSAG512 POCSAG1200 POCSAG2400 FLEX SCOPE; do
        multimon-ng -a "$mode" -t wav -A -u "$INPUT_FILE" >> "$OUTPUT_FILE" 2>&1 || true
        COUNT=$(grep -c "$mode:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
        if [ "$COUNT" -gt 0 ]; then
            echo "  - $mode packets: $COUNT"
            TOTAL_DECODED=$((TOTAL_DECODED + COUNT))
        fi
    done
}

# Auto-detect signal characteristics
auto_detect() {
    echo "Auto-detecting signal type..."
    
    # Start with most common digital modes
    try_afsk
    if [ "$TOTAL_DECODED" -gt 0 ]; then
        echo "Found AFSK signals, stopping auto-detection"
        return
    fi
    
    try_psk
    if [ "$TOTAL_DECODED" -gt 0 ]; then
        echo "Found PSK signals, stopping auto-detection"
        return
    fi
    
    try_rtty
    if [ "$TOTAL_DECODED" -gt 0 ]; then
        echo "Found RTTY signals, stopping auto-detection"
        return
    fi
    
    try_fsk
    if [ "$TOTAL_DECODED" -gt 0 ]; then
        echo "Found FSK signals, stopping auto-detection"
        return
    fi
    
    try_cw
    if [ "$TOTAL_DECODED" -gt 0 ]; then
        echo "Found CW signals, stopping auto-detection"
        return
    fi
    
    echo "No signals detected with standard decoders"
}

# Run decoder based on type
case "$DECODER_TYPE" in
    "afsk")
        try_afsk
        ;;
    "psk")
        try_psk
        ;;
    "rtty")
        try_rtty
        ;;
    "cw")
        try_cw
        ;;
    "fsk")
        try_fsk
        ;;
    "all")
        try_all
        ;;
    "auto")
        auto_detect
        ;;
    *)
        echo "ERROR: Unknown decoder type: $DECODER_TYPE"
        echo "Supported types: auto, afsk, psk, rtty, cw, fsk, all"
        exit 1
        ;;
esac

echo ""
echo "=== Decoding Results ==="
echo "Total decoded messages: $TOTAL_DECODED"
echo "Output saved to: $OUTPUT_FILE"

if [ "$TOTAL_DECODED" -gt 0 ]; then
    echo ""
    echo "=== Sample Decoded Data ==="
    head -n 30 "$OUTPUT_FILE" | grep -E ":" || echo "No formatted packets found"
    echo "=========================="
else
    echo ""
    echo "No digital signals decoded. This could mean:"
    echo "1. No digital signals present in the audio"
    echo "2. Signal quality too poor for decoding"
    echo "3. Unknown or unsupported modulation type"
    echo "4. Wrong demodulation mode (try different modes: fm, lsb, usb, am)"
    echo "5. Signal might be encrypted or use proprietary encoding"
    echo ""
    echo "Try:"
    echo "- Different demodulation modes in capture"
    echo "- Adjusting frequency slightly"
    echo "- Longer capture duration"
    echo "- Different decoder types"
fi

echo "✓ Digital signal decoding completed"
