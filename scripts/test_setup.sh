#!/bin/bash

# Test script to validate the RTL-SDR AFSK1200 decoder setup

echo "=== RTL-SDR AFSK1200 Decoder Test ==="
echo "Testing system components..."
echo ""

# Test 1: Check if we're in the correct directory
echo "1. Checking project structure..."
if [ -f "Dockerfile" ] && [ -f "docker-compose.yml" ] && [ -d "scripts" ]; then
    echo "✓ Project structure OK"
else
    echo "✗ Missing required files - ensure you're in the project root"
    exit 1
fi

# Test 2: Check script permissions
echo "2. Checking script permissions..."
for script in scripts/*.sh; do
    if [ -x "$script" ]; then
        echo "✓ $script is executable"
    else
        echo "⚠ Making $script executable..."
        chmod +x "$script"
    fi
done

# Test 3: Test Python parser with sample data
echo "3. Testing Python parser..."
cat > test_sample.txt << 'EOF'
AFSK1200: N0CALL>APRS,TCPIP*,qAC,THIRD:=4903.50N/07201.75W-Test APRS Message
APRS: WB2OSZ-1>APDW15,WIDE1-1,WIDE2-1:!4237.14N/07120.83W>Test Position Report
EOF

if python3 scripts/parse_output.py test_sample.txt --summary > /dev/null 2>&1; then
    echo "✓ Python parser working"
    rm test_sample.txt
else
    echo "✗ Python parser failed"
    rm -f test_sample.txt
    exit 1
fi

# Test 4: Check Docker setup
echo "4. Checking Docker setup..."
if command -v docker > /dev/null 2>&1; then
    echo "✓ Docker is available"
    
    if command -v docker-compose > /dev/null 2>&1 || docker compose version > /dev/null 2>&1; then
        echo "✓ Docker Compose is available"
    else
        echo "✗ Docker Compose not found"
        exit 1
    fi
else
    echo "✗ Docker not found - please install Docker"
    exit 1
fi

# Test 5: Check if we can build the image
echo "5. Testing Docker build (this may take a few minutes)..."
if docker compose build --quiet; then
    echo "✓ Docker image built successfully"
else
    echo "✗ Docker build failed"
    exit 1
fi

echo ""
echo "=== All Tests Passed! ==="
echo ""
echo "Your RTL-SDR AFSK1200 decoder is ready to use."
echo ""
echo "Quick start commands:"
echo "  # Run complete pipeline with defaults:"
echo "  docker compose run --rm rtl-decoder /app/scripts/pipeline.sh"
echo ""
echo "  # Interactive mode:"
echo "  docker compose run --rm rtl-decoder bash"
echo ""
echo "  # Custom frequency (e.g., 145.570 MHz):"
echo "  docker compose run --rm rtl-decoder /app/scripts/pipeline.sh 145.570M 60"
echo ""
echo "Make sure your RTL-SDR dongle is connected before running!"
