module utils

import net.http

pub fn is_valid_url(url string) bool {
	if url.len == 0 {
		return false
	}

	// Basic URL validation - should start with http:// or https://
	if !url.starts_with('http://') && !url.starts_with('https://') && !url.starts_with('udp://') {
		return false
	}

	// Check for basic URL structure
	if !url.contains('://') {
		return false
	}

	parts := url.split('://')
	if parts.len != 2 {
		return false
	}

	domain_and_path := parts[1]
	if domain_and_path.len == 0 {
		return false
	}

	// Extract domain part
	domain_parts := domain_and_path.split('/')
	domain := domain_parts[0]

	if domain.len == 0 {
		return false
	}

	// Basic domain validation
	if domain.contains('..') || domain.starts_with('.') || domain.ends_with('.') {
		return false
	}

	return true
}

pub fn is_valid_tracker_url(url string) bool {
	if !is_valid_url(url) {
		return false
	}

	// Trackers commonly use http, https, or udp protocols
	return url.starts_with('http://') || url.starts_with('https://') || url.starts_with('udp://')
}

pub fn is_valid_filename(filename string) bool {
	if filename.len == 0 {
		return false
	}

	// Check for invalid characters in filenames
	invalid_chars := ['/', '\\', ':', '*', '?', '"', '<', '>', '|']
	for c in invalid_chars {
		if filename.contains(c) {
			return false
		}
	}

	// Check for reserved names on Windows
	reserved_names := ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6',
		'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8',
		'LPT9']

	upper_filename := filename.to_upper()
	for reserved in reserved_names {
		if upper_filename == reserved || upper_filename.starts_with('${reserved}.') {
			return false
		}
	}

	// Check for relative path components
	if filename.contains('..') {
		return false
	}

	return true
}

pub fn is_valid_path_component(component string) bool {
	return is_valid_filename(component) && component != '.' && component != '..'
}

pub fn validate_file_path(path []string) bool {
	if path.len == 0 {
		return false
	}

	for component in path {
		if !is_valid_path_component(component) {
			return false
		}
	}

	return true
}

pub fn is_power_of_two(n i64) bool {
	return n > 0 && (n & (n - 1)) == 0
}

pub fn is_valid_piece_length(length i64) bool {
	// Piece length should be a power of 2 and within reasonable bounds
	min_piece_length := i64(16384) // 16KB
	max_piece_length := i64(33554432) // 32MB

	return is_power_of_two(length) && length >= min_piece_length && length <= max_piece_length
}

pub fn is_valid_hash_length(hash []u8, expected_length int) bool {
	return hash.len == expected_length
}

pub fn is_valid_sha1_hash(hash []u8) bool {
	return is_valid_hash_length(hash, 20)
}

pub fn is_valid_sha256_hash(hash []u8) bool {
	return is_valid_hash_length(hash, 32)
}

pub fn sanitize_filename(filename string) string {
	// Replace invalid characters with underscores
	mut result := filename
	invalid_chars := ['/', '\\', ':', '*', '?', '"', '<', '>', '|']

	for c in invalid_chars {
		result = result.replace(c, '_')
	}

	// Trim whitespace and dots
	result = result.trim_space().trim('.')

	// Ensure it's not empty
	if result.len == 0 {
		result = 'unnamed'
	}

	return result
}

pub fn sanitize_path(path []string) []string {
	mut result := []string{}

	for component in path {
		sanitized := sanitize_filename(component)
		if sanitized.len > 0 && sanitized != '.' && sanitized != '..' {
			result << sanitized
		}
	}

	// Ensure at least one component
	if result.len == 0 {
		result << 'unnamed'
	}

	return result
}

pub fn validate_announce_url(url string) bool {
	if !is_valid_tracker_url(url) {
		return false
	}

	// Additional validation for announce URLs
	// They should typically end with /announce for HTTP trackers
	if url.starts_with('http') {
		return url.contains('/announce') || url.contains('/scrape')
	}

	// UDP trackers don't need specific path validation
	return true
}
