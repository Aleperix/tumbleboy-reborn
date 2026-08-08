extends RefCounted
# ZipReader — lector ZIP mínimo en GDScript (método store).
# Reemplaza a ZIPReader (no compilado en este Godot). Los packs del editor se
# escriben con zip_writer.gd (store, sin compresión); si un ZIP externo usa
# deflate, read_file devuelve null.
# Port a Godot 4: PoolByteArray -> PackedByteArray, File.new -> FileAccess.

static func _le16(data: PackedByteArray, pos: int) -> int:
	return data[pos] | (data[pos + 1] << 8)

static func _le32(data: PackedByteArray, pos: int) -> int:
	return data[pos] | (data[pos + 1] << 8) | (data[pos + 2] << 16) | (data[pos + 3] << 24)

static func _has_sig(data: PackedByteArray, pos: int, sig: int) -> bool:
	return pos + 4 <= data.size() and data[pos] == (sig & 0xff) and data[pos + 1] == ((sig >> 8) & 0xff) and data[pos + 2] == ((sig >> 16) & 0xff) and data[pos + 3] == ((sig >> 24) & 0xff)

static func _read_all(zip_path: String) -> PackedByteArray:
	var f := FileAccess.open(zip_path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var data := f.get_buffer(f.get_length())
	f.close()
	return data

static func _find_eocd(data: PackedByteArray) -> int:
	var start := int(max(0, data.size() - 65557))
	var i := data.size() - 22
	while i >= start:
		if _has_sig(data, i, 0x06054b50):
			return i
		i -= 1
	return -1

static func get_files(zip_path: String) -> Array:
	var data := _read_all(zip_path)
	if data.size() == 0:
		return []
	var eocd := _find_eocd(data)
	if eocd < 0:
		return []
	var entries := _le16(data, eocd + 10)
	var cd_offset := _le32(data, eocd + 16)
	var names := []
	var pos := cd_offset
	for i in range(entries):
		if not _has_sig(data, pos, 0x02014b50):
			break
		var name_len := _le16(data, pos + 28)
		names.append(data.slice(pos + 46, pos + 46 + name_len).get_string_from_utf8())
		var extra_len := _le16(data, pos + 30)
		var comment_len := _le16(data, pos + 32)
		pos += 46 + name_len + extra_len + comment_len
	return names

static func read_file(zip_path: String, file_name: String):
	var data := _read_all(zip_path)
	if data.size() == 0:
		return null
	var eocd := _find_eocd(data)
	if eocd < 0:
		return null
	var entries := _le16(data, eocd + 10)
	var cd_offset := _le32(data, eocd + 16)
	var pos := cd_offset
	for i in range(entries):
		if not _has_sig(data, pos, 0x02014b50):
			break
		var name_len := _le16(data, pos + 28)
		var name := data.slice(pos + 46, pos + 46 + name_len).get_string_from_utf8()
		if name == file_name:
			var method := _le16(data, pos + 10)
			var csize := _le32(data, pos + 20)
			var local_offset := _le32(data, pos + 42)
			if method != 0:
				return null
			var lname_len := _le16(data, local_offset + 26)
			var lextra_len := _le16(data, local_offset + 28)
			var data_start := local_offset + 30 + lname_len + lextra_len
			return data.slice(data_start, data_start + csize)
		var extra_len := _le16(data, pos + 30)
		var comment_len := _le16(data, pos + 32)
		pos += 46 + name_len + extra_len + comment_len
	return null
