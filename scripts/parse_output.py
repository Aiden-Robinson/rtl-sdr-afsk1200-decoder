#!/usr/bin/env python3
"""
AFSK1200 and APRS Message Parser

This script parses the output from multimon-ng and direwolf decoders,
extracts APRS and AFSK1200 messages, and formats them as JSON or text.
"""

import re
import json
import argparse
import sys
from datetime import datetime
from typing import List, Dict, Optional, Any


class AFSKParser:
    """Parser for AFSK1200 and APRS messages from decoder output."""
    
    def __init__(self):
        # Regex patterns for different message types
        self.patterns = {
            'afsk1200': re.compile(r'AFSK1200:\s*(.+)'),
            'aprs': re.compile(r'APRS:\s*(.+)'),
            'direwolf': re.compile(r'^\[(\d+\.\d+)\]\s*(.+)'),
            'timestamp': re.compile(r'\[(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\]'),
        }
        
        # APRS message type patterns
        self.aprs_patterns = {
            'position': re.compile(r'([A-Z0-9-]+)>([A-Z0-9,-]+):([!=/@])([0-9]{4}\.[0-9]{2}[NS])[\\\/]([0-9]{5}\.[0-9]{2}[EW])'),
            'message': re.compile(r'([A-Z0-9-]+)>([A-Z0-9,-]+)::([A-Z0-9-]{1,9})\s*:(.+)'),
            'status': re.compile(r'([A-Z0-9-]+)>([A-Z0-9,-]+):>(.+)'),
            'weather': re.compile(r'([A-Z0-9-]+)>([A-Z0-9,-]+):.*_(\d{3}/\d{3}g\d{3}t\d{3})'),
        }
    
    def parse_file(self, filename: str) -> List[Dict[str, Any]]:
        """Parse decoder output file and extract messages."""
        messages = []
        
        try:
            with open(filename, 'r', encoding='utf-8', errors='ignore') as file:
                lines = file.readlines()
        except FileNotFoundError:
            print(f"ERROR: File '{filename}' not found")
            return messages
        except Exception as e:
            print(f"ERROR: Failed to read file '{filename}': {e}")
            return messages
        
        for line_num, line in enumerate(lines, 1):
            line = line.strip()
            if not line:
                continue
            
            # Try to parse different message types
            message = self._parse_line(line, line_num)
            if message:
                messages.append(message)
        
        return messages
    
    def _parse_line(self, line: str, line_num: int) -> Optional[Dict[str, Any]]:
        """Parse a single line for AFSK/APRS messages."""
        
        # Try AFSK1200 pattern
        match = self.patterns['afsk1200'].search(line)
        if match:
            return self._parse_afsk_message(match.group(1), line_num)
        
        # Try APRS pattern
        match = self.patterns['aprs'].search(line)
        if match:
            return self._parse_aprs_message(match.group(1), line_num)
        
        # Try Direwolf pattern
        match = self.patterns['direwolf'].search(line)
        if match:
            timestamp = float(match.group(1))
            message = match.group(2)
            return self._parse_direwolf_message(message, timestamp, line_num)
        
        return None
    
    def _parse_afsk_message(self, message: str, line_num: int) -> Dict[str, Any]:
        """Parse AFSK1200 message."""
        return {
            'type': 'AFSK1200',
            'line': line_num,
            'timestamp': datetime.now().isoformat(),
            'raw_message': message,
            'parsed': self._try_parse_aprs_content(message)
        }
    
    def _parse_aprs_message(self, message: str, line_num: int) -> Dict[str, Any]:
        """Parse APRS message."""
        parsed = self._try_parse_aprs_content(message)
        
        return {
            'type': 'APRS',
            'line': line_num,
            'timestamp': datetime.now().isoformat(),
            'raw_message': message,
            'parsed': parsed
        }
    
    def _parse_direwolf_message(self, message: str, timestamp: float, line_num: int) -> Dict[str, Any]:
        """Parse Direwolf decoder message."""
        return {
            'type': 'DIREWOLF',
            'line': line_num,
            'timestamp': datetime.fromtimestamp(timestamp).isoformat(),
            'raw_message': message,
            'parsed': self._try_parse_aprs_content(message)
        }
    
    def _try_parse_aprs_content(self, message: str) -> Dict[str, Any]:
        """Try to parse APRS message content."""
        result = {
            'message_type': 'unknown',
            'source_call': None,
            'destination': None,
            'path': None,
            'data': None
        }
        
        # Try position report
        match = self.aprs_patterns['position'].search(message)
        if match:
            result.update({
                'message_type': 'position',
                'source_call': match.group(1),
                'destination': match.group(2),
                'symbol': match.group(3),
                'latitude': match.group(4),
                'longitude': match.group(5)
            })
            return result
        
        # Try message
        match = self.aprs_patterns['message'].search(message)
        if match:
            result.update({
                'message_type': 'message',
                'source_call': match.group(1),
                'destination': match.group(2),
                'addressee': match.group(3),
                'text': match.group(4)
            })
            return result
        
        # Try status
        match = self.aprs_patterns['status'].search(message)
        if match:
            result.update({
                'message_type': 'status',
                'source_call': match.group(1),
                'destination': match.group(2),
                'status_text': match.group(3)
            })
            return result
        
        # Try weather
        match = self.aprs_patterns['weather'].search(message)
        if match:
            result.update({
                'message_type': 'weather',
                'source_call': match.group(1),
                'destination': match.group(2),
                'weather_data': match.group(3)
            })
            return result
        
        # Generic parsing for source>dest format
        if '>' in message and ':' in message:
            try:
                header, data = message.split(':', 1)
                if '>' in header:
                    source, dest_path = header.split('>', 1)
                    result.update({
                        'source_call': source.strip(),
                        'destination': dest_path.strip(),
                        'data': data.strip()
                    })
            except:
                pass
        
        result['data'] = message
        return result


