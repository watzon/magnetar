module magnet

fn test_parse_simple_magnet_uri() {
	magnet_uri := 'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&dn=Test%20File'

	result := parse(magnet_uri) or { panic(err) }

	assert result.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert result.display_name == 'Test File'
	assert result.trackers.len == 0
	assert result.peers.len == 0
}

fn test_parse_magnet_with_trackers() {
	magnet_uri := 'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&dn=Test%20File&tr=http://tracker1.example.com:8080/announce&tr=udp://tracker2.example.com:8080'

	result := parse(magnet_uri) or { panic(err) }

	assert result.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert result.display_name == 'Test File'
	assert result.trackers.len == 2
	assert 'http://tracker1.example.com:8080/announce' in result.trackers
	assert 'udp://tracker2.example.com:8080' in result.trackers
}

fn test_parse_magnet_with_peers() {
	magnet_uri := 'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&x.pe=192.168.1.1:6881&x.pe=peer.example.com:6882'

	result := parse(magnet_uri) or { panic(err) }

	assert result.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert result.peers.len == 2
	assert '192.168.1.1:6881' in result.peers
	assert 'peer.example.com:6882' in result.peers
}

fn test_parse_magnet_with_extended_parameters() {
	magnet_uri := 'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&dn=Test&xl=1073741824&ws=http://webseed.example.com/file&kt=video&kt=movie&so=0,2,4-7'

	result := parse(magnet_uri) or { panic(err) }

	assert result.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert result.display_name == 'Test'
	assert result.exact_length == 1073741824
	assert result.web_seeds.len == 1
	assert 'http://webseed.example.com/file' in result.web_seeds
	assert result.keywords.len == 2
	assert 'video' in result.keywords
	assert 'movie' in result.keywords
	assert result.select_only == [0, 2, 4, 5, 6, 7]
}

fn test_parse_magnet_v2_hash() {
	magnet_uri := 'magnet:?xt=urn:btmh:1220d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2&dn=Test%20V2'

	result := parse(magnet_uri) or { panic(err) }

	assert result.info_hash_v2 == '1220d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2'
	assert result.display_name == 'Test V2'
	assert result.has_v2_hash()
	assert !result.has_v1_hash()
}

fn test_parse_hybrid_magnet() {
	magnet_uri := 'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&xt=urn:btmh:1220d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2&dn=Hybrid%20Torrent'

	result := parse(magnet_uri) or { panic(err) }

	assert result.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert result.info_hash_v2 == '1220d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2'
	assert result.display_name == 'Hybrid Torrent'
	assert result.has_v1_hash()
	assert result.has_v2_hash()
	assert result.is_hybrid()
}

fn test_parse_base32_hash() {
	magnet_uri := 'magnet:?xt=urn:btih:MFRGG2LTMFAE4333MFAE4333MFAE4333&dn=Base32%20Test'

	result := parse(magnet_uri) or { panic(err) }

	assert result.info_hash == 'mfrgg2ltmfae4333mfae4333mfae4333'
	assert result.display_name == 'Base32 Test'
}

fn test_parse_magnet_with_extensions() {
	magnet_uri := 'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&x.custom=value&x.other=test'

	result := parse(magnet_uri) or { panic(err) }

	assert result.extensions.len == 2
	assert result.extensions['x.custom'] == 'value'
	assert result.extensions['x.other'] == 'test'
}

fn test_parse_select_only_ranges() {
	// Test individual indices
	indices1 := parse_select_only('0,2,5') or { panic(err) }
	assert indices1 == [0, 2, 5]

	// Test ranges
	indices2 := parse_select_only('1-3,7-9') or { panic(err) }
	assert indices2 == [1, 2, 3, 7, 8, 9]

	// Test mixed
	indices3 := parse_select_only('0,2-4,6,8-10') or { panic(err) }
	assert indices3 == [0, 2, 3, 4, 6, 8, 9, 10]
}

fn test_format_select_only() {
	// Test individual indices
	result1 := format_select_only([0, 2, 5])
	assert result1 == '0,2,5'

	// Test consecutive ranges
	result2 := format_select_only([1, 2, 3, 7, 8, 9])
	assert result2 == '1-3,7-9'

	// Test mixed
	result3 := format_select_only([0, 2, 3, 4, 6, 8, 9, 10])
	assert result3 == '0,2-4,6,8-10'
}

