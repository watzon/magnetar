module bencode

pub type BencodeValue = BencodeString | BencodeInteger | BencodeList | BencodeDictionary

pub struct BencodeString {
pub:
	value []u8
}

pub struct BencodeInteger {
pub:
	value i64
}

pub struct BencodeList {
pub:
	values []BencodeValue
}

pub struct BencodeDictionary {
pub mut:
	pairs map[string]BencodeValue
}

pub fn (v BencodeValue) str() string {
	match v {
		BencodeString { return 'String(${v.value.len} bytes)' }
		BencodeInteger { return 'Integer(${v.value})' }
		BencodeList { return 'List(${v.values.len} items)' }
		BencodeDictionary { return 'Dictionary(${v.pairs.len} pairs)' }
	}
}

pub fn (v BencodeValue) as_string() ?string {
	match v {
		BencodeString { return v.value.bytestr() }
		else { return none }
	}
}

pub fn (v BencodeValue) as_int() ?i64 {
	match v {
		BencodeInteger { return v.value }
		else { return none }
	}
}

pub fn (v BencodeValue) as_list() ?[]BencodeValue {
	match v {
		BencodeList { return v.values }
		else { return none }
	}
}

pub fn (v BencodeValue) as_dict() ?map[string]BencodeValue {
	match v {
		BencodeDictionary { return v.pairs }
		else { return none }
	}
}
