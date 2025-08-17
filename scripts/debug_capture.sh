#!/bin/bash

# Debug script to identify RTL-SDR capture issues
# This script performs comprehensive debugging of the capture process

echo "=== RTL-SDR Debug Capture Test ==="
echo "Timestamp: $(date)"
echo "====================================="

# Basic environment check
echo ""
echo "1. ENVIRONMENT CHECK"
echo "-------------------"
echo "Current user: $(whoami)"
echo "Working directory: $(pwd)"
echo "Available tools:"
for tool in rtl_test rtl_fm rtl_sdr sox file soxi; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  ✓ $tool: $(which "$tool")"
        if [ "$tool" = "rtl_fm" ]; then
            echo "    Version: $(rtl_fm 2>&1 | head -1 || echo 'Version info not available')"
        elif [ "$tool" = "sox" ]; then
            echo "    Version: $(sox --version 2>&1 | head -1 || echo 'Version info not available')"
        fi
    else
        echo "  ✗ $tool: NOT FOUND"
    fi
done

# USB device check
echo ""
echo "2. USB DEVICE CHECK"
echo "------------------"
echo "USB devices (lsusb):"
lsusb 2>/dev/null | grep -E "(RTL|2832|0bda|Realtek)" || echo "  No RTL-SDR devices found via lsusb"

echo ""
echo "Device files in /dev:"
ls -la /dev/ | grep -E "(rtl|sdr)" || echo "  No RTL-SDR device files found"

echo ""
echo "USB bus devices:"
ls -la /dev/bus/usb/ 2>/dev/null | head -10 || echo "  Cannot access /dev/bus/usb/"

# RTL-SDR device test
echo ""
echo "3. RTL-SDR DEVICE TEST"
echo "---------------------"
echo "Testing RTL-SDR device detection..."
if rtl_test -t 2>&1; then
    echo "✓ RTL-SDR device test passed"
else
    echo "✗ RTL-SDR device test failed"
    echo ""
    echo "Detailed rtl_test output:"
    rtl_test -t 2>&1 | head -10 | sed 's/^/  /'
fi

# Quick capture test (5 seconds)
echo ""
echo "4. QUICK CAPTURE TEST"
echo "--------------------"
TEST_DIR="/tmp/rtl_debug_test"
mkdir -p "$TEST_DIR"

FREQ="144.390M"  # Common APRS frequency
DURATION=5
OUTPUT_FILE="$TEST_DIR/debug_test.wav"

echo "Testing short capture (5 seconds)..."
echo "Frequency: $FREQ"
echo "Output: $OUTPUT_FILE"

# Test rtl_fm command (just status, no data output)
echo ""
echo "Testing rtl_fm device access..."
timeout 3 rtl_fm -f 144390000 -M fm -s 48000 -r 48000 -g 47 -E dc -F 9 - 2>&1 >/dev/null | head -10 | sed 's/^/  /'

# Test full pipeline with proper pipe handling
echo ""
echo "Testing full capture pipeline..."
echo "Starting rtl_fm -> sox pipeline..."

# Use timeout to prevent infinite hanging
timeout $((DURATION + 5)) bash -c "
rtl_fm -f 144390000 -M fm -s 48000 -r 48000 -g 47 -E dc -F 9 - 2>/tmp/rtl_debug.log | \
sox -t raw -r 48000 -e signed -b 16 -c 1 - -t wav '$OUTPUT_FILE' trim 0 $DURATION 2>/tmp/sox_debug.log
" &

CAPTURE_PID=$!
echo "Pipeline started with PID: $CAPTURE_PID"

# Monitor progress
for i in {1..6}; do
    sleep 1
    if [ -f "$OUTPUT_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "0")
        echo "Progress: ${i}s - File size: ${FILE_SIZE} bytes"
    else
        echo "Progress: ${i}s - No file yet"
    fi
done

# Kill the process if still running
if kill -0 $CAPTURE_PID 2>/dev/null; then
    echo "Terminating capture process..."
    kill $CAPTURE_PID 2>/dev/null
    wait $CAPTURE_PID 2>/dev/null
fi

# Check results
echo ""
echo "5. CAPTURE RESULTS"
echo "-----------------"
if [ -f "$OUTPUT_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo "✓ Output file created: $OUTPUT_FILE"
    echo "  - File size: $FILE_SIZE bytes"
    echo "  - File type: $(file "$OUTPUT_FILE")"
    
    if [ "$FILE_SIZE" -gt 1000 ]; then
        echo "  ✓ File size looks reasonable"
        
        # Try to get audio info
        if command -v soxi >/dev/null 2>&1; then
            echo "  - Audio info:"
            soxi "$OUTPUT_FILE" 2>&1 | sed 's/^/    /' || echo "    Cannot read audio info"
        fi
    else
        echo "  ⚠ WARNING: File size is very small ($FILE_SIZE bytes)"
    fi
else
    echo "✗ Output file not created"
fi

# Show error logs
echo ""
echo "6. ERROR LOGS"
echo "------------"
if [ -f "/tmp/rtl_debug.log" ]; then
    echo "rtl_fm errors/warnings:"
    cat /tmp/rtl_debug.log | head -10 | sed 's/^/  /'
fi

if [ -f "/tmp/sox_debug.log" ]; then
    echo ""
    echo "sox errors/warnings:"
    cat /tmp/sox_debug.log | head -10 | sed 's/^/  /'
fi

# System resources
echo ""
echo "7. SYSTEM RESOURCES"
echo "------------------"
echo "Disk space:"
df -h /tmp | sed 's/^/  /'

echo ""
echo "Memory usage:"
free -h | sed 's/^/  /'

# Clean up
echo ""
echo "8. CLEANUP"
echo "---------"
rm -rf "$TEST_DIR" /tmp/rtl_debug.log /tmp/sox_debug.log /tmp/rtl_fm_test.log
echo "Test files cleaned up"

echo ""
echo "=== Debug test completed ==="
echo ""
echo "SUMMARY:"
echo "--------"
if [ -f "$OUTPUT_FILE" ] && [ "$(stat -c%s "$OUTPUT_FILE" 2>/dev/null)" -gt 1000 ]; then
    echo "✓ Basic capture appears to be working"
    echo "  The issue may be with specific frequencies, durations, or demodulation modes"
    echo "  Try running the full pipeline with different parameters"
else
    echo "✗ Basic capture is not working"
    echo "  Check the error messages above for specific issues"
    echo "  Common problems:"
    echo "  - RTL-SDR device not properly connected or detected"
    echo "  - USB device permissions in Docker container"
    echo "  - Missing or incorrect device drivers"
    echo "  - Hardware malfunction"
fi