fn test_magnet_to_string() {
	mut mag_link := MagnetLink{
		info_hash:    '1234567890abcdef1234567890abcdef12345678'
		display_name: 'Test File'
		trackers:     ['http://tracker.example.com:8080/announce']
		peers:        ['192.168.1.1:6881']
		exact_length: 1048576
	}

	result := mag_link.to_string()

	assert result.contains('xt=urn:btih:1234567890abcdef1234567890abcdef12345678')
	assert result.contains('dn=Test+File')
	assert result.contains('tr=http%3A%2F%2Ftracker.example.com%3A8080%2Fannounce')
	assert result.contains('x.pe=192.168.1.1:6881')
	assert result.contains('xl=1048576')
}

fn test_magnet_to_string_hybrid() {
	mut mag_link := MagnetLink{
		info_hash:    '1234567890abcdef1234567890abcdef12345678'
		info_hash_v2: '1220d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2'
		display_name: 'Hybrid Test'
	}

	result := mag_link.to_string()

	assert result.contains('xt=urn:btih:1234567890abcdef1234567890abcdef12345678')
	assert result.contains('xt=urn:btmh:1220d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2')
	assert result.contains('dn=Hybrid+Test')
}

fn test_builder_simple() {
	mut builder := new_builder()
	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.set_display_name('Test File')
	mag := builder.build() or { panic(err) }

	assert mag.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert mag.display_name == 'Test File'
}

fn test_builder_with_trackers() {
	mut builder := new_builder()
	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.set_display_name('Test File')
	builder.add_tracker('http://tracker1.example.com:8080/announce')
	builder.add_tracker('udp://tracker2.example.com:8080')
	mag := builder.build() or { panic(err) }

	assert mag.trackers.len == 2
	assert 'http://tracker1.example.com:8080/announce' in mag.trackers
	assert 'udp://tracker2.example.com:8080' in mag.trackers
}

fn test_builder_hybrid() {
	mut builder := new_builder()
	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.set_info_hash_v2('1220d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2')
	builder.set_display_name('Hybrid Test')
	mag := builder.build() or { panic(err) }

	assert mag.is_hybrid()
	assert mag.get_primary_hash() == '1234567890abcdef1234567890abcdef12345678'
}

fn test_builder_with_all_parameters() {
	mut builder := new_builder()
	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.set_display_name('Complete Test')
	builder.add_tracker('http://tracker.example.com:8080/announce')
	builder.add_peer('192.168.1.1:6881')
	builder.add_web_seed('http://webseed.example.com/file')
	builder.add_keyword('test')
	builder.add_keyword('video')
	builder.set_exact_length(1073741824)
	builder.set_select_only([0, 2, 4, 5, 6, 7])
	builder.add_extension('x.custom', 'value')
	mag := builder.build() or { panic(err) }

	assert mag.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert mag.display_name == 'Complete Test'
	assert mag.trackers.len == 1
	assert mag.peers.len == 1
	assert mag.web_seeds.len == 1
	assert mag.keywords.len == 2
	assert mag.exact_length == 1073741824
	assert mag.select_only == [0, 2, 4, 5, 6, 7]
	assert mag.extensions['x.custom'] == 'value'
}

fn test_convenience_functions() {
	// Test simple magnet creation
	magnet1 := create_simple_magnet('1234567890abcdef1234567890abcdef12345678', 'Simple Test') or {
		panic(err)
	}
	assert magnet1.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert magnet1.display_name == 'Simple Test'

	// Test magnet with tracker
	magnet2 := create_magnet_with_tracker('1234567890abcdef1234567890abcdef12345678',
		'Tracker Test', 'http://tracker.example.com:8080/announce') or { panic(err) }
	assert magnet2.info_hash == '1234567890abcdef1234567890abcdef12345678'
	assert magnet2.display_name == 'Tracker Test'
	assert magnet2.trackers.len == 1

	// Test hybrid magnet
	magnet3 := create_hybrid_magnet('1234567890abcdef1234567890abcdef12345678', '1220d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2',
		'Hybrid Test') or { panic(err) }
	assert magnet3.is_hybrid()
}

