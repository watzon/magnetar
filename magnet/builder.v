module magnet

import torrent

pub struct MagnetBuilder {
mut:
	magnet MagnetLink
}

pub fn new_builder() MagnetBuilder {
	return MagnetBuilder{
		magnet: MagnetLink{}
	}
}

// Create a magnet link from torrent metadata
pub fn from_torrent(metadata torrent.TorrentMetadata) MagnetLink {
	mut mag := MagnetLink{}
	
	// Set info hash
	mag.info_hash = format_hash(metadata.info_hash)
	
	// Set v2 info hash if available
	// if v2_hash := metadata.info_hash_v2 {
	//	mag.info_hash_v2 = format_hash_v2(v2_hash)
	// }
	
	// Set display name
	mag.display_name = metadata.info.name
	
	// Add primary tracker
	if metadata.announce.len > 0 {
		mag.trackers << metadata.announce
	}
	
	// Add announce list trackers
	for tier in metadata.announce_list {
		for tracker in tier {
			if tracker !in mag.trackers {
				mag.trackers << tracker
			}
		}
	}
	
	// Set exact length for single-file torrents
	if length := metadata.info.length {
		mag.exact_length = length
	} else {
		mag.exact_length = metadata.total_size()
	}
	
	return mag
}

// Builder methods for constructing magnet links
pub fn (mut b MagnetBuilder) set_info_hash(hash string) MagnetBuilder {
	b.magnet.info_hash = hash
	return b
}

pub fn (mut b MagnetBuilder) set_info_hash_v2(hash string) MagnetBuilder {
	b.magnet.info_hash_v2 = hash
	return b
}

pub fn (mut b MagnetBuilder) set_info_hash_bytes(hash []u8) MagnetBuilder {
	// Convert []u8 to [20]u8
	mut fixed_hash := [20]u8{}
	for i in 0..20 {
		if i < hash.len {
			fixed_hash[i] = hash[i]
		}
	}
	b.magnet.info_hash = format_hash(fixed_hash)
	return b
}

// pub fn (mut b MagnetBuilder) set_info_hash_v2_bytes(hash [32]u8) MagnetBuilder {
//	b.magnet.info_hash_v2 = format_hash_v2(hash)
//	return b
// }

pub fn (mut b MagnetBuilder) set_display_name(name string) MagnetBuilder {
	b.magnet.display_name = name
	return b
}

pub fn (mut b MagnetBuilder) add_tracker(url string) MagnetBuilder {
	if url !in b.magnet.trackers {
		b.magnet.trackers << url
	}
	return b
}

pub fn (mut b MagnetBuilder) add_trackers(urls []string) MagnetBuilder {
	for url in urls {
		b.add_tracker(url)
	}
	return b
}

pub fn (mut b MagnetBuilder) add_peer(address string) MagnetBuilder {
	if address !in b.magnet.peers {
		b.magnet.peers << address
	}
	return b
}

pub fn (mut b MagnetBuilder) add_peers(addresses []string) MagnetBuilder {
	for address in addresses {
		b.add_peer(address)
	}
	return b
}

pub fn (mut b MagnetBuilder) add_web_seed(url string) MagnetBuilder {
	if url !in b.magnet.web_seeds {
		b.magnet.web_seeds << url
	}
	return b
}

pub fn (mut b MagnetBuilder) add_web_seeds(urls []string) MagnetBuilder {
	for url in urls {
		b.add_web_seed(url)
	}
	return b
}

pub fn (mut b MagnetBuilder) add_exact_source(url string) MagnetBuilder {
	if url !in b.magnet.exact_sources {
		b.magnet.exact_sources << url
	}
	return b
}

pub fn (mut b MagnetBuilder) add_alternate_source(url string) MagnetBuilder {
	if url !in b.magnet.alt_sources {
		b.magnet.alt_sources << url
	}
	return b
}

pub fn (mut b MagnetBuilder) add_keyword(keyword string) MagnetBuilder {
	if keyword !in b.magnet.keywords {
		b.magnet.keywords << keyword
	}
	return b
}

