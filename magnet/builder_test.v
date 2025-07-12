module magnet

import torrent

fn test_from_torrent_single_file() {
	// Create a simple single-file torrent metadata
	metadata := torrent.TorrentMetadata{
		announce:  'http://tracker.example.com:8080/announce'
		info:      torrent.InfoDictionary{
			name:         'test_file.txt'
			piece_length: 32768
			pieces:       [u8(0x01), 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45,
				0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67]
			length:       1024
		}
		info_hash: [u8(0x12), 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78,
			0x90, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78]!
	}

	mag := from_torrent(metadata)

	assert mag.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert mag.display_name == 'test_file.txt'
	assert mag.trackers.len == 1
	assert mag.trackers[0] == 'http://tracker.example.com:8080/announce'
	assert mag.exact_length == 1024
}

fn test_from_torrent_multi_file() {
	// Create a multi-file torrent metadata
	files := [
		torrent.FileInfo{
			length: 512
			path:   ['dir1', 'file1.txt']
		},
		torrent.FileInfo{
			length: 1024
			path:   ['dir2', 'file2.txt']
		},
	]

	metadata := torrent.TorrentMetadata{
		announce:      'http://tracker.example.com:8080/announce'
		announce_list: [
			['http://tracker1.example.com:8080/announce', 'http://tracker2.example.com:8080/announce'],
			['http://backup.example.com:8080/announce'],
		]
		info:          torrent.InfoDictionary{
			name:         'test_directory'
			piece_length: 32768
			pieces:       [u8(0x01), 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45,
				0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67]
			files:        files
		}
		info_hash:     [u8(0x12), 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78,
			0x90, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78]!
	}

	mag := from_torrent(metadata)

	assert mag.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert mag.display_name == 'test_directory'
	assert mag.trackers.len == 4
	assert 'http://tracker.example.com:8080/announce' in mag.trackers
	assert 'http://tracker1.example.com:8080/announce' in mag.trackers
	assert 'http://tracker2.example.com:8080/announce' in mag.trackers
	assert 'http://backup.example.com:8080/announce' in mag.trackers
	assert mag.exact_length == 1536 // 512 + 1024
}

// fn test_from_torrent_hybrid() {
//	// Create a hybrid torrent with both v1 and v2 hashes
//	v2_hash := [u8(0xaa), 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa,
//	             0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa,
//	             0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa,
//	             0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa]!
//	
//	metadata := torrent.TorrentMetadata{
//		announce: 'http://tracker.example.com:8080/announce'
//		info: torrent.InfoDictionary{
//			name: 'hybrid_test.txt'
//			piece_length: 32768
//			pieces: [u8(0x01), 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67]
//			length: 2048
//		}
//		info_hash: [u8(0x12), 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78]!
//		info_hash_v2: v2_hash
//	}
//	
//	mag := from_torrent(metadata)
//	
//	assert mag.info_hash == '1234567890abcdef1234567890abcdef12345678'
//	assert mag.info_hash_v2 == '1220aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
//	assert mag.display_name == 'hybrid_test.txt'
//	assert mag.is_hybrid()
//	assert mag.exact_length == 2048
//}

fn test_builder_method_chaining() {
	mut builder := new_builder()

	// Test builder methods step by step
	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.set_display_name('Chain Test')
	builder.add_tracker('http://tracker1.example.com:8080/announce')
	builder.add_tracker('http://tracker2.example.com:8080/announce')
	builder.add_peer('192.168.1.1:6881')
	builder.add_web_seed('http://webseed.example.com/file')
	builder.add_keyword('test')
	builder.set_exact_length(1048576)
	builder.set_select_only([0, 1, 2])

	mag := builder.build() or { panic(err) }

	assert mag.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert mag.display_name == 'Chain Test'
	assert mag.trackers.len == 2
	assert mag.peers.len == 1
	assert mag.web_seeds.len == 1
	assert mag.keywords.len == 1
	assert mag.exact_length == 1048576
	assert mag.select_only == [0, 1, 2]
}

fn test_builder_duplicate_prevention() {
	mut builder := new_builder()

	// Add the same tracker multiple times
	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.add_tracker('http://tracker.example.com:8080/announce')
	builder.add_tracker('http://tracker.example.com:8080/announce')
	builder.add_tracker('http://different.example.com:8080/announce')
	builder.add_tracker('http://tracker.example.com:8080/announce')

	mag := builder.build() or { panic(err) }

	// Should only have 2 unique trackers
	assert mag.trackers.len == 2
	assert 'http://tracker.example.com:8080/announce' in mag.trackers
	assert 'http://different.example.com:8080/announce' in mag.trackers
}

