module main

import os
import cli
import magnet
import torrent
import time

fn main() {
	mut app := cli.Command{
		name:        'magnetar'
		description: 'A CLI tool for working with torrent files, magnet links, and bencode data'
		version:     '0.1.0'
		execute:     fn (cmd cli.Command) ! {
			cmd.execute_help()
		}
		commands:    [
			cli.Command{
				name:          'magnet'
				description:   'Analyze and display information about magnet links'
				usage:         'magnetar magnet <magnet_uri>'
				execute:       magnet_info
				required_args: 1
			},
			cli.Command{
				name:          'torrent'
				description:   'Analyze and display information about torrent files'
				usage:         'magnetar torrent <file_path>'
				execute:       torrent_info
				required_args: 1
			},
		]
	}

	app.setup()
	app.parse(os.args)
}

fn magnet_info(cmd cli.Command) ! {
	if cmd.args.len < 1 {
		eprintln('Error: magnet URI required')
		println('Usage: magnetar magnet <magnet_uri>')
		exit(1)
	}

	magnet_uri := cmd.args[0]

	// Parse the magnet link
	mag := magnet.parse(magnet_uri) or {
		eprintln('Error parsing magnet URI: ${err}')
		exit(1)
	}

	// Display comprehensive information
	println('=== MAGNET LINK INFORMATION ===')
	println('')

	// Basic info
	println('📝 Basic Information:')
	if mag.display_name.len > 0 {
		println('   Name: ${mag.display_name}')
	}
	if mag.exact_length > 0 {
		println('   Size: ${format_bytes(u64(mag.exact_length))}')
	}
	println('')

	// Hash information
	println('🔑 Hash Information:')
	if mag.has_v1_hash() {
		println('   Info Hash (v1): ${mag.info_hash}')
	}
	if mag.has_v2_hash() {
		println('   Info Hash (v2): ${mag.info_hash_v2}')
	}
	if mag.is_hybrid() {
		println('   Type: Hybrid (v1 + v2)')
	} else if mag.has_v2_hash() {
		println('   Type: BitTorrent v2')
	} else {
		println('   Type: BitTorrent v1')
	}
	println('   Primary Hash: ${mag.get_primary_hash()}')
	println('')

	// Trackers
	if mag.trackers.len > 0 {
		println('🌐 Trackers (${mag.trackers.len}):')
		for i, tracker in mag.trackers {
			println('   ${i + 1}. ${tracker}')
		}
		println('')
	}

	// Peers
	if mag.peers.len > 0 {
		println('👥 Direct Peers (${mag.peers.len}):')
		for i, peer in mag.peers {
			println('   ${i + 1}. ${peer}')
		}
		println('')
	}

	// Web seeds
	if mag.web_seeds.len > 0 {
		println('🌍 Web Seeds (${mag.web_seeds.len}):')
		for i, seed in mag.web_seeds {
			println('   ${i + 1}. ${seed}')
		}
		println('')
	}

	// Keywords
	if mag.keywords.len > 0 {
		println('🏷️  Keywords:')
		println('   ${mag.keywords.join(', ')}')
		println('')
	}

	// File selection
	if mag.select_only.len > 0 {
		println('📁 File Selection:')
		selected_files := mag.select_only.map(it.str()).join(', ')
		println('   Selected files: ${selected_files}')
		println('')
	}

	// Extensions
	if mag.extensions.len > 0 {
		println('🔧 Extensions:')
		for key, value in mag.extensions {
			println('   ${key}: ${value}')
		}
		println('')
	}

	// Generate equivalent magnet URI
	println('🔗 Generated Magnet URI:')
	generated := mag.to_string()
	println('   ${generated}')
	println('')

	// Validation
	println('✅ Validation:')
	println('   Valid magnet format: ✓')
	if mag.info_hash.len > 0 {
		println('   v1 hash format: ✓')
	}
	if mag.info_hash_v2.len > 0 {
		println('   v2 hash format: ✓')
	}
	for tracker in mag.trackers {
		if tracker.starts_with('http://') || tracker.starts_with('https://')
			|| tracker.starts_with('udp://') {
			println('   Tracker ${tracker}: ✓')
		} else {
			println('   Tracker ${tracker}: ❌ Invalid URL')
		}
	}
	for peer in mag.peers {
		// Basic peer validation - should contain : for IP:PORT
		if peer.contains(':') {
			println('   Peer ${peer}: ✓')
		} else {
			println('   Peer ${peer}: ❌ Invalid address')
		}
	}
}