def main():
    """Main function to parse command line arguments and process files."""
    parser = argparse.ArgumentParser(
        description='Parse AFSK1200 and APRS messages from decoder output',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 parse_output.py decoded.txt
  python3 parse_output.py decoded.txt --format json --output results.json
  python3 parse_output.py *.txt --summary
        """
    )
    
    parser.add_argument('files', nargs='+', help='Input files to parse')
    parser.add_argument('--format', choices=['text', 'json'], default='text',
                        help='Output format (default: text)')
    parser.add_argument('--output', help='Output file (default: stdout)')
    parser.add_argument('--summary', action='store_true',
                        help='Show summary statistics only')
    parser.add_argument('--filter-type', choices=['AFSK1200', 'APRS', 'DIREWOLF'],
                        help='Filter by message type')
    
    args = parser.parse_args()
    
    # Initialize parser
    afsk_parser = AFSKParser()
    all_messages: List[Dict[str, Any]] = []
    
    # Process all input files
    for filename in args.files:
        print(f"Processing {filename}...", file=sys.stderr)
        messages = afsk_parser.parse_file(filename)
        
        # Add filename to each message
        for msg in messages:
            msg['source_file'] = filename
        
        all_messages.extend(messages)
    
    # Filter by type if requested
    if args.filter_type:
        all_messages = [msg for msg in all_messages if msg['type'] == args.filter_type]
    
    # Generate output
    if args.summary:
        output = generate_summary(all_messages)
    elif args.format == 'json':
        output = json.dumps(all_messages, indent=2, ensure_ascii=False)
    else:
        output = format_text_output(all_messages)
    
    # Write output
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(output)
        print(f"Output written to {args.output}", file=sys.stderr)
    else:
        print(output)


def generate_summary(messages: List[Dict[str, Any]]) -> str:
    """Generate summary statistics."""
    total = len(messages)
    by_type = {}
    by_source = {}
    
    for msg in messages:
        msg_type = msg['type']
        by_type[msg_type] = by_type.get(msg_type, 0) + 1
        
        source = msg.get('parsed', {}).get('source_call', 'Unknown')
        by_source[source] = by_source.get(source, 0) + 1
    
    summary = f"""
=== AFSK1200 Decoder Summary ===
Total messages: {total}

By message type:
"""
    for msg_type, count in sorted(by_type.items()):
        summary += f"  {msg_type}: {count}\n"
    
    summary += "\nTop 10 sources:\n"
    for source, count in sorted(by_source.items(), key=lambda x: x[1], reverse=True)[:10]:
        summary += f"  {source}: {count}\n"
    
    return summary.strip()


def format_text_output(messages: List[Dict[str, Any]]) -> str:
    """Format messages as readable text."""
    output = []
    
    for i, msg in enumerate(messages, 1):
        output.append(f"\n=== Message {i} ===")
        output.append(f"Type: {msg['type']}")
        output.append(f"Source file: {msg['source_file']}")
        output.append(f"Line: {msg['line']}")
        output.append(f"Timestamp: {msg['timestamp']}")
        output.append(f"Raw: {msg['raw_message']}")
        
        parsed = msg.get('parsed', {})
        if parsed.get('source_call'):
            output.append(f"From: {parsed['source_call']}")
        if parsed.get('destination'):
            output.append(f"To: {parsed['destination']}")
        if parsed.get('message_type') != 'unknown':
            output.append(f"APRS Type: {parsed['message_type']}")
        
        # Add specific fields based on message type
        if parsed.get('message_type') == 'position':
            output.append(f"Position: {parsed.get('latitude', 'N/A')}, {parsed.get('longitude', 'N/A')}")
        elif parsed.get('message_type') == 'message':
            output.append(f"To: {parsed.get('addressee', 'N/A')}")
            output.append(f"Text: {parsed.get('text', 'N/A')}")
    
    return '\n'.join(output)


if __name__ == '__main__':
    main()
