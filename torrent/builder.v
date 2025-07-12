module torrent

import bencode
import crypto.sha1
import time
import os

pub struct TorrentBuilder {
mut:
	metadata    TorrentMetadata
	file_paths  []string // Actual file paths for piece calculation
	auto_pieces bool     // Auto-calculate piece length
}

pub fn new_builder() TorrentBuilder {
	return TorrentBuilder{
		metadata:    TorrentMetadata{
			info: InfoDictionary{
				piece_length: 262144 // Default 256KB
				pieces:       []u8{}
				files:        []FileInfo{}
			}
		}
		auto_pieces: true
	}
}

pub fn (mut b TorrentBuilder) set_announce(url string) {
	b.metadata.announce = url
}

pub fn (mut b TorrentBuilder) add_tracker_tier(urls []string) {
	b.metadata.announce_list << urls
}

pub fn (mut b TorrentBuilder) set_comment(comment string) {
	b.metadata.comment = comment
}

pub fn (mut b TorrentBuilder) set_created_by(created_by string) {
	b.metadata.created_by = created_by
}

pub fn (mut b TorrentBuilder) set_encoding(encoding string) {
	b.metadata.encoding = encoding
}

pub fn (mut b TorrentBuilder) set_private(private bool) {
	b.metadata.info.private = private
}

pub fn (mut b TorrentBuilder) set_name(name string) {
	b.metadata.info.name = name
}

pub fn (mut b TorrentBuilder) set_piece_length(length i64) {
	// Validate power of 2
	if length > 0 && (length & (length - 1)) == 0 {
		b.metadata.info.piece_length = length
		b.auto_pieces = false
	}
}

pub fn (mut b TorrentBuilder) add_file(path string, size i64) {
	// For single file torrent
	if b.metadata.info.files.len == 0 && b.metadata.info.length == none {
		b.metadata.info.length = size
		b.file_paths << path
	} else {
		// Convert to multi-file if needed
		if length := b.metadata.info.length {
			// Convert single file to multi-file
			first_file := FileInfo{
				length: length
				path:   [b.metadata.info.name]
			}
			b.metadata.info.files << first_file
			b.metadata.info.length = none
		}

		// Add new file
		path_components := path.split(os.path_separator)
		file := FileInfo{
			length: size
			path:   path_components
		}
		b.metadata.info.files << file
		b.file_paths << path
	}
}

pub fn (mut b TorrentBuilder) add_file_with_path(actual_path string, torrent_path []string, size i64) {
	// For custom torrent paths different from actual file paths
	file := FileInfo{
		length: size
		path:   torrent_path
	}

	if b.metadata.info.files.len == 0 && b.metadata.info.length == none {
		b.metadata.info.length = size
		b.metadata.info.name = torrent_path.join(os.path_separator)
	} else {
		if length := b.metadata.info.length {
			// Convert single file to multi-file
			first_file := FileInfo{
				length: length
				path:   [b.metadata.info.name]
			}
			b.metadata.info.files << first_file
			b.metadata.info.length = none
		}
		b.metadata.info.files << file
	}

	b.file_paths << actual_path
}

pub fn (mut b TorrentBuilder) build() !TorrentMetadata {
	// Set creation date
	b.metadata.creation_date = i64(time.now().unix())

	// Validate required fields
	if b.metadata.announce.len == 0 {
		return error('announce URL is required')
	}

	if b.metadata.info.name.len == 0 {
		return error('torrent name is required')
	}

	// Auto-calculate piece length if needed
	if b.auto_pieces {
		total_size := b.metadata.total_size()
		b.metadata.info.piece_length = calculate_piece_length(total_size)
	}

	// Calculate pieces if files were added
	if b.file_paths.len > 0 {
		b.calculate_pieces()!
	}

	// Calculate info hash
	info_dict := b.build_info_dict()
	info_bencode := bencode.encode(info_dict)
	hash := sha1.sum(info_bencode)
	for i in 0 .. 20 {
		b.metadata.info_hash[i] = hash[i]
	}

	validate_torrent(b.metadata)!

	return b.metadata
}

