module bencode

import os

pub struct BencodeError {
pub:
	msg  string
	pos  int
	code BencodeErrorCode
}

pub enum BencodeErrorCode {
	invalid_format
	invalid_integer
	invalid_string
	invalid_structure
	buffer_overflow
	memory_limit_exceeded
	depth_limit_exceeded
	integer_overflow
	incomplete_data
}

fn (e BencodeError) msg() string {
	return 'Bencode error at position ${e.pos}: ${e.msg}'
}

struct Decoder {
mut:
	data       []u8
	pos        int
	depth      int
	max_depth  int = 50          // Prevent stack overflow attacks
	max_size   int = 100_000_000 // 100MB limit to prevent memory exhaustion
	bytes_read int
}

pub fn decode(data []u8) !BencodeValue {
	mut decoder := Decoder{
		data:       data
		pos:        0
		depth:      0
		bytes_read: 0
	}
	return decoder.decode_value()!
}

// Decode with custom limits
pub fn decode_with_limits(data []u8, max_depth int, max_size int) !BencodeValue {
	mut decoder := Decoder{
		data:       data
		pos:        0
		depth:      0
		max_depth:  max_depth
		max_size:   max_size
		bytes_read: 0
	}
	return decoder.decode_value()!
}

pub fn decode_from_file(path string) !BencodeValue {
	data := os.read_bytes(path)!
	return decode(data)!
}

fn (mut d Decoder) decode_value() !BencodeValue {
	// Check bounds
	if d.pos >= d.data.len {
		return error(BencodeError{
			msg:  'unexpected end of data'
			pos:  d.pos
			code: .incomplete_data
		}.msg())
	}

	// Check memory limit
	if d.bytes_read > d.max_size {
		return error(BencodeError{
			msg:  'data size exceeds limit of ${d.max_size} bytes'
			pos:  d.pos
			code: .memory_limit_exceeded
		}.msg())
	}

	// Check depth limit for nested structures
	current_byte := d.data[d.pos]
	if (current_byte == `l` || current_byte == `d`) && d.depth >= d.max_depth {
		return error(BencodeError{
			msg:  'nesting depth exceeds limit of ${d.max_depth}'
			pos:  d.pos
			code: .depth_limit_exceeded
		}.msg())
	}

	match current_byte {
		`i` {
			return d.decode_integer()!
		}
		`l` {
			return d.decode_list()!
		}
		`d` {
			return d.decode_dictionary()!
		}
		`0`...`9` {
			return d.decode_string()!
		}
		else {
			return error(BencodeError{
				msg:  'invalid bencode type: ${current_byte:c}'
				pos:  d.pos
				code: .invalid_format
			}.msg())
		}
	}
}

fn (mut d Decoder) decode_string() !BencodeString {
	start_pos := d.pos

	colon_pos := d.find_byte(`:`, d.pos) or {
		return error(BencodeError{
			msg:  'missing colon in string length'
			pos:  d.pos
			code: .invalid_string
		}.msg())
	}

	// Check for empty length
	if colon_pos == d.pos {
		return error(BencodeError{
			msg:  'empty string length'
			pos:  d.pos
			code: .invalid_string
		}.msg())
	}

	length_str := d.data[d.pos..colon_pos].bytestr()
	length := length_str.int()

	if length < 0 {
		return error(BencodeError{
			msg:  'negative string length: ${length}'
			pos:  d.pos
			code: .invalid_string
		}.msg())
	}

	// Check for leading zeros in length (except for "0:")
	if length_str.len > 1 && length_str[0] == `0` {
		return error(BencodeError{
			msg:  'string length has leading zeros'
			pos:  d.pos
			code: .invalid_string
		}.msg())
	}

	d.pos = colon_pos + 1

	// Check bounds
	if d.pos + length > d.data.len {
		return error(BencodeError{
			msg:  'string length ${length} exceeds remaining data ${d.data.len - d.pos}'
			pos:  d.pos
			code: .buffer_overflow
		}.msg())
	}

	// Update bytes read counter
	d.bytes_read += length + (colon_pos - start_pos + 1)

	value := d.data[d.pos..d.pos + length].clone()
	d.pos += length

	return BencodeString{
		value: value
	}
}

