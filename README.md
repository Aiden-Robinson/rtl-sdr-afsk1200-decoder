# RTL-SDR Digital Signal Explorer

Docker-based pipeline for capturing and decoding digital signals using RTL-SDR dongles. Supports multiple demodulation modes (FM, LSB, USB, AM) and decoders (AFSK, PSK, RTTY, CW, FSK).

## Prerequisites

**Important:** Before running, ensure your RTL-SDR device has proper USB permissions:

```bash
# Add your user to the plugdev group
sudo usermod -a -G plugdev $USER

# Create udev rule for RTL-SDR devices
sudo tee /etc/udev/rules.d/20-rtlsdr.rules > /dev/null <<EOF
SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", GROUP="plugdev", MODE="0666", SYMLINK+="rtl_sdr"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Log out and back in (or reboot) for changes to take effect
```

## Quick Start

1. **Build and run:**
   ```bash
   docker compose build
   docker compose run --rm rtl-decoder /app/scripts/pipeline.sh
   ```

2. **Custom frequency and mode:**
   ```bash
   # APRS on 144.390 MHz for 60 seconds
   docker compose run --rm rtl-decoder /app/scripts/pipeline.sh 144.390M fm 60
   
   # PSK31 on 14.070 MHz for 120 seconds  
   docker compose run --rm rtl-decoder /app/scripts/pipeline.sh 14.070M usb 120
   ```

3. **Interactive mode:**
   ```bash
   docker compose run --rm rtl-decoder bash
   ```

4. **Debug mode (troubleshooting):**
   ```bash
   docker compose run --rm rtl-decoder /app/scripts/debug_capture.sh
   ```

## Usage

```bash
# Basic capture and decode
./pipeline.sh [frequency] [demod_mode] [duration] [decoder_type]

# Examples
./pipeline.sh 144.390M fm 60 auto     # APRS on 144.390 MHz (auto-detect decoder)
./pipeline.sh 14.070M usb 120 psk     # PSK31 on 14.070 MHz  
./pipeline.sh 472.5485M lsb 60 all    # Try all decoders on custom frequency
./pipeline.sh 145.500M fm 300 afsk    # Long APRS capture with AFSK decoder only
```

**Parameters:**
- `frequency`: Target frequency (e.g., 144.390M, 14.070M, 472.5485M)
- `demod_mode`: fm, lsb, usb, am (default: fm)
- `duration`: Capture time in seconds (default: 60)
- `decoder_type`: auto, afsk, psk, rtty, cw, fsk, all (default: auto)

**Common Frequencies:**
- `144.390M fm` - APRS (North America)
- `144.800M fm` - APRS (Europe)
- `14.070M usb` - PSK31 digital mode
- `18.100M usb` - PSK31 digital mode
- `7.040M lsb` - PSK31 digital mode
- `28.120M usb` - PSK31 digital mode

## Troubleshooting

**If you get "usb_claim_interface error -6":**
1. Ensure USB permissions are set up (see Prerequisites)
2. Unplug and reconnect your RTL-SDR dongle
3. Kill any running RTL processes: `sudo pkill -f rtl_`
4. Reboot if necessary

**If audio files are only 44 bytes:**
- This was a known issue that has been fixed
- Run the debug script: `docker compose run --rm rtl-decoder /app/scripts/debug_capture.sh`

**If no signals are decoded:**
- This is normal! Most frequencies don't have active digital traffic
- Try different frequencies or longer capture times
- Use `decoder_type=all` to try all available decoders
- Check that you're using the correct demodulation mode for your target signal

**Debug commands:**
```bash
# Test RTL-SDR device and capture
docker compose run --rm rtl-decoder /app/scripts/debug_capture.sh

# Validate existing audio files
docker compose run --rm rtl-decoder /app/scripts/validate_audio.sh /app/output/session_*/capture_*.wav

# Interactive troubleshooting
docker compose run --rm rtl-decoder bash
```

## Output

Each run creates timestamped session files in `/output/session_YYYYMMDD_HHMMSS/`:

- `capture_TIMESTAMP.wav` - Raw audio (48kHz, 16-bit, mono)
- `decoded_TIMESTAMP.txt` - Raw decoder output from multimon-ng
- `decoded_TIMESTAMP_direwolf.txt` - Alternative decoder output (if signals found)
- `parsed_TIMESTAMP.json` - Structured data in JSON format
- `parsed_TIMESTAMP.txt` - Human-readable formatted output
- `summary_TIMESTAMP.txt` - Statistics and summary

**Example successful output:**
```
📁 output/session_20250817_034936/
├── 🎵 capture_20250817_034936.wav        (2.8M - 30 seconds of audio)
├── 📄 decoded_20250817_034936.txt         (344 bytes - decoder output)  
├── 📊 parsed_20250817_034936.json         (structured data)
├── 📝 parsed_20250817_034936.txt          (human readable)
└── 📋 summary_20250817_034936.txt         (statistics)
```

## Technical Details

**Audio Processing:**
- RTL-SDR sample rate: 48kHz (for FM/AM/LSB/USB modes)
- Output audio: 48kHz, 16-bit signed, mono WAV
- Raw I/Q mode: 2.048 MSPS (saved as .raw file)

**Supported Decoders:**
- **AFSK1200**: APRS, packet radio
- **PSK31/PSK63**: Digital text modes
- **RTTY**: Radio teletype
- **FSK**: Various FSK modes (1200, 2400, 4800, 9600 baud)
- **CW**: Morse code
- **POCSAG**: Pager signals
- **FLEX**: Pager signals

**Docker Container Features:**
- Privileged USB access for RTL-SDR
- Comprehensive debugging and logging
- Automatic error recovery
- Session-based output organization

## Requirements

- **Hardware**: RTL-SDR dongle (Blog V4, R820T2, etc.)
- **Software**: Docker & Docker Compose
- **System**: Linux with USB device access
- **Permissions**: User in `plugdev` group (see Prerequisites)