pub fn (mut b TorrentBuilder) save_to_file(path string) ! {
	metadata := b.build()!
	torrent_dict := b.build_torrent_dict(metadata)
	bencode.encode_to_file(torrent_dict, path)!
}

fn (b TorrentBuilder) build_torrent_dict(metadata TorrentMetadata) bencode.BencodeDictionary {
	mut dict := bencode.bencode_dict()

	// Add top-level fields
	dict.set('announce', bencode.bencode_string(metadata.announce))

	if metadata.announce_list.len > 0 {
		mut announce_list := []bencode.BencodeValue{}
		for tier in metadata.announce_list {
			mut tier_list := []bencode.BencodeValue{}
			for url in tier {
				tier_list << bencode.bencode_string(url)
			}
			announce_list << bencode.bencode_list(...tier_list)
		}
		dict.set('announce-list', bencode.bencode_list(...announce_list))
	}

	if creation_date := metadata.creation_date {
		dict.set('creation date', bencode.bencode_int(creation_date))
	}

	if comment := metadata.comment {
		dict.set('comment', bencode.bencode_string(comment))
	}

	if created_by := metadata.created_by {
		dict.set('created by', bencode.bencode_string(created_by))
	}

	if encoding := metadata.encoding {
		dict.set('encoding', bencode.bencode_string(encoding))
	}

	// Add info dictionary
	dict.set('info', b.build_info_dict())

	return dict
}

fn (b TorrentBuilder) build_info_dict() bencode.BencodeDictionary {
	mut info := bencode.bencode_dict()

	info.set('piece length', bencode.bencode_int(b.metadata.info.piece_length))
	info.set('pieces', bencode.bencode_bytes(b.metadata.info.pieces))
	info.set('name', bencode.bencode_string(b.metadata.info.name))

	if private := b.metadata.info.private {
		info.set('private', bencode.bencode_int(if private { 1 } else { 0 }))
	}

	// Single-file or multi-file
	if length := b.metadata.info.length {
		info.set('length', bencode.bencode_int(length))
		if md5sum := b.metadata.info.md5sum {
			info.set('md5sum', bencode.bencode_string(md5sum))
		}
	} else if b.metadata.info.files.len > 0 {
		mut files := []bencode.BencodeValue{}
		for file in b.metadata.info.files {
			mut file_dict := bencode.bencode_dict()
			file_dict.set('length', bencode.bencode_int(file.length))

			mut path_list := []bencode.BencodeValue{}
			for component in file.path {
				path_list << bencode.bencode_string(component)
			}
			file_dict.set('path', bencode.bencode_list(...path_list))

			if md5sum := file.md5sum {
				file_dict.set('md5sum', bencode.bencode_string(md5sum))
			}

			files << file_dict
		}
		info.set('files', bencode.bencode_list(...files))
	}

	return info
}

fn (mut b TorrentBuilder) calculate_pieces() ! {
	// This is a placeholder - actual implementation would read files
	// and calculate SHA1 hashes for each piece
	// For now, we'll just create dummy hashes

	total_size := b.metadata.total_size()
	piece_count := (total_size + b.metadata.info.piece_length - 1) / b.metadata.info.piece_length

	mut pieces := []u8{cap: int(piece_count * 20)}
	for _ in 0 .. piece_count {
		// In real implementation, read piece data and calculate SHA1
		dummy_hash := sha1.sum('dummy piece data'.bytes()).data
		pieces << dummy_hash
	}

	b.metadata.info.pieces = pieces
}

fn calculate_piece_length(total_size i64) i64 {
	// Auto-calculate optimal piece length based on total size
	// Common piece sizes: 256KB, 512KB, 1MB, 2MB, 4MB

	kb := i64(1024)
	mb := kb * 1024
	gb := mb * 1024

	return match true {
		total_size < 256 * mb { 256 * kb } // < 256MB: 256KB pieces
		total_size < 512 * mb { 512 * kb } // < 512MB: 512KB pieces
		total_size < 1 * gb { 1 * mb } // < 1GB: 1MB pieces
		total_size < 2 * gb { 2 * mb } // < 2GB: 2MB pieces
		else { 4 * mb } // >= 2GB: 4MB pieces
	}
}