fn (mut d Decoder) decode_integer() !BencodeInteger {
	if d.data[d.pos] != `i` {
		return error(BencodeError{
			msg:  'expected "i" for integer'
			pos:  d.pos
			code: .invalid_integer
		}.msg())
	}
	d.pos++

	end_pos := d.find_byte(`e`, d.pos) or {
		return error(BencodeError{
			msg:  'missing "e" to end integer'
			pos:  d.pos
			code: .incomplete_data
		}.msg())
	}

	num_str := d.data[d.pos..end_pos].bytestr()

	// Check for invalid formats
	if num_str.len == 0 {
		return error(BencodeError{
			msg:  'empty integer'
			pos:  d.pos
			code: .invalid_integer
		}.msg())
	}

	// No leading zeros except for "0"
	if num_str.len > 1 && num_str[0] == `0` {
		return error(BencodeError{
			msg:  'leading zeros not allowed'
			pos:  d.pos
			code: .invalid_integer
		}.msg())
	}

	// No leading zeros for negative numbers either (e.g., "-03")
	if num_str.len > 2 && num_str[0] == `-` && num_str[1] == `0` {
		return error(BencodeError{
			msg:  'leading zeros not allowed for negative numbers'
			pos:  d.pos
			code: .invalid_integer
		}.msg())
	}

	// Negative zero not allowed
	if num_str == '-0' {
		return error(BencodeError{
			msg:  'negative zero not allowed'
			pos:  d.pos
			code: .invalid_integer
		}.msg())
	}

	// Check for integer overflow by validating string length
	// i64 max is 9223372036854775807 (19 digits)
	// i64 min is -9223372036854775808 (20 characters including minus)
	max_digits := if num_str[0] == `-` { 20 } else { 19 }
	if num_str.len > max_digits {
		return error(BencodeError{
			msg:  'integer too large: ${num_str}'
			pos:  d.pos
			code: .integer_overflow
		}.msg())
	}

	// Additional overflow check - try parsing and check for errors
	value := num_str.i64()

	// Simple overflow detection - if we get an unexpected value, it might be overflow
	if num_str.len > 18 { // Near the limits
		// Re-stringify and compare to detect overflow
		test_str := value.str()
		if test_str != num_str {
			return error(BencodeError{
				msg:  'integer overflow: ${num_str}'
				pos:  d.pos
				code: .integer_overflow
			}.msg())
		}
	}

	d.pos = end_pos + 1

	return BencodeInteger{
		value: value
	}
}

fn (mut d Decoder) decode_list() !BencodeList {
	if d.data[d.pos] != `l` {
		return error(BencodeError{
			msg:  'expected "l" for list'
			pos:  d.pos
			code: .invalid_structure
		}.msg())
	}

	d.pos++
	d.depth++
	defer { d.depth-- }

	mut values := []BencodeValue{}
	for d.pos < d.data.len && d.data[d.pos] != `e` {
		value := d.decode_value()!
		values << value
	}

	if d.pos >= d.data.len || d.data[d.pos] != `e` {
		return error(BencodeError{
			msg:  'missing "e" to end list'
			pos:  d.pos
			code: .incomplete_data
		}.msg())
	}
	d.pos++

	return BencodeList{
		values: values
	}
}

fn (mut d Decoder) decode_dictionary() !BencodeDictionary {
	if d.data[d.pos] != `d` {
		return error(BencodeError{
			msg:  'expected "d" for dictionary'
			pos:  d.pos
			code: .invalid_structure
		}.msg())
	}

	d.pos++
	d.depth++
	defer { d.depth-- }

	mut pairs := map[string]BencodeValue{}
	mut last_key_bytes := []u8{}

	for d.pos < d.data.len && d.data[d.pos] != `e` {
		// Dictionary keys must be strings
		key_value := d.decode_string()!
		key_bytes := key_value.value
		key := key_bytes.bytestr()

		// Keys must be in sorted order (binary comparison)
		if last_key_bytes.len > 0 && compare_bytes(key_bytes, last_key_bytes) <= 0 {
			return error(BencodeError{
				msg:  'dictionary keys not in sorted order'
				pos:  d.pos
				code: .invalid_structure
			}.msg())
		}
		last_key_bytes = key_bytes.clone()

		value := d.decode_value()!
		pairs[key] = value
	}

	if d.pos >= d.data.len || d.data[d.pos] != `e` {
		return error(BencodeError{
			msg:  'missing "e" to end dictionary'
			pos:  d.pos
			code: .incomplete_data
		}.msg())
	}
	d.pos++

	return BencodeDictionary{
		pairs: pairs
	}
}

// Binary comparison of byte arrays
fn compare_bytes(a []u8, b []u8) int {
	min_len := if a.len < b.len { a.len } else { b.len }

	for i in 0 .. min_len {
		if a[i] < b[i] {
			return -1
		} else if a[i] > b[i] {
			return 1
		}
	}

	// If all compared bytes are equal, compare lengths
	if a.len < b.len {
		return -1
	} else if a.len > b.len {
		return 1
	}

	return 0
}

fn (d Decoder) find_byte(b u8, start int) ?int {
	for i := start; i < d.data.len; i++ {
		if d.data[i] == b {
			return i
		}
	}
	return none
}

// Validate bencode data without fully parsing it
// This is useful for quick validation of potentially malicious data
pub fn validate(data []u8) !bool {
	mut validator := Decoder{
		data:       data
		pos:        0
		depth:      0
		max_depth:  50
		max_size:   100_000_000
		bytes_read: 0
	}

	// Try to decode - if it succeeds, it's valid
	_ := validator.decode_value()!

	// Check that we consumed all the data
	if validator.pos != data.len {
		return error(BencodeError{
			msg:  'extra data after valid bencode'
			pos:  validator.pos
			code: .invalid_format
		}.msg())
	}

	return true
}

// Quick validation with custom limits
pub fn validate_with_limits(data []u8, max_depth int, max_size int) !bool {
	mut validator := Decoder{
		data:       data
		pos:        0
		depth:      0
		max_depth:  max_depth
		max_size:   max_size
		bytes_read: 0
	}

	_ := validator.decode_value()!

	if validator.pos != data.len {
		return error(BencodeError{
			msg:  'extra data after valid bencode'
			pos:  validator.pos
			code: .invalid_format
		}.msg())
	}

	return true
}
