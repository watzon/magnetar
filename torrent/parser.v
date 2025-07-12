module torrent

import bencode
import crypto.sha1
import crypto.sha256
import os

pub struct TorrentError {
pub:
	msg   string
	field string
}

fn (e TorrentError) msg() string {
	return 'Torrent error in field "${e.field}": ${e.msg}'
}

pub fn parse_torrent_file(path string) !TorrentMetadata {
	data := os.read_bytes(path)!
	return parse_torrent_data(data)!
}

pub fn parse_torrent_data(data []u8) !TorrentMetadata {
	value := bencode.decode(data)!

	dict := value.as_dict() or {
		return error(TorrentError{
			msg:   'torrent file must be a dictionary'
			field: 'root'
		}.msg())
	}

	mut metadata := TorrentMetadata{}

	// Parse announce
	if announce_val := dict['announce'] {
		metadata.announce = announce_val.as_string() or {
			return error(TorrentError{
				msg:   'announce must be a string'
				field: 'announce'
			}.msg())
		}
	} else {
		return error(TorrentError{
			msg:   'missing required field'
			field: 'announce'
		}.msg())
	}

	// Parse announce-list (optional)
	if announce_list_val := dict['announce-list'] {
		list := announce_list_val.as_list() or {
			return error(TorrentError{
				msg:   'announce-list must be a list'
				field: 'announce-list'
			}.msg())
		}

		mut announce_list := [][]string{}
		for tier_val in list {
			tier_list := tier_val.as_list() or {
				return error(TorrentError{
					msg:   'announce-list tier must be a list'
					field: 'announce-list'
				}.msg())
			}

			mut tier := []string{}
			for url_val in tier_list {
				url := url_val.as_string() or {
					return error(TorrentError{
						msg:   'tracker URL must be a string'
						field: 'announce-list'
					}.msg())
				}
				tier << url
			}
			announce_list << tier
		}
		metadata.announce_list = announce_list
	}

	// Parse optional fields
	if creation_date_val := dict['creation date'] {
		metadata.creation_date = creation_date_val.as_int() or {
			return error(TorrentError{
				msg:   'creation date must be an integer'
				field: 'creation date'
			}.msg())
		}
	}

	if comment_val := dict['comment'] {
		metadata.comment = comment_val.as_string() or {
			return error(TorrentError{
				msg:   'comment must be a string'
				field: 'comment'
			}.msg())
		}
	}

	if created_by_val := dict['created by'] {
		metadata.created_by = created_by_val.as_string() or {
			return error(TorrentError{
				msg:   'created by must be a string'
				field: 'created by'
			}.msg())
		}
	}

	if encoding_val := dict['encoding'] {
		metadata.encoding = encoding_val.as_string() or {
			return error(TorrentError{
				msg:   'encoding must be a string'
				field: 'encoding'
			}.msg())
		}
	}

	// Parse info dictionary
	info_val := dict['info'] or {
		return error(TorrentError{
			msg:   'missing required field'
			field: 'info'
		}.msg())
	}

	info_dict := info_val.as_dict() or {
		return error(TorrentError{
			msg:   'info must be a dictionary'
			field: 'info'
		}.msg())
	}

	metadata.info = parse_info_dictionary(info_dict)!

	// Calculate info hash using exact bytes from original torrent file
	metadata.info_hash = calculate_info_hash_from_torrent(data)!

	// Calculate v2 info hash if applicable
	if metadata.info.meta_version != none {
		info_bytes := extract_info_bytes(data)!
		hash256 := sha256.sum256(info_bytes)
		mut v2_hash := [32]u8{}
		for i in 0 .. 32 {
			v2_hash[i] = hash256[i]
		}
		metadata.info_hash_v2 = v2_hash
	}

	return metadata
}