fn test_parse_errors() {
	// Test invalid protocol
	if _ := parse('http://invalid.url') {
		panic('should have failed on invalid protocol')
	}

	// Test missing xt parameter
	if _ := parse('magnet:?dn=Test') {
		panic('should have failed on missing xt parameter')
	}

	// Test invalid hash length
	if _ := parse('magnet:?xt=urn:btih:invalid') {
		panic('should have failed on invalid hash length')
	}

	// Test invalid hex characters
	if _ := parse('magnet:?xt=urn:btih:123456789gabcdef1234567890abcdef12345678') {
		panic('should have failed on invalid hex characters')
	}
}

fn test_builder_validation() {
	mut builder := new_builder()

	// Test missing info hash
	if _ := builder.build() {
		panic('should have failed on missing info hash')
	}

	// Test invalid hash length
	builder.set_info_hash('invalid')
	if _ := builder.build() {
		panic('should have failed on invalid hash length')
	}

	// Test invalid tracker URL
	builder.set_info_hash('1234567890abcdef1234567890abcdef12345678')
	builder.add_tracker('invalid-url')
	if _ := builder.build() {
		panic('should have failed on invalid tracker URL')
	}
}

fn test_peer_address_validation() {
	// Valid addresses
	assert is_valid_peer_address('192.168.1.1:6881')
	assert is_valid_peer_address('example.com:8080')
	assert is_valid_peer_address('[::1]:6881')
	assert is_valid_peer_address('[2001:db8::1]:8080')

	// Invalid addresses
	assert !is_valid_peer_address('192.168.1.1')
	assert !is_valid_peer_address('192.168.1.1:70000')
	assert !is_valid_peer_address('[invalid')
	assert !is_valid_peer_address('host:port:extra')
}

fn test_roundtrip_conversion() {
	// Create a magnet with all parameters
	original_uri := 'magnet:?xt=urn:btih:1234567890abcdef1234567890abcdef12345678&dn=Test%20File&tr=http%3A%2F%2Ftracker.example.com%3A8080%2Fannounce&x.pe=192.168.1.1%3A6881&xl=1048576'

	// Parse to struct
	mag := parse(original_uri) or { panic(err) }

	// Convert back to string
	result_uri := mag.to_string()

	// Parse again to verify consistency
	magnet2 := parse(result_uri) or { panic(err) }

	assert mag.info_hash == magnet2.info_hash
	assert mag.display_name == magnet2.display_name
	assert mag.trackers == magnet2.trackers
	assert mag.peers == magnet2.peers
	assert mag.exact_length == magnet2.exact_length
}

fn test_hash_format_functions() {
	// Test v1 hash formatting
	v1_hash := [u8(0x12), 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78, 0x90,
		0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78]!
	formatted_v1 := format_hash(v1_hash)
	assert formatted_v1 == '1234567890abcdef1234567890abcdef12345678'

	// Test v2 hash formatting
	mut v2_hash := [32]u8{}
	for i in 0..32 {
		v2_hash[i] = u8(0xd2)
	}
	formatted_v2 := format_hash_v2(v2_hash)
	assert formatted_v2.starts_with('1220')
	assert formatted_v2.len == 68 // 4 + 64 hex chars
}

fn test_utility_functions() {
	// Test hex validation
	assert is_hex('1234567890abcdef')
	assert is_hex('1234567890ABCDEF')
	assert !is_hex('1234567890ghijkl')
	assert !is_hex('12345')

	// Test base32 validation
	assert is_base32('MFRGG2LTMJUXI33J')
	assert !is_base32('mfrgg2ltmjuxi33j') // lowercase not allowed
	assert !is_base32('MFRGG2LTMJUXI331') // 1 not allowed

	// Test URL validation
	assert is_valid_url('http://example.com')
	assert is_valid_url('https://example.com')
	assert is_valid_url('udp://tracker.example.com')
	assert !is_valid_url('ftp://example.com')
	assert !is_valid_url('invalid-url')
}
