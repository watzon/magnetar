module bencode

fn test_basic_decoding() {
	// Test basic string
	data := '4:spam'.bytes()
	result := decode(data) or { panic(err) }
	str_val := result.as_string() or { panic('expected string') }
	assert str_val == 'spam'

	// Test basic integer
	data2 := 'i42e'.bytes()
	result2 := decode(data2) or { panic(err) }
	int_val := result2.as_int() or { panic('expected integer') }
	assert int_val == 42

	// Test basic list
	data3 := 'l4:spami42ee'.bytes()
	result3 := decode(data3) or { panic(err) }
	list_val := result3.as_list() or { panic('expected list') }
	assert list_val.len == 2
}

fn test_string_edge_cases() {
	// Empty string
	data := '0:'.bytes()
	result := decode(data) or { panic(err) }
	str_val := result.as_string() or { panic('expected string') }
	assert str_val == ''

	// String with leading zeros in length - should fail
	data2 := '04:spam'.bytes()
	if _ := decode(data2) {
		panic('should have failed on leading zeros')
	}

	// Negative string length - should fail
	data3 := '-1:'.bytes()
	if _ := decode(data3) {
		panic('should have failed on negative length')
	}

	// String longer than data - should fail
	data4 := '10:spam'.bytes()
	if _ := decode(data4) {
		panic('should have failed on length overflow')
	}

	// Missing colon - should fail
	data5 := '4spam'.bytes()
	if _ := decode(data5) {
		panic('should have failed on missing colon')
	}

	// Empty length field - should fail
	data6 := ':spam'.bytes()
	if _ := decode(data6) {
		panic('should have failed on empty length')
	}
}

fn test_integer_edge_cases() {
	// Zero
	data := 'i0e'.bytes()
	result := decode(data) or { panic(err) }
	int_val := result.as_int() or { panic('expected integer') }
	assert int_val == 0

	// Negative number
	data2 := 'i-123e'.bytes()
	result2 := decode(data2) or { panic(err) }
	int_val2 := result2.as_int() or { panic('expected integer') }
	assert int_val2 == -123

	// Leading zeros - should fail
	data3 := 'i03e'.bytes()
	if _ := decode(data3) {
		panic('should have failed on leading zeros')
	}

	// Negative zero - should fail
	data4 := 'i-0e'.bytes()
	if _ := decode(data4) {
		panic('should have failed on negative zero')
	}

	// Leading zeros in negative - should fail
	data5 := 'i-03e'.bytes()
	if _ := decode(data5) {
		panic('should have failed on negative leading zeros')
	}

	// Empty integer - should fail
	data6 := 'ie'.bytes()
	if _ := decode(data6) {
		panic('should have failed on empty integer')
	}

	// Missing end marker - should fail
	data7 := 'i42'.bytes()
	if _ := decode(data7) {
		panic('should have failed on missing end marker')
	}

	// Large integer
	data8 := 'i9223372036854775807e'.bytes() // i64 max
	result8 := decode(data8) or { panic(err) }
	int_val8 := result8.as_int() or { panic('expected integer') }
	assert int_val8 == 9223372036854775807

	// Too large integer - should fail
	data9 := 'i92233720368547758070e'.bytes() // Too large
	if _ := decode(data9) {
		panic('should have failed on integer overflow')
	}
}

fn test_list_edge_cases() {
	// Empty list
	data := 'le'.bytes()
	result := decode(data) or { panic(err) }
	list_val := result.as_list() or { panic('expected list') }
	assert list_val.len == 0

	// Nested lists
	data2 := 'llei42ee'.bytes() // [[],42]
	result2 := decode(data2) or { panic(err) }
	list_val2 := result2.as_list() or { panic('expected list') }
	assert list_val2.len == 2

	// Missing end marker - should fail
	data3 := 'l4:spam'.bytes()
	if _ := decode(data3) {
		panic('should have failed on missing end marker')
	}
}

fn test_dictionary_edge_cases() {
	// Empty dictionary
	data := 'de'.bytes()
	result := decode(data) or { panic(err) }
	dict_val := result.as_dict() or { panic('expected dictionary') }
	assert dict_val.len == 0

	// Dictionary with proper ordering
	data2 := 'd1:a4:spam1:bi42ee'.bytes()
	result2 := decode(data2) or { panic(err) }
	dict_val2 := result2.as_dict() or { panic('expected dictionary') }
	assert dict_val2.len == 2

	// Dictionary with wrong ordering - should fail
	data3 := 'd1:b4:spam1:ai42ee'.bytes()
	if _ := decode(data3) {
		panic('should have failed on wrong key ordering')
	}

	// Dictionary with duplicate keys - should fail
	data4 := 'd1:a4:spam1:ai42ee'.bytes()
	if _ := decode(data4) {
		panic('should have failed on duplicate keys')
	}

	// Missing end marker - should fail
	data5 := 'd1:a4:spam'.bytes()
	if _ := decode(data5) {
		panic('should have failed on missing end marker')
	}

	// Odd number of elements (no value for last key) - should fail
	data6 := 'd1:ae'.bytes()
	if _ := decode(data6) {
		panic('should have failed on missing value')
	}
}