pub fn (mut b MagnetBuilder) add_keywords(keywords []string) MagnetBuilder {
	for keyword in keywords {
		b.add_keyword(keyword)
	}
	return b
}

pub fn (mut b MagnetBuilder) set_exact_length(length i64) MagnetBuilder {
	b.magnet.exact_length = length
	return b
}

pub fn (mut b MagnetBuilder) set_select_only(indices []int) MagnetBuilder {
	b.magnet.select_only = indices.clone()
	return b
}

pub fn (mut b MagnetBuilder) add_extension(key string, value string) MagnetBuilder {
	if !key.starts_with('x.') {
		panic('extension parameters must start with "x."')
	}
	b.magnet.extensions[key] = value
	return b
}

pub fn (mut b MagnetBuilder) build() !MagnetLink {
	// Validate required fields
	if b.magnet.info_hash.len == 0 && b.magnet.info_hash_v2.len == 0 {
		return error(MagnetError{
			msg: 'at least one info hash (v1 or v2) is required'
			param: 'xt'
		}.msg())
	}
	
	// Validate hash formats
	if b.magnet.info_hash.len > 0 {
		if b.magnet.info_hash.len != 40 || !is_hex(b.magnet.info_hash) {
			return error(MagnetError{
				msg: 'v1 info hash must be 40 hex characters'
				param: 'xt'
			}.msg())
		}
	}
	
	if b.magnet.info_hash_v2.len > 0 {
		if b.magnet.info_hash_v2.len < 4 || !is_hex(b.magnet.info_hash_v2) {
			return error(MagnetError{
				msg: 'v2 info hash must be valid hex multihash'
				param: 'xt'
			}.msg())
		}
	}
	
	// Validate tracker URLs
	for tracker in b.magnet.trackers {
		if !is_valid_url(tracker) {
			return error(MagnetError{
				msg: 'invalid tracker URL: ${tracker}'
				param: 'tr'
			}.msg())
		}
	}
	
	// Validate peer addresses
	for peer in b.magnet.peers {
		if !is_valid_peer_address(peer) {
			return error(MagnetError{
				msg: 'invalid peer address: ${peer}'
				param: 'x.pe'
			}.msg())
		}
	}
	
	return b.magnet
}

// Utility functions
fn format_hash(hash [20]u8) string {
	mut result := ''
	for b in hash {
		result += '${b:02x}'
	}
	return result
}

// fn format_hash_v2(hash [32]u8) string {
//	// For v2, we need to format as multihash
//	// SHA-256 multihash prefix is 0x1220 (0x12 = SHA-256, 0x20 = 32 bytes)
//	mut result := '1220'
//	for b in hash {
//		result += '${b:02x}'
//	}
//	return result
// }

fn is_valid_url(url string) bool {
	return url.starts_with('http://') || url.starts_with('https://') || url.starts_with('udp://')
}

pub fn is_valid_peer_address(address string) bool {
	// Basic validation for hostname:port, ipv4:port, or [ipv6]:port
	if address.contains('[') && address.contains(']:') {
		// IPv6 format [host]:port
		return address.starts_with('[') && address.contains(']:')
	} else if address.contains(':') {
		// IPv4 or hostname format host:port
		parts := address.split(':')
		if parts.len != 2 {
			return false
		}
		port := parts[1].int()
		return port > 0 && port <= 65535
	}
	return false
}

// Convenience functions
pub fn create_simple_magnet(info_hash string, display_name string) !MagnetLink {
	mut builder := new_builder()
	builder.set_info_hash(info_hash)
	builder.set_display_name(display_name)
	return builder.build()!
}

pub fn create_magnet_with_tracker(info_hash string, display_name string, tracker string) !MagnetLink {
	mut builder := new_builder()
	builder.set_info_hash(info_hash)
	builder.set_display_name(display_name)
	builder.add_tracker(tracker)
	return builder.build()!
}

pub fn create_hybrid_magnet(info_hash_v1 string, info_hash_v2 string, display_name string) !MagnetLink {
	mut builder := new_builder()
	builder.set_info_hash(info_hash_v1)
	builder.set_info_hash_v2(info_hash_v2)
	builder.set_display_name(display_name)
	return builder.build()!
}