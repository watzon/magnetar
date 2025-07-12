module torrent

import crypto.sha1
import crypto.sha256

pub fn calculate_info_hash(info_dict []u8) [20]u8 {
	hash := sha1.sum(info_dict)
	mut result := [20]u8{}
	for i in 0 .. 20 {
		result[i] = hash[i]
	}
	return result
}

pub fn calculate_info_hash_v2(info_dict []u8) [32]u8 {
	hash := sha256.sum256(info_dict)
	mut result := [32]u8{}
	for i in 0 .. 32 {
		result[i] = hash[i]
	}
	return result
}

pub fn calculate_piece_hash(piece_data []u8) [20]u8 {
	hash := sha1.sum(piece_data)
	mut result := [20]u8{}
	for i in 0 .. 20 {
		result[i] = hash[i]
	}
	return result
}

pub fn verify_piece(piece_data []u8, expected_hash [20]u8) bool {
	actual_hash := calculate_piece_hash(piece_data)
	return actual_hash == expected_hash
}

pub fn extract_piece_hash(pieces []u8, piece_index int) ?[20]u8 {
	start := piece_index * 20
	if start + 20 > pieces.len {
		return none
	}

	mut hash := [20]u8{}
	for i in 0 .. 20 {
		hash[i] = pieces[start + i]
	}
	return hash
}

pub fn format_hash(hash []u8) string {
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return result
}

pub fn parse_hash(hex_string string) ?[]u8 {
	if hex_string.len % 2 != 0 {
		return none
	}

	mut result := []u8{cap: hex_string.len / 2}
	for i := 0; i < hex_string.len; i += 2 {
		hex_byte := hex_string[i..i + 2]
		byte_val := hex_byte.parse_uint(16, 8) or { return none }
		result << u8(byte_val)
	}
	return result
}
