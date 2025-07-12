module magnet

import net.urllib

pub struct MagnetLink {
pub mut:
	// Core BitTorrent parameters
	info_hash    string   // xt: exact topic (btih hash)
	info_hash_v2 string   // xt: exact topic (btmh hash for v2)
	display_name string   // dn: display name
	trackers     []string // tr: tracker URLs
	peers        []string // x.pe: peer addresses

	// Extended parameters
	web_seeds     []string // ws: web seed URLs
	exact_sources []string // xs: exact source URLs (.torrent file)
	alt_sources   []string // as: acceptable/alternate sources
	keywords      []string // kt: keyword topic
	exact_length  i64      // xl: exact length in bytes
	select_only   []int    // so: select only specific file indices

	// Any additional x.* parameters
	extensions map[string]string
}

pub struct MagnetError {
pub:
	msg   string
	param string
}

fn (e MagnetError) msg() string {
	return 'Magnet error in parameter "${e.param}": ${e.msg}'
}

// Hash types for info_hash parameter
pub enum HashType {
	btih_v1 // BitTorrent Info Hash v1 (SHA-1)
	btmh_v2 // BitTorrent Merkle Hash v2 (SHA-256)
}

pub struct ParsedHash {
pub:
	hash_type HashType
	hash      string
}

// Parse a magnet URI string into a MagnetLink struct
pub fn parse(magnet_uri string) !MagnetLink {
	if !magnet_uri.starts_with('magnet:?') {
		return error(MagnetError{
			msg:   'magnet URI must start with "magnet:?"'
			param: 'uri'
		}.msg())
	}

	// Remove the magnet:? prefix
	query_string := magnet_uri[8..]

	// Parse URL query parameters manually
	params := parse_query_params(query_string)

	mut mag := MagnetLink{}

	// Parse exact topic (info hash) - required parameter
	if xt_values := params['xt'] {
		if xt_values.len == 0 {
			return error(MagnetError{
				msg:   'xt parameter cannot be empty'
				param: 'xt'
			}.msg())
		}

		// Parse the first xt value (primary hash)
		parsed_hash := parse_exact_topic(xt_values[0])!
		match parsed_hash.hash_type {
			.btih_v1 {
				mag.info_hash = parsed_hash.hash
			}
			.btmh_v2 {
				mag.info_hash_v2 = parsed_hash.hash
			}
		}

		// Handle additional xt values (for hybrid torrents)
		for i := 1; i < xt_values.len; i++ {
			additional_hash := parse_exact_topic(xt_values[i])!
			match additional_hash.hash_type {
				.btih_v1 {
					if mag.info_hash.len == 0 {
						mag.info_hash = additional_hash.hash
					}
				}
				.btmh_v2 {
					if mag.info_hash_v2.len == 0 {
						mag.info_hash_v2 = additional_hash.hash
					}
				}
			}
		}
	} else {
		return error(MagnetError{
			msg:   'missing required parameter'
			param: 'xt'
		}.msg())
	}

	// Parse optional parameters
	if dn_values := params['dn'] {
		if dn_values.len > 0 {
			mag.display_name = urllib.query_unescape(dn_values[0]) or { dn_values[0] }
		}
	}

	if tr_values := params['tr'] {
		for tr in tr_values {
			decoded := urllib.query_unescape(tr) or { tr }
			mag.trackers << decoded
		}
	}

	if pe_values := params['x.pe'] {
		for pe in pe_values {
			mag.peers << pe
		}
	}

	// Parse extended parameters
	if ws_values := params['ws'] {
		for ws in ws_values {
			decoded := urllib.query_unescape(ws) or { ws }
			mag.web_seeds << decoded
		}
	}

	if xs_values := params['xs'] {
		for xs in xs_values {
			decoded := urllib.query_unescape(xs) or { xs }
			mag.exact_sources << decoded
		}
	}

	if as_values := params['as'] {
		for as_val in as_values {
			decoded := urllib.query_unescape(as_val) or { as_val }
			mag.alt_sources << decoded
		}
	}

	if kt_values := params['kt'] {
		for kt in kt_values {
			decoded := urllib.query_unescape(kt) or { kt }
			mag.keywords << decoded
		}
	}

	if xl_values := params['xl'] {
		if xl_values.len > 0 {
			mag.exact_length = xl_values[0].i64()
		}
	}

	if so_values := params['so'] {
		if so_values.len > 0 {
			mag.select_only = parse_select_only(so_values[0])!
		}
	}

	// Parse any x.* extension parameters
	for key, values in params {
		if key.starts_with('x.') && key != 'x.pe' {
			if values.len > 0 {
				mag.extensions[key] = values[0]
			}
		}
	}

	return mag
}

// Generate a magnet URI string from a MagnetLink struct
pub fn (m MagnetLink) to_string() string {
	mut params := []string{}

	// Add exact topic (required)
	if m.info_hash.len > 0 {
		params << 'xt=urn:btih:${m.info_hash}'
	}
	if m.info_hash_v2.len > 0 {
		params << 'xt=urn:btmh:${m.info_hash_v2}'
	}

	// Add display name
	if m.display_name.len > 0 {
		encoded := urllib.query_escape(m.display_name)
		params << 'dn=${encoded}'
	}

	// Add trackers
	for tracker in m.trackers {
		encoded := urllib.query_escape(tracker)
		params << 'tr=${encoded}'
	}

	// Add peers
	for peer in m.peers {
		params << 'x.pe=${peer}'
	}

	// Add web seeds
	for ws in m.web_seeds {
		encoded := urllib.query_escape(ws)
		params << 'ws=${encoded}'
	}

	// Add exact sources
	for xs in m.exact_sources {
		encoded := urllib.query_escape(xs)
		params << 'xs=${encoded}'
	}

	// Add alternate sources
	for as_val in m.alt_sources {
		encoded := urllib.query_escape(as_val)
		params << 'as=${encoded}'
	}

	// Add keywords
	for kt in m.keywords {
		encoded := urllib.query_escape(kt)
		params << 'kt=${encoded}'
	}

	// Add exact length
	if m.exact_length > 0 {
		params << 'xl=${m.exact_length}'
	}

	// Add select only
	if m.select_only.len > 0 {
		so_str := format_select_only(m.select_only)
		params << 'so=${so_str}'
	}

	// Add extensions
	for key, value in m.extensions {
		params << '${key}=${value}'
	}

	return 'magnet:?' + params.join('&')
}