fn test_binary_key_ordering() {
	// Test binary string ordering (not lexicographic)
	// In binary: [0x00] < [0x01] < [0xFF]
	mut data := []u8{}
	data << 'd'.bytes()
	data << '1:'.bytes()
	data << [u8(0x00)]  // First key: single null byte
	data << 'i1e'.bytes()
	data << '1:'.bytes()
	data << [u8(0x01)]  // Second key: single byte with value 1
	data << 'i2e'.bytes()
	data << '1:'.bytes()
	data << [u8(0xFF)]  // Third key: single byte with value 255
	data << 'i3e'.bytes()
	data << 'e'.bytes()

	result := decode(data) or { panic(err) }
	dict_val := result.as_dict() or { panic('expected dictionary') }
	assert dict_val.len == 3

	// Test wrong binary ordering - should fail
	mut data2 := []u8{}
	data2 << 'd'.bytes()
	data2 << '1:'.bytes()
	data2 << [u8(0xFF)]  // Wrong order: 255 first
	data2 << 'i1e'.bytes()
	data2 << '1:'.bytes()
	data2 << [u8(0x00)]  // Then 0
	data2 << 'i2e'.bytes()
	data2 << 'e'.bytes()

	if _ := decode(data2) {
		panic('should have failed on wrong binary ordering')
	}
}

fn test_depth_limiting() {
	// Create deeply nested structure
	mut data := []u8{}
	
	// Create 60 nested lists (exceeds default limit of 50)
	for _ in 0..60 {
		data << 'l'.bytes()
	}
	for _ in 0..60 {
		data << 'e'.bytes()
	}

	// Should fail due to depth limit
	if _ := decode(data) {
		panic('should have failed on depth limit')
	}

	// Test with custom limit
	mut small_data := []u8{}
	for _ in 0..5 {
		small_data << 'l'.bytes()
	}
	for _ in 0..5 {
		small_data << 'e'.bytes()
	}

	// Should work with higher limit
	result := decode_with_limits(small_data, 10, 1000000) or { panic(err) }
	_ = result.as_list() or { panic('expected list') }

	// Should fail with lower limit
	if _ := decode_with_limits(small_data, 3, 1000000) {
		panic('should have failed on custom depth limit')
	}
}

fn test_memory_limiting() {
	// Create large string that exceeds memory limit
	large_size := 150_000_000 // 150MB
	size_str := large_size.str()
	
	mut data := []u8{}
	data << size_str.bytes()
	data << ':'.bytes()
	// Don't actually add the data, just test the size check

	// Should fail due to memory limit (even before we add the actual data)
	// The decoder checks limits during string parsing
	if result := decode(data) {
		// If it somehow succeeds, that's unexpected
		panic('expected memory limit error')
	}
}

fn test_malformed_data() {
	// Incomplete data
	data := 'i42'.bytes() // Missing 'e'
	if _ := decode(data) {
		panic('should have failed on incomplete data')
	}

	// Invalid type marker
	data2 := 'x42e'.bytes()
	if _ := decode(data2) {
		panic('should have failed on invalid type marker')
	}

	// Empty data
	data3 := []u8{}
	if _ := decode(data3) {
		panic('should have failed on empty data')
	}

	// Random bytes
	data4 := [u8(0x00), 0x01, 0x02, 0xFF]
	if _ := decode(data4) {
		panic('should have failed on random bytes')
	}
}

fn test_nested_structures() {
	// Complex nested structure - keys must be in sorted order: "dict" < "list"
	data := 'd4:dictd3:bari2e3:fooi1ee4:listl4:spam4:eggsi42eee'.bytes()
	result := decode(data) or { panic(err) }
	dict_val := result.as_dict() or { panic('expected dictionary') }
	assert dict_val.len == 2

	// Verify nested list
	list_item := dict_val['list'] or { panic('missing list key') }
	list_val := list_item.as_list() or { panic('expected list') }
	assert list_val.len == 3

	// Verify nested dictionary - keys must be sorted: "bar" < "foo"
	dict_item := dict_val['dict'] or { panic('missing dict key') }
	nested_dict := dict_item.as_dict() or { panic('expected dictionary') }
	assert nested_dict.len == 2
}

fn test_real_world_torrent_like_data() {
	// Simulate a minimal torrent-like structure
	data := 'd8:announce9:test:12346:lengthi1024e4:name8:test.txt12:piece lengthi262144e6:pieces20:01234567890123456789e'.bytes()
	result := decode(data) or { panic(err) }
	dict_val := result.as_dict() or { panic('expected dictionary') }
	
	assert 'announce' in dict_val
	assert 'length' in dict_val
	assert 'name' in dict_val
	assert 'piece length' in dict_val
	assert 'pieces' in dict_val
}

fn test_unicode_and_binary_strings() {
	// Binary data in string
	mut data := []u8{}
	data << '4:'.bytes()
	data << [u8(0x00), 0xFF, 0x80, 0x7F] // Various byte values
	
	result := decode(data) or { panic(err) }
	str_val := result.as_string() or { panic('expected string') }
	assert str_val.len == 4

	// UTF-8 data
	utf8_data := '6:héllo'.bytes()
	result2 := decode(utf8_data) or { panic(err) }
	str_val2 := result2.as_string() or { panic('expected string') }
	assert str_val2 == 'héllo'
}

fn test_validation_functions() {
	// Valid data should validate
	valid_data := 'd4:spam4:eggse'.bytes()
	assert validate(valid_data) or { panic(err) }

	// Invalid data should fail validation
	invalid_data := 'd4:spam'.bytes() // Missing end marker
	if _ := validate(invalid_data) {
		panic('should have failed validation')
	}

	// Extra data should fail validation
	extra_data := 'd4:spam4:eggsejunk'.bytes()
	if _ := validate(extra_data) {
		panic('should have failed validation due to extra data')
	}

	// Test custom limits - create properly nested structure
	nested_data := 'lllllleeeeee'.bytes() // 6 levels deep: [[[[[[]]]]]]
	assert validate_with_limits(nested_data, 10, 1000) or { panic(err) }
	
	if _ := validate_with_limits(nested_data, 3, 1000) {
		panic('should have failed validation due to depth limit')
	}
}