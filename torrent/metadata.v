module torrent

pub struct TorrentMetadata {
pub mut:
	announce      string          // Primary tracker URL
	announce_list [][]string     // Multi-tracker support
	creation_date ?i64           // Optional creation timestamp
	comment       ?string         // Optional comment
	created_by    ?string         // Optional creator
	encoding      ?string         // Optional encoding
	info          InfoDictionary  // Required info dictionary
	info_hash     [20]u8          // SHA1 hash of info dict
	info_hash_v2  ?[32]u8         // SHA256 for v2 torrents
}

pub struct InfoDictionary {
pub mut:
	piece_length i64              // Bytes per piece
	pieces       []u8             // Concatenated SHA1 hashes
	private      ?bool            // Private torrent flag
	name         string           // Suggested name
	files        []FileInfo       // Multi-file mode
	length       ?i64             // Single-file mode
	md5sum       ?string          // Optional MD5
	file_tree    ?map[string]FileNode // v2 file tree
	meta_version ?i64             // v2 meta version
}

pub struct FileInfo {
pub mut:
	length i64          // File size in bytes
	path   []string     // Path components
	md5sum ?string      // Optional MD5
}

pub struct FileNode {
pub:
	length       ?i64
	pieces_root  ?[32]u8
	children     ?map[string]FileNode
}

// Helper methods
pub fn (t TorrentMetadata) is_single_file() bool {
	return t.info.length != none
}

pub fn (t TorrentMetadata) is_multi_file() bool {
	return t.info.files.len > 0
}

pub fn (t TorrentMetadata) is_v2() bool {
	return t.info.meta_version != none
}

pub fn (t TorrentMetadata) total_size() i64 {
	if length := t.info.length {
		return length
	}
	
	mut total := i64(0)
	for file in t.info.files {
		total += file.length
	}
	return total
}

pub fn (t TorrentMetadata) file_count() int {
	if t.is_single_file() {
		return 1
	}
	return t.info.files.len
}

pub fn (t TorrentMetadata) piece_count() int {
	// Each piece hash is 20 bytes
	return t.info.pieces.len / 20
}

pub fn (t TorrentMetadata) get_trackers() []string {
	mut trackers := []string{}
	trackers << t.announce
	
	for tier in t.announce_list {
		for tracker in tier {
			if tracker !in trackers {
				trackers << tracker
			}
		}
	}
	
	return trackers
}