module bencode

import strings
import os

pub fn encode(value BencodeValue) []u8 {
	mut builder := strings.new_builder(1024)
	encode_to_builder(value, mut builder)
	return builder.str().bytes()
}

pub fn encode_to_file(value BencodeValue, path string) ! {
	data := encode(value)
	os.write_file(path, data.bytestr())!
}

fn encode_to_builder(value BencodeValue, mut builder strings.Builder) {
	match value {
		BencodeString {
			builder.write_string('${value.value.len}:')
			builder.write(value.value) or {}
		}
		BencodeInteger {
			builder.write_string('i${value.value}e')
		}
		BencodeList {
			builder.write_u8(`l`)
			for item in value.values {
				encode_to_builder(item, mut builder)
			}
			builder.write_u8(`e`)
		}
		BencodeDictionary {
			builder.write_u8(`d`)
			// Dictionary keys must be sorted
			mut keys := value.pairs.keys()
			keys.sort()
			for key in keys {
				// Encode key as string
				key_bytes := key.bytes()
				builder.write_string('${key_bytes.len}:')
				builder.write(key_bytes) or {}
				// Encode value
				if val := value.pairs[key] {
					encode_to_builder(val, mut builder)
				}
			}
			builder.write_u8(`e`)
		}
	}
}

// Helper function to create bencode values
pub fn bencode_string(s string) BencodeString {
	return BencodeString{value: s.bytes()}
}

pub fn bencode_bytes(b []u8) BencodeString {
	return BencodeString{value: b}
}

pub fn bencode_int(i i64) BencodeInteger {
	return BencodeInteger{value: i}
}

pub fn bencode_list(values ...BencodeValue) BencodeList {
	return BencodeList{values: values}
}

pub fn bencode_dict() BencodeDictionary {
	return BencodeDictionary{pairs: map[string]BencodeValue{}}
}

pub fn (mut d BencodeDictionary) set(key string, value BencodeValue) {
	d.pairs[key] = value
}

pub fn (d BencodeDictionary) get(key string) ?BencodeValue {
	return d.pairs[key] or { return none }
}