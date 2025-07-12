module torrent

import bencode

fn test_parse_simple_single_file_torrent() {
	// Create a minimal single-file torrent structure
	mut info_dict := map[string]bencode.BencodeValue{}
	info_dict['name'] = bencode.BencodeString{ value: 'test.txt'.bytes() }
	info_dict['piece length'] = bencode.BencodeInteger{ value: 32768 }
	info_dict['pieces'] = bencode.BencodeString{ value: [u8(0x01), 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67] }
	info_dict['length'] = bencode.BencodeInteger{ value: 1024 }
	
	mut root_dict := map[string]bencode.BencodeValue{}
	root_dict['announce'] = bencode.BencodeString{ value: 'http://tracker.example.com:8080/announce'.bytes() }
	root_dict['info'] = bencode.BencodeDictionary{ pairs: info_dict }
	
	root := bencode.BencodeDictionary{ pairs: root_dict }
	data := bencode.encode(root)
	
	// Parse the torrent
	result := parse_torrent_data(data) or { panic(err) }
	
	// Verify basic fields
	assert result.announce == 'http://tracker.example.com:8080/announce'
	assert result.info.name == 'test.txt'
	assert result.info.piece_length == 32768
	assert result.info.pieces.len == 20
	assert result.info.length or { 0 } == 1024
	assert result.is_single_file()
	assert !result.is_multi_file()
	assert result.total_size() == 1024
	assert result.file_count() == 1
	assert result.piece_count() == 1
}

fn test_parse_multi_file_torrent() {
	// Create a multi-file torrent structure
	mut file1 := map[string]bencode.BencodeValue{}
	file1['length'] = bencode.BencodeInteger{ value: 512 }
	file1['path'] = bencode.BencodeList{ values: [
		bencode.BencodeString{ value: 'dir1'.bytes() },
		bencode.BencodeString{ value: 'file1.txt'.bytes() }
	] }
	
	mut file2 := map[string]bencode.BencodeValue{}
	file2['length'] = bencode.BencodeInteger{ value: 1024 }
	file2['path'] = bencode.BencodeList{ values: [
		bencode.BencodeString{ value: 'dir2'.bytes() },
		bencode.BencodeString{ value: 'file2.txt'.bytes() }
	] }
	
	files_list := bencode.BencodeList{ values: [
		bencode.BencodeDictionary{ pairs: file1 },
		bencode.BencodeDictionary{ pairs: file2 }
	] }
	
	mut info_dict := map[string]bencode.BencodeValue{}
	info_dict['name'] = bencode.BencodeString{ value: 'test_directory'.bytes() }
	info_dict['piece length'] = bencode.BencodeInteger{ value: 32768 }
	info_dict['pieces'] = bencode.BencodeString{ value: [u8(0x01), 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67] }
	info_dict['files'] = files_list
	
	mut root_dict := map[string]bencode.BencodeValue{}
	root_dict['announce'] = bencode.BencodeString{ value: 'http://tracker.example.com:8080/announce'.bytes() }
	root_dict['info'] = bencode.BencodeDictionary{ pairs: info_dict }
	
	root := bencode.BencodeDictionary{ pairs: root_dict }
	data := bencode.encode(root)
	
	// Parse the torrent
	result := parse_torrent_data(data) or { panic(err) }
	
	// Verify basic fields
	assert result.announce == 'http://tracker.example.com:8080/announce'
	assert result.info.name == 'test_directory'
	assert result.info.piece_length == 32768
	assert result.info.pieces.len == 20
	assert !result.is_single_file()
	assert result.is_multi_file()
	assert result.total_size() == 1536 // 512 + 1024
	assert result.file_count() == 2
	assert result.piece_count() == 1
	
	// Verify files
	assert result.info.files.len == 2
	assert result.info.files[0].length == 512
	assert result.info.files[0].path == ['dir1', 'file1.txt']
	assert result.info.files[1].length == 1024
	assert result.info.files[1].path == ['dir2', 'file2.txt']
}

