# RTL-SDR AFSK1200 Decoder - Process Flow Diagram

## High-Level Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   RTL-SDR       │    │   Docker         │    │   Decoded       │    │   Parsed        │
│   Hardware      │───▶│   Container      │───▶│   Output        │───▶│   Results       │
│                 │    │                  │    │                 │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘    └─────────────────┘
      Physical               Software              Raw Data            Structured Data
```

## Detailed Process Flow Diagram

```
START
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              DOCKER ENVIRONMENT SETUP                               │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ 1. docker-compose.yml Configuration                                                │
│    • Sets frequency: 460.800M                                                      │
│    • Sets sample rate: 2.4 MSPS                                                   │
│    • Mounts USB devices for RTL-SDR access                                        │
│    • Mounts output directory                                                       │
│                                                                                     │
│ 2. Dockerfile Build Process                                                        │
│    • Ubuntu 22.04 base image                                                      │
│    • Install: rtl-sdr, multimon-ng, sox, python3                                 │
│    • Build and install Direwolf decoder                                           │
│    • Make scripts executable                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                PIPELINE EXECUTION                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ Entry Points:                                                                       │
│ • pipeline.sh (complete automated flow)                                           │
│ • Individual scripts (manual control)                                             │
│ • Interactive bash session                                                         │
└─────────────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            STEP 1: SIGNAL CAPTURE                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ Script: rtl_to_wav.sh                                                              │
│                                                                                     │
│ Input Parameters:                                                                   │
│ • Frequency: 460.800M (default from docker-compose)                               │
│ • Sample Rate: 2400000 Hz (2.4 MSPS)                                             │
│ • Duration: 60 seconds (default)                                                   │
│ • Output Directory: /app/output                                                    │
│                                                                                     │
│ Process Flow:                                                                       │
│ ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│ │RTL-SDR Check│───▶│rtl_fm       │───▶│sox          │───▶│WAV File     │         │
│ │rtl_test -t  │    │Demodulation │    │Conversion   │    │Output       │         │
│ └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                                     │
│ rtl_fm Parameters:                                                                  │
│ • -f 460.800M: Target frequency                                                   │
│ • -M fm: FM demodulation                                                          │
│ • -s 48000: RTL-SDR sample rate                                                   │
│ • -r 2400000: Resample rate                                                       │
│ • -g auto: Automatic gain control                                                 │
│ • -E dc: DC blocking filter                                                       │
│ • -F 9: De-emphasis filter                                                        │
│                                                                                     │
│ Output: capture_TIMESTAMP.wav                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           STEP 2: SIGNAL DECODING                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ Script: decode_afsk.sh                                                              │
│                                                                                     │
│ Input: WAV file from Step 1                                                        │
│                                                                                     │
│ Dual Decoder Approach:                                                             │
│                                                                                     │
│ ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│ │                        PRIMARY: multimon-ng                                     │ │
│ ├─────────────────────────────────────────────────────────────────────────────────┤ │
│ │ multimon-ng -a AFSK1200 -t wav -A -u input.wav > output.txt                   │ │
│ │                                                                                 │ │
│ │ Parameters:                                                                     │ │
│ │ • -a AFSK1200: Decode AFSK1200 signals                                        │ │
│ │ • -t wav: Input format is WAV                                                 │ │
│ │ • -A: Print all received packets                                               │ │
│ │ • -u: Flush output immediately                                                 │ │
│ │                                                                                 │ │
│ │ Output Format:                                                                  │ │
│ │ AFSK1200: [decoded_data]                                                       │ │
│ │ APRS: [aprs_message]                                                           │ │
│ └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                              │                                       │
│                                              ▼                                       │
│ ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│ │                      SECONDARY: Direwolf                                       │ │
│ ├─────────────────────────────────────────────────────────────────────────────────┤ │
│ │ direwolf -t 0 -r 48000 -B 1200 -q d -a 100 input.wav > direwolf_output.txt   │ │
│ │                                                                                 │ │
│ │ Parameters:                                                                     │ │
│ │ • -t 0: No TNC mode                                                            │ │
│ │ • -r 48000: Audio sample rate                                                  │ │
│ │ • -B 1200: Baud rate for AFSK1200                                             │ │
│ │ • -q d: Quiet mode, decode only                                               │ │
│ │ • -a 100: Audio level                                                          │ │
│ │                                                                                 │ │
│ │ Output Format:                                                                  │ │
│ │ [timestamp] [decoded_packet]                                                    │ │
│ └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                     │
│ Statistics Generated:                                                               │
│ • Total AFSK1200 packets decoded                                                  │
│ • Total APRS packets decoded                                                       │
│ • Sample decoded data preview                                                      │
│                                                                                     │
│ Output Files:                                                                       │
│ • decoded_TIMESTAMP.txt (multimon-ng output)                                      │
│ • decoded_TIMESTAMP_direwolf.txt (direwolf output)                                │
└─────────────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           STEP 3: MESSAGE PARSING                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ Script: parse_output.py                                                             │
│                                                                                     │
│ Input: Raw decoder output files from Step 2                                        │
│                                                                                     │
│ Parsing Engine (AFSKParser Class):                                                 │
│                                                                                     │
│ ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│ │                          MESSAGE TYPE DETECTION                                 │ │
│ ├─────────────────────────────────────────────────────────────────────────────────┤ │
│ │ Regex Patterns:                                                                 │ │
│ │ • AFSK1200: r'AFSK1200:\s*(.+)'                                               │ │
│ │ • APRS: r'APRS:\s*(.+)'                                                        │ │
│ │ • Direwolf: r'^\[(\d+\.\d+)\]\s*(.+)'                                         │ │
│ │ • Timestamp: r'\[(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\]'                  │ │
│ └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                              │                                       │
│                                              ▼                                       │
│ ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│ │                         APRS CONTENT PARSING                                   │ │
│ ├─────────────────────────────────────────────────────────────────────────────────┤ │
│ │ APRS Message Types:                                                             │ │
│ │                                                                                 │ │
│ │ Position Reports:                                                               │ │
│ │ • Pattern: CALL>DEST:=LLLL.LLNSSSSSS.SSEW                                     │ │
│ │ • Extracts: latitude, longitude, symbol                                        │ │
│ │                                                                                 │ │
│ │ Messages:                                                                       │ │
│ │ • Pattern: CALL>DEST::ADDRESSEE :message_text                                 │ │
│ │ • Extracts: addressee, message content                                         │ │
│ │                                                                                 │ │
│ │ Status Reports:                                                                 │ │
│ │ • Pattern: CALL>DEST:>status_text                                             │ │
│ │ • Extracts: status information                                                 │ │
│ │                                                                                 │ │
│ │ Weather Data:                                                                   │ │
│ │ • Pattern: CALL>DEST:...weather_data...                                       │ │
│ │ • Extracts: weather parameters                                                 │ │
│ └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                              │                                       │
│                                              ▼                                       │
│ ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│ │                        STRUCTURED DATA OUTPUT                                  │ │
│ ├─────────────────────────────────────────────────────────────────────────────────┤ │
│ │ JSON Structure per message:                                                     │ │
│ │ {                                                                               │ │
│ │   "type": "AFSK1200|APRS|DIREWOLF",                                           │ │
│ │   "line": line_number,                                                          │ │
│ │   "timestamp": "ISO_datetime",                                                  │ │
│ │   "raw_message": "original_decoded_text",                                      │ │
│ │   "source_file": "input_filename",                                             │ │
│ │   "parsed": {                                                                   │ │
│ │     "message_type": "position|message|status|weather|unknown",                 │ │
│ │     "source_call": "calling_station",                                          │ │
│ │     "destination": "destination_call",                                          │ │
│ │     "path": "routing_path",                                                     │ │
│ │     "data": "message_specific_data"                                            │ │
│ │   }                                                                             │ │
│ │ }                                                                               │ │
│ └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                     │
│ Output Formats:                                                                     │
│ • JSON: parsed_TIMESTAMP.json (machine readable)                                  │
│ • Text: parsed_TIMESTAMP.txt (human readable)                                     │
│ • Summary: summary_TIMESTAMP.txt (statistics)                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            STEP 4: RESULTS & ANALYSIS                               │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ Generated Session Directory: session_TIMESTAMP/                                    │
│                                                                                     │
│ File Structure:                                                                     │
│ session_20250810_143022/                                                          │
│ ├── capture_20250810_143022.wav      # Raw audio capture                         │
│ ├── decoded_20250810_143022.txt      # multimon-ng output                        │
│ ├── decoded_20250810_143022_direwolf.txt  # direwolf output                      │
│ ├── parsed_20250810_143022.json      # Structured JSON data                      │
│ ├── parsed_20250810_143022.txt       # Human-readable report                     │
│ └── summary_20250810_143022.txt      # Statistics summary                        │
│                                                                                     │
│ ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│ │                            SUMMARY STATISTICS                                   │ │
│ ├─────────────────────────────────────────────────────────────────────────────────┤ │
│ │ • Total messages decoded                                                        │ │
│ │ • Messages by type (AFSK1200, APRS, DIREWOLF)                                 │ │
│ │ • Top 10 source stations                                                       │ │
│ │ • Success/failure indicators                                                    │ │
│ │ • Troubleshooting suggestions if no signals found                              │ │
│ └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                     │
│ ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│ │                           SUCCESS CRITERIA                                      │ │
│ ├─────────────────────────────────────────────────────────────────────────────────┤ │
│ │ Pipeline Success:                                                               │ │
│ │ ✓ RTL-SDR device detected and responsive                                       │ │
│ │ ✓ Audio capture completed without errors                                       │ │
│ │ ✓ Decoders processed audio files                                               │ │
│ │ ✓ Parser extracted structured data                                             │ │
│ │ ✓ One or more messages successfully decoded                                     │ │
│ │                                                                                 │ │
│ │ Pipeline Failure Scenarios:                                                     │ │
│ │ ✗ No RTL-SDR device found                                                      │ │
│ │ ✗ No signals present on target frequency                                       │ │
│ │ ✗ Signal quality too poor for decoding                                         │ │
│ │ ✗ Hardware/software configuration issues                                       │ │
│ └─────────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              END - RESULTS READY                                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ User can now:                                                                       │
│ • Analyze decoded messages in JSON/text format                                     │
│ • Review statistics and patterns                                                   │
│ • Adjust parameters and re-run                                                     │
│ • Archive session data for later analysis                                          │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
RTL-SDR Hardware (460.800 MHz)
  │
  │ RF Signal
  ▼
