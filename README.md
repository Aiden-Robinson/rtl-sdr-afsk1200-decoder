# RTL-SDR Digital Signal Explorer

Docker-based pipeline for capturing and decoding digital signals using RTL-SDR dongles. Supports multiple demodulation modes (FM, LSB, USB, AM) and decoders (AFSK, PSK, RTTY, CW, FSK).

## Quick Start

1. **Build and run:**
   ```bash
   docker compose build
   docker compose run --rm rtl-decoder /app/scripts/pipeline.sh
   ```

2. **Custom frequency and mode:**
   ```bash
   # LSB demodulation on 472.5485 MHz for 120 seconds
   docker compose run --rm rtl-decoder /app/scripts/pipeline.sh 472.5485M lsb 120
   ```

3. **Interactive mode:**
   ```bash
   docker compose run --rm rtl-decoder bash
   ```

## Usage

```bash
# Basic capture and decode
./pipeline.sh [frequency] [demod_mode] [duration]

# Examples
./pipeline.sh 144.390M fm 60      # APRS on 144.390 MHz
./pipeline.sh 14.070M usb 120     # PSK31 on 14.070 MHz  
./pipeline.sh 472.5485M lsb 60    # Custom frequency LSB
```

**Parameters:**
- `frequency`: Target frequency (e.g., 144.390M, 14.070M)
- `demod_mode`: fm, lsb, usb, am (default: fm)
- `duration`: Capture time in seconds (default: 60)

## Output

Each run creates timestamped files:
- `capture_TIMESTAMP.wav` - Raw audio
- `decoded_TIMESTAMP.txt` - Decoder output
- `parsed_TIMESTAMP.json` - Structured data

## Requirements

- RTL-SDR dongle
- Docker & Docker Compose
- USB device access for Docker