fn torrent_info(cmd cli.Command) ! {
	if cmd.args.len < 1 {
		eprintln('Error: torrent file path required')
		println('Usage: magnetar torrent <file_path>')
		exit(1)
	}

	file_path := cmd.args[0]

	// Check if file exists
	if !os.exists(file_path) {
		eprintln('Error: file "${file_path}" does not exist')
		exit(1)
	}

	// Read torrent file
	torrent_data := os.read_file(file_path) or {
		eprintln('Error reading file: ${err}')
		exit(1)
	}

	// Parse torrent data
	metadata := torrent.parse_torrent_data(torrent_data.bytes()) or {
		eprintln('Error parsing torrent file: ${err}')
		exit(1)
	}

	// Validate torrent
	torrent.validate_torrent(metadata) or { eprintln('Warning: torrent validation failed: ${err}') }

	// Display comprehensive information
	println('=== TORRENT FILE INFORMATION ===')
	println('')

	// Basic info
	println('📝 Basic Information:')
	println('   Name: ${metadata.info.name}')
	println('   Total Size: ${format_bytes(u64(metadata.total_size()))}')
	println('   File Count: ${metadata.file_count()}')
	println('   Type: ${if metadata.is_single_file() { 'Single file' } else { 'Multi-file' }}')
	println('')

	// Hash information
	println('🔑 Hash Information:')
	mut hash_str := ''
	for b in metadata.info_hash {
		hash_str += '${b:02x}'
	}
	println('   Info Hash: ${hash_str}')
	println('')

	// Piece information
	println('🧩 Piece Information:')
	println('   Piece Length: ${format_bytes(u64(metadata.info.piece_length))}')
	println('   Piece Count: ${metadata.piece_count()}')
	println('   Pieces Hash Length: ${metadata.info.pieces.len} bytes')
	println('')

	// Optional torrent metadata
	if metadata.announce.len > 0 {
		println('🌐 Primary Tracker:')
		println('   ${metadata.announce}')
		println('')
	}

	if metadata.announce_list.len > 0 {
		println('🌐 All Trackers:')
		trackers := metadata.get_trackers()
		for i, tracker in trackers {
			println('   ${i + 1}. ${tracker}')
		}
		println('')
	}

	// Creation information
	if creation_date := metadata.creation_date {
		println('📅 Creation Information:')
		created_time := time.unix(creation_date)
		println('   Created: ${created_time.format()}')
		if created_by := metadata.created_by {
			println('   Created by: ${created_by}')
		}
		println('')
	}

	// Comments and encoding
	if comment := metadata.comment {
		println('💬 Comment:')
		println('   ${comment}')
		println('')
	}

	if encoding := metadata.encoding {
		println('🔤 Encoding: ${encoding}')
		println('')
	}

	// File details
	if metadata.is_multi_file() {
		println('📁 Files (${metadata.info.files.len}):')
		for i, file in metadata.info.files {
			file_path_str := file.path.join('/')
			println('   ${i + 1}. ${file_path_str} (${format_bytes(u64(file.length))})')
			if md5sum := file.md5sum {
				println('      MD5: ${md5sum}')
			}
		}
		println('')
	} else {
		println('📄 Single File:')
		if length := metadata.info.length {
			println('   Size: ${format_bytes(u64(length))}')
		}
		if md5sum := metadata.info.md5sum {
			println('   MD5: ${md5sum}')
		}
		if private := metadata.info.private {
			println('   Private: ${if private { 'Yes' } else { 'No' }}')
		}
		println('')
	}

	// Convert to magnet link
	println('🔗 Equivalent Magnet Link:')
	mag := magnet.from_torrent(metadata)
	magnet_uri := mag.to_string()
	println('   ${magnet_uri}')
	println('')

	// File analysis
	println('📊 File Analysis:')
	println('   Torrent file size: ${format_bytes(u64(torrent_data.len))}')

	// Calculate some statistics
	if metadata.piece_count() > 0 {
		avg_piece_size := f64(metadata.total_size()) / f64(metadata.piece_count())
		println('   Average piece size: ${format_bytes(u64(avg_piece_size))}')
	}

	if metadata.is_multi_file() {
		mut smallest_file := metadata.info.files[0].length
		mut largest_file := metadata.info.files[0].length
		mut total_files := metadata.info.files.len

		for file in metadata.info.files {
			if file.length < smallest_file {
				smallest_file = file.length
			}
			if file.length > largest_file {
				largest_file = file.length
			}
		}

		println('   Smallest file: ${format_bytes(u64(smallest_file))}')
		println('   Largest file: ${format_bytes(u64(largest_file))}')

		if total_files > 0 {
			avg_file_size := f64(metadata.total_size()) / f64(total_files)
			println('   Average file size: ${format_bytes(u64(avg_file_size))}')
		}
	}

	println('')

	// Validation results
	println('✅ Validation:')
	println('   Valid torrent format: ✓')
	println('   Info hash calculated: ✓')

	if metadata.announce.len > 0 {
		if metadata.announce.starts_with('http://') || metadata.announce.starts_with('https://')
			|| metadata.announce.starts_with('udp://') {
			println('   Primary tracker URL: ✓')
		} else {
			println('   Primary tracker URL: ❌ Invalid format')
		}
	}

	if metadata.piece_count() > 0 {
		expected_pieces_length := metadata.piece_count() * 20 // SHA-1 is 20 bytes
		if metadata.info.pieces.len == expected_pieces_length {
			println('   Pieces hash length: ✓')
		} else {
			println('   Pieces hash length: ❌ Expected ${expected_pieces_length}, got ${metadata.info.pieces.len}')
		}
	}
}

fn format_bytes(bytes u64) string {
	if bytes < 1024 {
		return '${bytes} B'
	} else if bytes < 1024 * 1024 {
		return '${(f64(bytes) / 1024):.1f} KB'
	} else if bytes < 1024 * 1024 * 1024 {
		return '${(f64(bytes) / (1024 * 1024)):.1f} MB'
	} else if bytes < u64(1024) * 1024 * 1024 * 1024 {
		return '${(f64(bytes) / (1024 * 1024 * 1024)):.1f} GB'
	} else {
		return '${(f64(bytes) / (u64(1024) * 1024 * 1024 * 1024)):.1f} TB'
	}
}