// Parse the exact topic parameter (xt)
fn parse_exact_topic(xt string) !ParsedHash {
	if xt.starts_with('urn:btih:') {
		hash := xt[9..]
		if hash.len == 40 {
			// Hex encoding
			if !is_hex(hash) {
				return error(MagnetError{
					msg:   'invalid hex encoding in info hash'
					param: 'xt'
				}.msg())
			}
			return ParsedHash{
				hash_type: .btih_v1
				hash:      hash.to_lower()
			}
		} else if hash.len == 32 {
			// Base32 encoding
			if !is_base32(hash) {
				return error(MagnetError{
					msg:   'invalid base32 encoding in info hash'
					param: 'xt'
				}.msg())
			}
			return ParsedHash{
				hash_type: .btih_v1
				hash:      hash.to_lower()
			}
		} else {
			return error(MagnetError{
				msg:   'info hash must be 40 hex chars or 32 base32 chars'
				param: 'xt'
			}.msg())
		}
	} else if xt.starts_with('urn:btmh:') {
		// BitTorrent v2 multihash
		hash := xt[9..]
		if hash.len < 4 {
			return error(MagnetError{
				msg:   'v2 hash too short'
				param: 'xt'
			}.msg())
		}
		return ParsedHash{
			hash_type: .btmh_v2
			hash:      hash.to_lower()
		}
	}

	return error(MagnetError{
		msg:   'exact topic must start with urn:btih: or urn:btmh:'
		param: 'xt'
	}.msg())
}

// Parse select-only parameter (so)
fn parse_select_only(so string) ![]int {
	mut indices := []int{}

	parts := so.split(',')
	for part in parts {
		part_trimmed := part.trim_space()
		if part_trimmed.contains('-') {
			// Range like "4-7"
			range_parts := part_trimmed.split('-')
			if range_parts.len != 2 {
				return error(MagnetError{
					msg:   'invalid range format in select-only'
					param: 'so'
				}.msg())
			}
			start := range_parts[0].int()
			end := range_parts[1].int()
			if start > end {
				return error(MagnetError{
					msg:   'invalid range: start > end'
					param: 'so'
				}.msg())
			}
			for i := start; i <= end; i++ {
				indices << i
			}
		} else {
			// Single index
			index := part_trimmed.int()
			indices << index
		}
	}

	return indices
}

// Format select-only indices back to string
fn format_select_only(indices []int) string {
	if indices.len == 0 {
		return ''
	}

	mut sorted := indices.clone()
	sorted.sort()

	mut parts := []string{}
	mut start := sorted[0]
	mut end := start

	for i := 1; i < sorted.len; i++ {
		if sorted[i] == end + 1 {
			end = sorted[i]
		} else {
			if start == end {
				parts << '${start}'
			} else {
				parts << '${start}-${end}'
			}
			start = sorted[i]
			end = start
		}
	}

	// Add the last range/index
	if start == end {
		parts << '${start}'
	} else {
		parts << '${start}-${end}'
	}

	return parts.join(',')
}

// Utility functions
fn is_hex(s string) bool {
	// Hex strings should have even length
	if s.len % 2 != 0 {
		return false
	}
	for c in s {
		if !((c >= `0` && c <= `9`) || (c >= `a` && c <= `f`) || (c >= `A` && c <= `F`)) {
			return false
		}
	}
	return true
}

fn is_base32(s string) bool {
	for c in s {
		if !((c >= `A` && c <= `Z`) || (c >= `2` && c <= `7`)) {
			return false
		}
	}
	return true
}

// Parse query parameters manually
fn parse_query_params(query_string string) map[string][]string {
	mut params := map[string][]string{}

	if query_string.len == 0 {
		return params
	}

	parts := query_string.split('&')
	for part in parts {
		if part.len == 0 {
			continue
		}

		kv := part.split_nth('=', 2)
		if kv.len != 2 {
			continue
		}

		key := urllib.query_unescape(kv[0]) or { kv[0] }
		value := urllib.query_unescape(kv[1]) or { kv[1] }

		if key in params {
			params[key] << value
		} else {
			params[key] = [value]
		}
	}

	return params
}

// Helper methods for MagnetLink
pub fn (m MagnetLink) has_v1_hash() bool {
	return m.info_hash.len > 0
}

pub fn (m MagnetLink) has_v2_hash() bool {
	return m.info_hash_v2.len > 0
}

pub fn (m MagnetLink) is_hybrid() bool {
	return m.has_v1_hash() && m.has_v2_hash()
}

pub fn (m MagnetLink) get_primary_hash() string {
	if m.info_hash.len > 0 {
		return m.info_hash
	}
	return m.info_hash_v2
}

pub fn (m MagnetLink) get_all_trackers() []string {
	return m.trackers.clone()
}

pub fn (m MagnetLink) get_all_peers() []string {
	return m.peers.clone()
}
