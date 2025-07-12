module magnetar

// Import submodules
import bencode
import torrent
import magnet
import utils

// Convenience functions for common operations

// Parse a torrent file and return metadata
pub fn parse_file(path string) !torrent.TorrentMetadata {
	return torrent.parse_torrent_file(path)!
}

// Parse torrent data from bytes
pub fn parse(data []u8) !torrent.TorrentMetadata {
	return torrent.parse_torrent_data(data)!
}

// Parse a magnet URI
pub fn parse_magnet(uri string) !magnet.MagnetLink {
	return magnet.parse(uri)!
}

// Create a new torrent builder
pub fn new_torrent_builder() torrent.TorrentBuilder {
	return torrent.new_builder()
}

// Create a new magnet builder  
pub fn new_magnet_builder() magnet.MagnetBuilder {
	return magnet.new_builder()
}

// Convert torrent metadata to magnet link
pub fn torrent_to_magnet(metadata torrent.TorrentMetadata) magnet.MagnetLink {
	return magnet.from_torrent(metadata)
}

// Convert magnet link to minimal torrent metadata
// pub fn magnet_to_torrent(magnet_link magnet.MagnetLink) !torrent.TorrentMetadata {
//	return magnet.to_torrent_metadata(magnet_link)!
// }

// Validate a torrent file
pub fn validate_file(path string) ! {
	metadata := parse_file(path)!
	torrent.validate_torrent(metadata)!
}

// Validate torrent metadata
pub fn validate(metadata torrent.TorrentMetadata) ! {
	torrent.validate_torrent(metadata)!
}

// Quick info extraction
pub struct TorrentInfo {
pub:
	name        string
	size        i64
	file_count  int
	piece_count int
	info_hash   string
	announce    string
	is_private  bool
	trackers    []string
}

pub fn get_info(metadata torrent.TorrentMetadata) TorrentInfo {
	return TorrentInfo{
		name: metadata.info.name
		size: metadata.total_size()
		file_count: metadata.file_count()
		piece_count: metadata.piece_count()
		info_hash: torrent.format_hash(metadata.info_hash[..])
		announce: metadata.announce
		is_private: metadata.info.private or { false }
		trackers: metadata.get_trackers()
	}
}

pub fn get_info_from_file(path string) !TorrentInfo {
	metadata := parse_file(path)!
	return get_info(metadata)
}

pub fn get_info_from_magnet(uri string) !TorrentInfo {
	magnet_link := parse_magnet(uri)!
	
	// Extract basic info from magnet
	mut info := TorrentInfo{
		name: if magnet_link.display_name.len > 0 { magnet_link.display_name } else { 'Unknown' }
		size: magnet_link.exact_length
		file_count: if magnet_link.exact_length > 0 { 1 } else { 0 }
		piece_count: 0 // Cannot determine from magnet alone
		info_hash: magnet_link.get_primary_hash()
		announce: if magnet_link.trackers.len > 0 { magnet_link.trackers[0] } else { '' }
		is_private: false // Cannot determine from magnet alone
		trackers: magnet_link.trackers
	}
	
	return info
}

// Utility functions for hash formatting
pub fn format_info_hash(hash [20]u8) string {
	return torrent.format_hash(hash[..])
}

pub fn parse_info_hash(hex_string string) ?[20]u8 {
	hash_bytes := torrent.parse_hash(hex_string) or { return none }
	if hash_bytes.len != 20 {
		return none
	}
	
	mut result := [20]u8{}
	for i, b in hash_bytes {
		result[i] = b
	}
	return result
}

// Bencode helpers
// pub fn encode_to_bencode(data map[string]string) []u8 {
//	mut dict := bencode.bencode_dict()
//	for key, value in data {
//		dict.set(key, bencode.bencode_string(value))
//	}
//	return bencode.encode(dict)
// }

// pub fn decode_from_bencode(data []u8) !map[string]string {
//	value := bencode.decode(data)!
//	dict := value.as_dict() or {
//		return error('not a dictionary')
//	}
//	
//	mut result := map[string]string{}
//	for key, val in dict {
//		if str_val := val.as_string() {
//			result[key] = str_val
//		}
//	}
//	
//	return result
// }