fn parse_info_dictionary(dict map[string]bencode.BencodeValue) !InfoDictionary {
	mut info := InfoDictionary{}

	// Parse piece length
	if piece_length_val := dict['piece length'] {
		info.piece_length = piece_length_val.as_int() or {
			return error(TorrentError{
				msg:   'piece length must be an integer'
				field: 'info.piece length'
			}.msg())
		}

		// Validate piece length is power of 2
		if info.piece_length <= 0 || (info.piece_length & (info.piece_length - 1)) != 0 {
			return error(TorrentError{
				msg:   'piece length must be a positive power of 2'
				field: 'info.piece length'
			}.msg())
		}
	} else {
		return error(TorrentError{
			msg:   'missing required field'
			field: 'info.piece length'
		}.msg())
	}

	// Parse pieces
	if pieces_val := dict['pieces'] {
		pieces_str := pieces_val.as_string() or {
			return error(TorrentError{
				msg:   'pieces must be a string'
				field: 'info.pieces'
			}.msg())
		}
		info.pieces = pieces_str.bytes()

		// Validate pieces length is multiple of 20
		if info.pieces.len % 20 != 0 {
			return error(TorrentError{
				msg:   'pieces length must be multiple of 20'
				field: 'info.pieces'
			}.msg())
		}
	} else {
		return error(TorrentError{
			msg:   'missing required field'
			field: 'info.pieces'
		}.msg())
	}

	// Parse name
	if name_val := dict['name'] {
		info.name = name_val.as_string() or {
			return error(TorrentError{
				msg:   'name must be a string'
				field: 'info.name'
			}.msg())
		}
	} else {
		return error(TorrentError{
			msg:   'missing required field'
			field: 'info.name'
		}.msg())
	}

	// Parse private flag (optional)
	if private_val := dict['private'] {
		private_int := private_val.as_int() or {
			return error(TorrentError{
				msg:   'private must be an integer (0 or 1)'
				field: 'info.private'
			}.msg())
		}
		info.private = private_int == 1
	}

	// Check if single-file or multi-file mode
	if length_val := dict['length'] {
		// Single-file mode
		info.length = length_val.as_int() or {
			return error(TorrentError{
				msg:   'length must be an integer'
				field: 'info.length'
			}.msg())
		}

		// Parse optional md5sum
		if md5sum_val := dict['md5sum'] {
			info.md5sum = md5sum_val.as_string() or {
				return error(TorrentError{
					msg:   'md5sum must be a string'
					field: 'info.md5sum'
				}.msg())
			}
		}
	} else if files_val := dict['files'] {
		// Multi-file mode
		files_list := files_val.as_list() or {
			return error(TorrentError{
				msg:   'files must be a list'
				field: 'info.files'
			}.msg())
		}

		mut files := []FileInfo{}
		for i, file_val in files_list {
			file_dict := file_val.as_dict() or {
				return error(TorrentError{
					msg:   'file entry must be a dictionary'
					field: 'info.files[${i}]'
				}.msg())
			}

			file := parse_file_info(file_dict, 'info.files[${i}]')!
			files << file
		}
		info.files = files
	} else {
		return error(TorrentError{
			msg:   'must have either length (single-file) or files (multi-file)'
			field: 'info'
		}.msg())
	}

	// Parse v2 fields (optional)
	if meta_version_val := dict['meta version'] {
		info.meta_version = meta_version_val.as_int() or {
			return error(TorrentError{
				msg:   'meta version must be an integer'
				field: 'info.meta version'
			}.msg())
		}
	}

	// TODO: Parse file tree for v2 torrents

	return info
}

fn parse_file_info(dict map[string]bencode.BencodeValue, field_prefix string) !FileInfo {
	mut file := FileInfo{}

	// Parse length
	if length_val := dict['length'] {
		file.length = length_val.as_int() or {
			return error(TorrentError{
				msg:   'length must be an integer'
				field: '${field_prefix}.length'
			}.msg())
		}
	} else {
		return error(TorrentError{
			msg:   'missing required field'
			field: '${field_prefix}.length'
		}.msg())
	}

	// Parse path
	if path_val := dict['path'] {
		path_list := path_val.as_list() or {
			return error(TorrentError{
				msg:   'path must be a list'
				field: '${field_prefix}.path'
			}.msg())
		}

		mut path := []string{}
		for j, component_val in path_list {
			component := component_val.as_string() or {
				return error(TorrentError{
					msg:   'path component must be a string'
					field: '${field_prefix}.path[${j}]'
				}.msg())
			}

			// Validate path component
			if component.contains('..') || component.contains('/') || component.contains('\\') {
				return error(TorrentError{
					msg:   'invalid path component (directory traversal)'
					field: '${field_prefix}.path[${j}]'
				}.msg())
			}

			path << component
		}
		file.path = path
	} else {
		return error(TorrentError{
			msg:   'missing required field'
			field: '${field_prefix}.path'
		}.msg())
	}

	// Parse optional md5sum
	if md5sum_val := dict['md5sum'] {
		file.md5sum = md5sum_val.as_string() or {
			return error(TorrentError{
				msg:   'md5sum must be a string'
				field: '${field_prefix}.md5sum'
			}.msg())
		}
	}

	return file
}

// Calculate info hash by extracting exact bencoded bytes from original torrent data
fn calculate_info_hash_from_torrent(data []u8) ![20]u8 {
	info_bytes := extract_info_bytes(data)!
	hash := sha1.sum(info_bytes)
	mut result := [20]u8{}
	for i in 0 .. 20 {
		result[i] = hash[i]
	}
	return result
}