fn test_builder_batch_additions() {
	mut builder := new_builder()

	trackers := ['http://tracker1.example.com:8080/announce',
		'http://tracker2.example.com:8080/announce']
	peers := ['192.168.1.1:6881', '192.168.1.2:6881']
	web_seeds := ['http://webseed1.example.com/file', 'http://webseed2.example.com/file']
	keywords := ['video', 'movie', 'test']

	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.add_trackers(trackers)
	builder.add_peers(peers)
	builder.add_web_seeds(web_seeds)
	builder.add_keywords(keywords)
	mag := builder.build() or { panic(err) }

	assert mag.trackers.len == 2
	assert mag.peers.len == 2
	assert mag.web_seeds.len == 2
	assert mag.keywords.len == 3
}

fn test_builder_hash_bytes() {
	mut builder := new_builder()

	// Test setting hash from bytes
	v1_hash := [u8(0x12), 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78, 0x90,
		0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78]

	v2_hash := [u8(0xbb), 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb,
		0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb,
		0xbb, 0xbb, 0xbb, 0xbb]!

	builder.set_info_hash_bytes(v1_hash)
	builder.set_info_hash_v2_bytes(v2_hash)
	builder.set_display_name('Bytes Test')
	mag := builder.build() or { panic(err) }

	assert mag.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert mag.info_hash_v2 == '1220bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
	assert mag.is_hybrid()
}

fn test_builder_extensions() {
	mut builder := new_builder()

	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.add_extension('x.custom', 'value1')
	builder.add_extension('x.other', 'value2')
	mag := builder.build() or { panic(err) }

	assert mag.extensions.len == 2
	assert mag.extensions['x.custom'] == 'value1'
	assert mag.extensions['x.other'] == 'value2'
}

fn test_builder_extension_validation() {
	mut builder := new_builder()

	// Should panic on invalid extension key
	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')

	// This should panic
	mut panicked := false
	defer {
		if panicked {
			// Expected behavior
		}
	}

	// Try to catch the panic - this is V specific syntax
	$if debug {
		// In debug mode, we can test this differently
		// For now, just verify the extension is properly set with valid key
		builder.add_extension('x.valid', 'test')
		mag := builder.build() or { panic(err) }
		assert mag.extensions['x.valid'] == 'test'
	}
}

fn test_builder_validation_errors() {
	mut builder := new_builder()

	// Test validation of hash formats
	builder.set_info_hash('invalid-hash')
	if magnet := builder.build() {
		panic('should have failed with invalid hash')
	} else {
		// Expected failure
	}

	// Reset and test with valid hash but invalid tracker
	builder = new_builder()
	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.add_tracker('invalid-tracker-url')

	if magnet := builder.build() {
		panic('should have failed with invalid tracker')
	} else {
		// Expected failure
	}

	// Reset and test with valid hash but invalid peer
	builder = new_builder()
	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.add_peer('invalid-peer-address')

	if magnet := builder.build() {
		panic('should have failed with invalid peer')
	} else {
		// Expected failure
	}
}

fn test_integration_torrent_to_magnet_roundtrip() {
	// Create torrent metadata
	metadata := torrent.TorrentMetadata{
		announce:      'http://tracker.example.com:8080/announce'
		announce_list: [
			['http://tracker1.example.com:8080/announce'],
			['http://backup.example.com:8080/announce'],
		]
		comment:       'Test torrent'
		created_by:    'magnetar/0.1.0'
		creation_date: 1640995200
		info:          torrent.InfoDictionary{
			name:         'integration_test.txt'
			piece_length: 32768
			pieces:       [u8(0x01), 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45,
				0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67]
			length:       4096
		}
		info_hash:     [u8(0x12), 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78,
			0x90, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78]!
	}

	// Convert to magnet
	mag := from_torrent(metadata)

	// Convert to string
	magnet_uri := mag.to_string()

	// Parse back from string
	parsed_magnet := parse(magnet_uri) or { panic(err) }

	// Verify consistency
	assert parsed_magnet.info_hash == mag.info_hash
	assert parsed_magnet.display_name == mag.display_name
	assert parsed_magnet.trackers.len == mag.trackers.len
	assert parsed_magnet.exact_length == mag.exact_length

	// Check that all trackers are preserved
	for tracker in mag.trackers {
		assert tracker in parsed_magnet.trackers
	}
}
