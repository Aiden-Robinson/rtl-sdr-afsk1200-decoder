# RTL-SDR AFSK1200 Decoder Pipeline

A complete Docker-based pipeline for capturing and decoding AFSK1200 signals (commonly used for APRS) using RTL-SDR dongles.

## Features

- **RTL-SDR Integration**: Direct capture from RTL-SDR dongles
- **Multiple Decoders**: Uses both multimon-ng and Direwolf for robust decoding
- **APRS Support**: Specialized parsing for APRS messages
- **Docker Containerized**: Easy deployment and consistent environment
- **Automated Pipeline**: Complete capture-to-decoded workflow
- **Multiple Output Formats**: JSON, text, and summary reports

## Prerequisites

### Hardware

- RTL-SDR dongle (RTL2832U-based)
- Appropriate antenna for target frequency
- USB port for RTL-SDR connection

### Software

- Docker and Docker Compose
- USB device access permissions

## Installation

1. **Clone or create the project:**

   ```bash
   git init afsk_decoder_pipeline
   cd afsk_decoder_pipeline
   ```

2. **Build the Docker image:**

   ```bash
   docker compose build
   ```

3. **Connect your RTL-SDR dongle** to a USB port

## Usage

### Quick Start

Run the complete pipeline with default settings (144.390 MHz APRS frequency):

```bash
docker compose run --rm rtl-decoder /app/scripts/pipeline.sh
```

### Custom Frequency and Duration

```bash
# Capture on 145.570 MHz for 120 seconds
docker compose run --rm rtl-decoder /app/scripts/pipeline.sh 145.570M 120
```

### Interactive Mode

Start an interactive session for manual control:

```bash
docker compose run --rm rtl-decoder bash
```

Then run individual components:

```bash
# Inside the container:

# 1. Capture audio (frequency, sample_rate, duration, output_dir, filename)
/app/scripts/rtl_to_wav.sh 144.390M 22050 60 /app/output capture.wav

# 2. Decode signals
/app/scripts/decode_afsk.sh /app/output/capture.wav /app/output/decoded.txt

# 3. Parse messages
python3 /app/scripts/parse_output.py /app/output/decoded.txt --format json --output /app/output/parsed.json
```

## Script Reference

### `rtl_to_wav.sh`

Captures FM signals from RTL-SDR and saves as WAV files.

**Usage:**

```bash
./rtl_to_wav.sh [frequency] [sample_rate] [duration] [output_dir] [filename]
```

**Parameters:**

- `frequency`: Target frequency (e.g., 144.390M)
- `sample_rate`: Audio sample rate (default: 22050)
- `duration`: Capture duration in seconds (default: 60)
- `output_dir`: Output directory (default: /app/output)
- `filename`: Output filename (default: auto-generated)

### `decode_afsk.sh`

Decodes AFSK1200 signals using multimon-ng and Direwolf.

**Usage:**

```bash
./decode_afsk.sh <input_wav_file> [output_file]
```

### `parse_output.py`

Parses decoder output and formats as JSON or text.

**Usage:**

```bash
python3 parse_output.py [files...] [options]
```

**Options:**

- `--format {text,json}`: Output format
- `--output FILE`: Output file (default: stdout)
- `--summary`: Show summary statistics only
- `--filter-type {AFSK1200,APRS,DIREWOLF}`: Filter by message type

### `pipeline.sh`

Complete automated pipeline from capture to parsed output.

**Usage:**

```bash
./pipeline.sh [frequency] [duration] [output_dir] [sample_rate]
```

## Common Frequencies

| Service    | Frequency   | Region        |
| ---------- | ----------- | ------------- |
| APRS       | 144.390 MHz | North America |
| APRS       | 144.800 MHz | Europe        |
| APRS       | 145.570 MHz | Australia     |
| Marine AIS | 161.975 MHz | Global        |
| Marine AIS | 162.025 MHz | Global        |

## Output Files

Each pipeline run creates a session directory with:

- `capture_TIMESTAMP.wav`: Raw audio capture
- `decoded_TIMESTAMP.txt`: Raw decoder output
- `parsed_TIMESTAMP.json`: Structured JSON data
- `parsed_TIMESTAMP.txt`: Human-readable text
- `summary_TIMESTAMP.txt`: Summary statistics

## Troubleshooting

### No RTL-SDR Device Found

1. **Check USB connection**: Ensure dongle is properly connected
2. **Verify permissions**: Docker needs USB device access
3. **Test device**: Run `rtl_test -t` inside container

### No Signals Decoded

1. **Verify frequency**: Check local APRS/AFSK frequency
2. **Antenna positioning**: Ensure good antenna placement
3. **Increase duration**: Try longer capture times
4. **Check gain**: Experiment with RTL-SDR gain settings

### Poor Signal Quality

1. **Improve antenna**: Use appropriate antenna for frequency
2. **Reduce interference**: Move away from noise sources
3. **Adjust filters**: Modify sox filtering parameters
4. **Check coax**: Ensure good connection and minimal loss

## Advanced Configuration

### Environment Variables

Set in `docker-compose.yml` or pass to container:

- `DEFAULT_FREQ`: Default frequency (default: 144.390M)
- `DEFAULT_SAMPLE_RATE`: Default sample rate (default: 22050)

### Custom Decoder Settings

Modify decoder parameters in the shell scripts:

**RTL-SDR settings (`rtl_to_wav.sh`):**

- `-g auto`: Gain (auto, or specific value like 20)
- `-E dc`: DC blocking
- `-F 9`: De-emphasis filter

**Multimon-ng settings (`decode_afsk.sh`):**

- `-a AFSK1200`: Decoder type
- `-A`: Print all packets
- `-u`: Flush output immediately

## Development

### Adding New Decoders

1. Install decoder in `Dockerfile`
2. Add decoding logic to `decode_afsk.sh`
3. Update parser patterns in `parse_output.py`

### Custom Message Parsing

Extend `AFSKParser` class in `parse_output.py`:

```python
# Add new regex patterns
self.patterns['new_type'] = re.compile(r'NEWTYPE:\s*(.+)')

# Add parsing logic
def _parse_new_type(self, message: str, line_num: int) -> Dict:
    # Custom parsing logic here
    pass
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

This project is provided as-is for educational and amateur radio use.

## Support

For issues and questions:

1. Check the troubleshooting section
2. Verify hardware setup
3. Test with known good signals
4. Review Docker logs for errors

## References

- [RTL-SDR Blog](https://www.rtl-sdr.com/)
- [APRS Specification](http://www.aprs.org/)
- [Multimon-ng Documentation](https://github.com/EliasOenal/multimon-ng)
- [Direwolf Documentation](https://github.com/wb2osz/direwolf)