fn test_parse_torrent_with_optional_fields() {
	// Create torrent with optional fields
	mut info_dict := map[string]bencode.BencodeValue{}
	info_dict['name'] = bencode.BencodeString{ value: 'test.txt'.bytes() }
	info_dict['piece length'] = bencode.BencodeInteger{ value: 32768 }
	info_dict['pieces'] = bencode.BencodeString{ value: [u8(0x01), 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67] }
	info_dict['length'] = bencode.BencodeInteger{ value: 1024 }
	info_dict['private'] = bencode.BencodeInteger{ value: 1 }
	info_dict['md5sum'] = bencode.BencodeString{ value: 'd41d8cd98f00b204e9800998ecf8427e'.bytes() }
	
	// Announce list with multiple tiers
	tier1 := bencode.BencodeList{ values: [
		bencode.BencodeString{ value: 'http://tracker1.example.com:8080/announce'.bytes() },
		bencode.BencodeString{ value: 'http://tracker2.example.com:8080/announce'.bytes() }
	] }
	tier2 := bencode.BencodeList{ values: [
		bencode.BencodeString{ value: 'http://backup.example.com:8080/announce'.bytes() }
	] }
	announce_list := bencode.BencodeList{ values: [tier1, tier2] }
	
	mut root_dict := map[string]bencode.BencodeValue{}
	root_dict['announce'] = bencode.BencodeString{ value: 'http://tracker.example.com:8080/announce'.bytes() }
	root_dict['announce-list'] = announce_list
	root_dict['creation date'] = bencode.BencodeInteger{ value: 1640995200 } // 2022-01-01
	root_dict['comment'] = bencode.BencodeString{ value: 'Test torrent'.bytes() }
	root_dict['created by'] = bencode.BencodeString{ value: 'magnetar/0.1.0'.bytes() }
	root_dict['encoding'] = bencode.BencodeString{ value: 'UTF-8'.bytes() }
	root_dict['info'] = bencode.BencodeDictionary{ pairs: info_dict }
	
	root := bencode.BencodeDictionary{ pairs: root_dict }
	data := bencode.encode(root)
	
	// Parse the torrent
	result := parse_torrent_data(data) or { panic(err) }
	
	// Verify basic fields
	assert result.announce == 'http://tracker.example.com:8080/announce'
	assert result.info.name == 'test.txt'
	assert result.info.private or { false } == true
	assert result.info.md5sum or { '' } == 'd41d8cd98f00b204e9800998ecf8427e'
	
	// Verify optional root fields
	assert result.creation_date or { 0 } == 1640995200
	assert result.comment or { '' } == 'Test torrent'
	assert result.created_by or { '' } == 'magnetar/0.1.0'
	assert result.encoding or { '' } == 'UTF-8'
	
	// Verify announce list
	assert result.announce_list.len == 2
	assert result.announce_list[0].len == 2
	assert result.announce_list[1].len == 1
	assert 'http://tracker1.example.com:8080/announce' in result.announce_list[0]
	assert 'http://tracker2.example.com:8080/announce' in result.announce_list[0]
	assert 'http://backup.example.com:8080/announce' in result.announce_list[1]
	
	// Test tracker list extraction
	trackers := result.get_trackers()
	assert trackers.len == 4
	assert 'http://tracker.example.com:8080/announce' in trackers
	assert 'http://tracker1.example.com:8080/announce' in trackers
	assert 'http://backup.example.com:8080/announce' in trackers
}

fn test_parse_invalid_torrents() {
	// Test invalid root structure (not a dictionary)
	data1 := 'l4:spam4:eggse'.bytes() // This is a list, not a dict
	if _ := parse_torrent_data(data1) {
		panic('should have failed on non-dictionary root')
	}
	
	// Test missing announce field
	mut info_dict := map[string]bencode.BencodeValue{}
	info_dict['name'] = bencode.BencodeString{ value: 'test.txt'.bytes() }
	info_dict['piece length'] = bencode.BencodeInteger{ value: 32768 }
	info_dict['pieces'] = bencode.BencodeString{ value: [u8(0x01), 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67] }
	info_dict['length'] = bencode.BencodeInteger{ value: 1024 }
	
	mut root_dict := map[string]bencode.BencodeValue{}
	// Missing announce field
	root_dict['info'] = bencode.BencodeDictionary{ pairs: info_dict }
	
	root := bencode.BencodeDictionary{ pairs: root_dict }
	data2 := bencode.encode(root)
	
	if _ := parse_torrent_data(data2) {
		panic('should have failed on missing announce field')
	}
	
	// Test missing info field
	mut root_dict3 := map[string]bencode.BencodeValue{}
	root_dict3['announce'] = bencode.BencodeString{ value: 'http://tracker.example.com:8080/announce'.bytes() }
	// Missing info field
	
	root3 := bencode.BencodeDictionary{ pairs: root_dict3 }
	data3 := bencode.encode(root3)
	
	if _ := parse_torrent_data(data3) {
		panic('should have failed on missing info field')
	}
}

fn test_info_hash_calculation() {
	// Create a simple torrent
	mut info_dict := map[string]bencode.BencodeValue{}
	info_dict['name'] = bencode.BencodeString{ value: 'test.txt'.bytes() }
	info_dict['piece length'] = bencode.BencodeInteger{ value: 32768 }
	info_dict['pieces'] = bencode.BencodeString{ value: [u8(0x01), 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67] }
	info_dict['length'] = bencode.BencodeInteger{ value: 1024 }
	
	mut root_dict := map[string]bencode.BencodeValue{}
	root_dict['announce'] = bencode.BencodeString{ value: 'http://tracker.example.com:8080/announce'.bytes() }
	root_dict['info'] = bencode.BencodeDictionary{ pairs: info_dict }
	
	root := bencode.BencodeDictionary{ pairs: root_dict }
	data := bencode.encode(root)
	
	// Parse the torrent
	result := parse_torrent_data(data) or { panic(err) }
	
	// The info hash should be calculated correctly
	assert result.info_hash.len == 20
	
	// Verify that the info hash is not all zeros (should be an actual hash)
	mut all_zeros := true
	for b in result.info_hash {
		if b != 0 {
			all_zeros = false
			break
		}
	}
	assert !all_zeros
}

fn test_torrent_validation() {
	// Create a valid torrent
	mut info_dict := map[string]bencode.BencodeValue{}
	info_dict['name'] = bencode.BencodeString{ value: 'test.txt'.bytes() }
	info_dict['piece length'] = bencode.BencodeInteger{ value: 32768 }
	info_dict['pieces'] = bencode.BencodeString{ value: [u8(0x01), 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67] }
	info_dict['length'] = bencode.BencodeInteger{ value: 32768 } // Exactly one piece
	
	mut root_dict := map[string]bencode.BencodeValue{}
	root_dict['announce'] = bencode.BencodeString{ value: 'http://tracker.example.com:8080/announce'.bytes() }
	root_dict['info'] = bencode.BencodeDictionary{ pairs: info_dict }
	
	root := bencode.BencodeDictionary{ pairs: root_dict }
	data := bencode.encode(root)
	
	// Parse and validate the torrent
	result := parse_torrent_data(data) or { panic(err) }
	validate_torrent(result) or { panic(err) }
}