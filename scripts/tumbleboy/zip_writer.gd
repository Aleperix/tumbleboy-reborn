extends Reference
# ZIPWriter — escritor ZIP mínimo en GDScript (método store, sin compresión).
# Suficiente para que el editor empaquete packs: manifest.json + niveles .txt.
# Godot 3 escribe big-endian con File.store_32, así que escribimos LE a mano.

static func _le16(f, v: int):
	f.store_8(v & 0xff)
	f.store_8((v >> 8) & 0xff)

static func _le32(f, v: int):
	f.store_8(v & 0xff)
	f.store_8((v >> 8) & 0xff)
	f.store_8((v >> 16) & 0xff)
	f.store_8((v >> 24) & 0xff)

static func _crc_table() -> Array:
	var table := []
	for i in range(256):
		var c := i
		for j in range(8):
			if c & 1:
				c = (c >> 1) ^ 0xEDB88320
			else:
				c = c >> 1
		table.append(c)
	return table

static func crc32(data: PoolByteArray) -> int:
	var table := _crc_table()
	var c := 0xFFFFFFFF
	for i in range(data.size()):
		c = table[(c ^ data[i]) & 0xff] ^ (c >> 8)
	return c ^ 0xFFFFFFFF

static func _cd_le16(cd: Array, v: int):
	cd.append(v & 0xff)
	cd.append((v >> 8) & 0xff)

static func _cd_le32(cd: Array, v: int):
	cd.append(v & 0xff)
	cd.append((v >> 8) & 0xff)
	cd.append((v >> 16) & 0xff)
	cd.append((v >> 24) & 0xff)

# files: { "ruta/dentro.zip": "contenido texto", ... }
static func write_pack_zip(zip_path: String, files: Dictionary) -> bool:
	var f := File.new()
	if f.open(zip_path, File.WRITE) != OK:
		return false
	var cd: Array = []
	var cd_offset := 0
	var local_offset := 0
	var count := 0
	for name in files:
		var data: PoolByteArray = str(files[name]).to_utf8()
		var name_b: PoolByteArray = name.to_utf8()
		var crc := crc32(data)

		# cabecera local
		_le32(f, 0x04034b50)
		_le16(f, 20)
		_le16(f, 0x0800) # flag UTF-8
		_le16(f, 0)      # método store
		_le16(f, 0)      # mtime
		_le16(f, 0)      # mdate
		_le32(f, crc)
		_le32(f, data.size())
		_le32(f, data.size())
		_le16(f, name_b.size())
		_le16(f, 0)      # extra
		f.store_buffer(name_b)
		f.store_buffer(data)

		# directorio central
		_cd_le32(cd, 0x02014b50)
		_cd_le16(cd, 20)
		_cd_le16(cd, 20)
		_cd_le16(cd, 0x0800)
		_cd_le16(cd, 0)
		_cd_le16(cd, 0)
		_cd_le16(cd, 0)
		_cd_le32(cd, crc)
		_cd_le32(cd, data.size())
		_cd_le32(cd, data.size())
		_cd_le16(cd, name_b.size())
		_cd_le16(cd, 0)  # extra
		_cd_le16(cd, 0)  # comment
		_cd_le16(cd, 0)  # disk
		_cd_le16(cd, 0)  # attrs internos
		_cd_le32(cd, 0)  # attrs externos
		_cd_le32(cd, local_offset)
		cd.append_array(name_b)

		local_offset += 30 + name_b.size() + data.size()
		count += 1

	cd_offset = local_offset
	f.store_buffer(PoolByteArray(cd))

	# fin del directorio central
	_le32(f, 0x06054b50)
	_le16(f, 0)
	_le16(f, 0)
	_le16(f, count)
	_le16(f, count)
	_le32(f, cd.size())
	_le32(f, cd_offset)
	_le16(f, 0)
	f.close()
	return true
