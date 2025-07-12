# Magnetar

A high-performance BitTorrent parsing and manipulation library written in V. Magnetar provides zero-dependency, memory-safe operations for working with torrent files, bencode data, and magnet links.

## Features

- **🚀 High Performance**: Zero-allocation parsing where possible, optimized for speed
- **🔒 Memory Safe**: Leverages V's memory safety and type system
- **📦 Zero Dependencies**: Pure V implementation with no external dependencies
- **🔗 Magnet Links**: Full support for magnet URI parsing and generation (BEP-9)
- **📄 Torrent Files**: Parse and create .torrent files (BEP-3, BEP-52)
- **🔢 Bencode**: Complete bencode encoding/decoding implementation
- **✅ Spec Compliant**: Follows BitTorrent protocol specifications

## Modules

### Bencode
Encode and decode bencode format (BitTorrent's data serialization):
- Strings, integers, lists, and dictionaries
- Streaming decode for large files
- Position tracking for error reporting

### Magnet
Parse and generate magnet URIs with full BEP-9 support:
- Info hashes (SHA-1 and SHA-256)
- Tracker URLs and peer addresses
- Web seeds and exact sources
- File selection and metadata

### Torrent
Work with .torrent files:
- Single-file and multi-file torrents
- BitTorrent v1 and v2 support
- Info hash calculation
- Metadata extraction

## Installation

Add Magnetar to your V project:

```bash
v install https://github.com/watzon/magnetar
```

Or clone directly:

```bash
git clone https://github.com/watzon/magnetar.git
```

## Quick Start

### Parsing Magnet Links

```v
import magnet

// Parse a magnet URI
magnet_uri := 'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&dn=Example%20File&tr=http://tracker.example.com:8080/announce'

mag := magnet.parse(magnet_uri) or {
    eprintln('Failed to parse magnet: ${err}')
    return
}

println('Info hash: ${mag.info_hash}')
println('Display name: ${mag.display_name}')
println('Trackers: ${mag.trackers}')
```

### Creating Magnet Links

```v
import magnet

// Using the builder pattern
mut builder := magnet.new_builder()
builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
builder.set_display_name('My File')
builder.add_tracker('http://tracker.example.com:8080/announce')
builder.add_tracker('udp://backup.tracker.com:8080')

mag := builder.build() or {
    eprintln('Failed to build magnet: ${err}')
    return
}

magnet_uri := mag.to_string()
println('Generated magnet: ${magnet_uri}')
```

### Convenience Functions

```v
import magnet

// Simple magnet with just hash and name
mag1 := magnet.create_simple_magnet(
    '1234567890abcdef1234567890abcdef12345678',
    'Simple File'
) or { panic(err) }

// Magnet with tracker
mag2 := magnet.create_magnet_with_tracker(
    '1234567890abcdef1234567890abcdef12345678',
    'File with Tracker',
    'http://tracker.example.com:8080/announce'
) or { panic(err) }

// Hybrid torrent (v1 + v2)
mag3 := magnet.create_hybrid_magnet(
    '1234567890abcdef1234567890abcdef12345678',        // v1 hash
    '1220d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2', // v2 hash
    'Hybrid Torrent'
) or { panic(err) }
```

### Working with Torrents

```v
import torrent
import magnet
import os

// Parse a torrent file
torrent_data := os.read_file('example.torrent') or { panic(err) }
metadata := torrent.parse_torrent_data(torrent_data.bytes()) or {
    eprintln('Failed to parse torrent: ${err}')
    return
}

println('Torrent name: ${metadata.info.name}')
println('Piece length: ${metadata.info.piece_length}')
println('Total size: ${metadata.total_size()}')

// Convert torrent to magnet link
mag := magnet.from_torrent(metadata)
magnet_uri := mag.to_string()
println('Magnet URI: ${magnet_uri}')
```

### Bencode Operations

```v
import bencode

// Create bencode data structures
announce := bencode.BencodeString{ value: 'http://tracker.example.com:8080/announce'.bytes() }
name := bencode.BencodeString{ value: 'example.txt'.bytes() }
length := bencode.BencodeInteger{ value: 1024 }

mut info_dict := bencode.BencodeDictionary{ pairs: map[string]bencode.BencodeValue{} }
info_dict.pairs['name'] = name
info_dict.pairs['length'] = length

mut root_dict := bencode.BencodeDictionary{ pairs: map[string]bencode.BencodeValue{} }
root_dict.pairs['announce'] = announce
root_dict.pairs['info'] = info_dict

// Encode the data
encoded := bencode.encode(root_dict)
println('Encoded: ${encoded}')

// Decode it back
original_data := bencode.decode(encoded) or { panic(err) }
println('Decoded: ${original_data}')
```

## Advanced Usage

### Builder Pattern with All Parameters

```v
import magnet

mut builder := magnet.new_builder()

// Set hashes
builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
builder.set_info_hash_v2('1220d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2')

// Set metadata
builder.set_display_name('Complete Example')
builder.set_exact_length(1073741824) // 1GB

// Add trackers and peers
builder.add_tracker('http://tracker1.example.com:8080/announce')
builder.add_tracker('udp://tracker2.example.com:8080')
builder.add_peer('192.168.1.1:6881')
builder.add_peer('peer.example.com:6882')

// Add web seeds
builder.add_web_seed('http://webseed1.example.com/file')
builder.add_web_seed('http://webseed2.example.com/file')

// Add keywords
builder.add_keyword('video')
builder.add_keyword('movie')
builder.add_keyword('hd')

// Set file selection (download only specific files)
builder.set_select_only([0, 2, 4, 5, 6, 7]) // files 0, 2, and 4-7

// Add custom extensions
builder.add_extension('x.custom', 'custom_value')

mag := builder.build() or { panic(err) }
```

### Error Handling

```v
import magnet

// All parsing operations return Result types
magnet_uri := 'invalid-magnet-uri'

if mag := magnet.parse(magnet_uri) {
    println('Parsed successfully: ${mag.display_name}')
} else {
    eprintln('Parse error: ${err}')
    // Handle specific error types by checking message content
    if err.msg().contains('missing required field') {
        eprintln('Missing required info hash')
    } else if err.msg().contains('invalid hash') {
        eprintln('Invalid hash format')
    } else {
        eprintln('Other error: ${err}')
    }
}
```

### Validation

```v
import magnet

// Validate peer addresses
valid_peers := [
    '192.168.1.1:6881',      // IPv4
    'example.com:8080',       // hostname
    '[::1]:6881',            // IPv6
    '[2001:db8::1]:8080'     // IPv6 with port
]

for peer in valid_peers {
    if magnet.is_valid_peer_address(peer) {
        println('${peer} is valid')
    }
}
```

## Specifications Supported

- **[BEP-3](http://bittorrent.org/beps/bep_0003.html)**: The BitTorrent Protocol Specification
- **[BEP-9](http://bittorrent.org/beps/bep_0009.html)**: Extension for Peers to Send Metadata Files
- **[BEP-52](http://bittorrent.org/beps/bep_0052.html)**: The BitTorrent Protocol Specification v2

## API Reference

### Magnet Module

#### Types
- `MagnetLink`: Represents a parsed magnet URI with all parameters
- `MagnetBuilder`: Builder for constructing magnet links
- `MagnetError`: Error type for magnet operations

#### Functions
- `parse(uri string) !MagnetLink`: Parse magnet URI string
- `new_builder() MagnetBuilder`: Create new magnet builder
- `create_simple_magnet(hash, name string) !MagnetLink`: Quick magnet creation
- `create_magnet_with_tracker(hash, name, tracker string) !MagnetLink`: Magnet with tracker
- `create_hybrid_magnet(v1_hash, v2_hash, name string) !MagnetLink`: Hybrid v1/v2 magnet

#### MagnetLink Methods
- `to_string() string`: Generate magnet URI string
- `has_v1_hash() bool`: Check if has v1 info hash
- `has_v2_hash() bool`: Check if has v2 info hash
- `is_hybrid() bool`: Check if hybrid (both v1 and v2)
- `get_primary_hash() string`: Get primary info hash

### Torrent Module

#### Types
- `TorrentMetadata`: Complete torrent file metadata
- `InfoDictionary`: Torrent info section
- `FileInfo`: Individual file information

#### Functions
- `parse(data []u8) !TorrentMetadata`: Parse torrent file
- `create(info InfoDictionary) !TorrentMetadata`: Create new torrent

### Bencode Module

#### Functions
- `encode(data BencodeValue) ![]u8`: Encode to bencode
- `decode(data []u8) !BencodeValue`: Decode from bencode

## Performance

Magnetar is designed for high performance:

- **Zero-allocation parsing**: Minimizes memory allocations in hot paths
- **Streaming support**: Handle large files without loading everything into memory
- **Small binary size**: V's compilation produces compact executables
- **Fast compilation**: V's fast compilation speeds up development

## Testing

Run the test suite:

```bash
v test .
```

Run with detailed statistics:

```bash
v -stats test .
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changelog

### v0.1.0
- Initial release
- Magnet URI parsing and generation
- Basic torrent file support
- Bencode implementation
- Comprehensive test suite