┌─────────────────┐
│   rtl_fm        │ ◄── USB Interface
│   Demodulator   │
└─────────────────┘
  │
  │ Raw Audio Stream (2.4 MSPS)
  ▼
┌─────────────────┐
│   sox           │
│   Audio Proc.   │
└─────────────────┘
  │
  │ WAV File (22.05 kHz)
  ▼
┌─────────────────┐     ┌─────────────────┐
│   multimon-ng   │     │   direwolf      │
│   Decoder       │     │   Decoder       │
└─────────────────┘     └─────────────────┘
  │                       │
  │ AFSK1200/APRS Text   │ Timestamped Text
  ▼                       ▼
┌─────────────────────────────────┐
│        parse_output.py          │
│        Python Parser            │
└─────────────────────────────────┘
  │
  │ Structured Data
  ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   JSON Output   │  │   Text Report   │  │   Statistics    │
│   (Machine)     │  │   (Human)       │  │   (Summary)     │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

## Command Flow Options

### Option 1: Complete Automated Pipeline

```bash
docker compose run --rm rtl-decoder /app/scripts/pipeline.sh [freq] [duration]
```

**Flow:** All steps executed automatically in sequence

### Option 2: Manual Step-by-Step

```bash
# Start interactive session
docker compose run --rm rtl-decoder bash

# Inside container:
/app/scripts/rtl_to_wav.sh 460.800M 2400000 60 /app/output capture.wav
/app/scripts/decode_afsk.sh /app/output/capture.wav /app/output/decoded.txt
python3 /app/scripts/parse_output.py /app/output/decoded.txt --format json
```

**Flow:** User controls each step individually

### Option 3: Custom Parameters

```bash
docker compose run --rm rtl-decoder /app/scripts/pipeline.sh 461.000M 120 /app/output 2400000
```

**Flow:** Automated with custom frequency, duration, output directory, and sample rate

## Error Handling & Recovery Points

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Step Failed   │───▶│   Error Check   │───▶│   Suggested     │
│                 │    │   & Diagnosis   │    │   Recovery      │
└─────────────────┘    └─────────────────┘    └─────────────────┘

RTL-SDR Not Found ────────────────────────────────▶ Check USB connection, permissions
No Signals Decoded ───────────────────────────────▶ Verify frequency, increase duration
Poor Signal Quality ──────────────────────────────▶ Improve antenna, reduce interference
Docker Build Fails ───────────────────────────────▶ Check dependencies, internet connection
```

This process flow shows how your RTL-SDR AFSK1200 decoder transforms RF signals into structured, analyzable data through a robust, multi-stage pipeline with error handling and multiple output formats.