// Extract the exact bencoded bytes of the info dictionary from torrent data
fn extract_info_bytes(data []u8) ![]u8 {
	// The torrent file is a bencoded dictionary, we need to find the 'info' key
	// and extract its exact bencoded value

	if data.len < 2 || data[0] != `d` {
		return error('invalid torrent file format')
	}

	mut pos := 1 // Skip the initial 'd'

	// Search for the info key
	for pos < data.len && data[pos] != `e` {
		// Read key length
		colon_pos := find_colon(data, pos) or { return error('malformed torrent file') }

		key_len_str := data[pos..colon_pos].bytestr()
		key_len := key_len_str.int()

		pos = colon_pos + 1

		// Read key
		if pos + key_len > data.len {
			return error('malformed torrent file')
		}

		key := data[pos..pos + key_len].bytestr()
		pos += key_len

		// Mark start of value
		value_start := pos

		// Skip over the value to find its end
		value_end := skip_bencode_value(data, pos) or { return error('malformed torrent file') }

		// If this is the info key, return its bencoded value
		if key == 'info' {
			return data[value_start..value_end]
		}

		pos = value_end
	}

	return error('info dictionary not found')
}

// Helper function to find colon in bencoded string length
fn find_colon(data []u8, start int) ?int {
	for i := start; i < data.len; i++ {
		if data[i] == `:` {
			return i
		}
		// Only digits are allowed before colon
		if data[i] < `0` || data[i] > `9` {
			return none
		}
	}
	return none
}

// Skip over a bencoded value and return the position after it
fn skip_bencode_value(data []u8, pos int) ?int {
	if pos >= data.len {
		return none
	}

	match data[pos] {
		`i` {
			// Integer: find the 'e'
			mut i := pos + 1
			for i < data.len && data[i] != `e` {
				i++
			}
			if i >= data.len {
				return none
			}
			return i + 1
		}
		`l` {
			// List: skip elements until 'e'
			mut i := pos + 1
			for i < data.len && data[i] != `e` {
				i = skip_bencode_value(data, i) or { return none }
			}
			if i >= data.len {
				return none
			}
			return i + 1
		}
		`d` {
			// Dictionary: skip key-value pairs until 'e'
			mut i := pos + 1
			for i < data.len && data[i] != `e` {
				// Skip key (must be string)
				i = skip_bencode_value(data, i) or { return none }
				// Skip value
				i = skip_bencode_value(data, i) or { return none }
			}
			if i >= data.len {
				return none
			}
			return i + 1
		}
		`0`...`9` {
			// String: read length, then skip that many bytes
			colon_pos := find_colon(data, pos) or { return none }
			length_str := data[pos..colon_pos].bytestr()
			length := length_str.int()
			string_end := colon_pos + 1 + length
			if string_end > data.len {
				return none
			}
			return string_end
		}
		else {
			return none
		}
	}
}

pub fn validate_torrent(metadata TorrentMetadata) ! {
	// Validate basic fields
	if metadata.announce.len == 0 {
		return error(TorrentError{
			msg:   'announce URL cannot be empty'
			field: 'announce'
		}.msg())
	}

	if metadata.info.name.len == 0 {
		return error(TorrentError{
			msg:   'torrent name cannot be empty'
			field: 'info.name'
		}.msg())
	}

	// Validate piece length
	if metadata.info.piece_length <= 0 {
		return error(TorrentError{
			msg:   'piece length must be positive'
			field: 'info.piece_length'
		}.msg())
	}

	// Validate pieces
	expected_pieces := ((metadata.total_size() + metadata.info.piece_length - 1) / metadata.info.piece_length)
	actual_pieces := metadata.piece_count()

	if actual_pieces != expected_pieces {
		return error(TorrentError{
			msg:   'piece count mismatch: expected ${expected_pieces}, got ${actual_pieces}'
			field: 'info.pieces'
		}.msg())
	}

	// Validate file sizes
	if metadata.is_single_file() {
		if length := metadata.info.length {
			if length <= 0 {
				return error(TorrentError{
					msg:   'file length must be positive'
					field: 'info.length'
				}.msg())
			}
		}
	} else {
		for i, file in metadata.info.files {
			if file.length <= 0 {
				return error(TorrentError{
					msg:   'file length must be positive'
					field: 'info.files[${i}].length'
				}.msg())
			}

			if file.path.len == 0 {
				return error(TorrentError{
					msg:   'file path cannot be empty'
					field: 'info.files[${i}].path'
				}.msg())
			}
		}
	}
}
