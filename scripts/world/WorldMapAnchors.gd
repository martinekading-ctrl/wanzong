class_name WorldMapAnchors
extends RefCounted

## 世界地图标记的唯一逻辑锚点来源。
## 坐标以旧版 4096 逻辑世界归一化，随后由 WorldMapSpec 映射到当前地图。
const LEGACY_LOGICAL_WORLD_SIZE := Vector2(4096.0, 4096.0)

const SECT_ANCHORS_NORMALIZED: Array[Vector2] = [
	Vector2(0.50, 0.52), Vector2(0.24, 0.23), Vector2(0.40, 0.19), Vector2(0.70, 0.23),
	Vector2(0.83, 0.34), Vector2(0.78, 0.53), Vector2(0.82, 0.76), Vector2(0.59, 0.81),
	Vector2(0.30, 0.80), Vector2(0.19, 0.54),
]

const RESOURCE_ANCHORS_NORMALIZED: Array[Vector2] = [
	Vector2(350.0 / 4096.0, 450.0 / 4096.0), Vector2(1050.0 / 4096.0, 420.0 / 4096.0),
	Vector2(2350.0 / 4096.0, 620.0 / 4096.0), Vector2(3720.0 / 4096.0, 720.0 / 4096.0),
	Vector2(3600.0 / 4096.0, 2400.0 / 4096.0), Vector2(2520.0 / 4096.0, 3500.0 / 4096.0),
	Vector2(1200.0 / 4096.0, 3600.0 / 4096.0), Vector2(420.0 / 4096.0, 2550.0 / 4096.0),
	Vector2(410.0 / 4096.0, 1250.0 / 4096.0), Vector2(1900.0 / 4096.0, 520.0 / 4096.0),
	Vector2(2600.0 / 4096.0, 1280.0 / 4096.0), Vector2(3260.0 / 4096.0, 2200.0 / 4096.0),
	Vector2(1450.0 / 4096.0, 2650.0 / 4096.0), Vector2(350.0 / 4096.0, 650.0 / 4096.0),
	Vector2(980.0 / 4096.0, 1350.0 / 4096.0), Vector2(1600.0 / 4096.0, 1250.0 / 4096.0),
	Vector2(2300.0 / 4096.0, 950.0 / 4096.0), Vector2(3600.0 / 4096.0, 1200.0 / 4096.0),
	Vector2(3260.0 / 4096.0, 2850.0 / 4096.0), Vector2(2800.0 / 4096.0, 3600.0 / 4096.0),
	Vector2(1500.0 / 4096.0, 3400.0 / 4096.0), Vector2(600.0 / 4096.0, 3500.0 / 4096.0),
	Vector2(350.0 / 4096.0, 2300.0 / 4096.0), Vector2(2500.0 / 4096.0, 1650.0 / 4096.0),
	Vector2(3800.0 / 4096.0, 3000.0 / 4096.0), Vector2(1100.0 / 4096.0, 2200.0 / 4096.0),
]

const BUILD_SLOT_ANCHORS_NORMALIZED: Array[Vector2] = [
	Vector2(1868.0 / 4096.0, 1928.0 / 4096.0), Vector2(2048.0 / 4096.0, 1868.0 / 4096.0),
	Vector2(2228.0 / 4096.0, 1938.0 / 4096.0), Vector2(1848.0 / 4096.0, 2168.0 / 4096.0),
	Vector2(2068.0 / 4096.0, 2198.0 / 4096.0), Vector2(2268.0 / 4096.0, 2148.0 / 4096.0),
]


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_anchor_group(SECT_ANCHORS_NORMALIZED, 10, "sect", errors)
	_validate_anchor_group(RESOURCE_ANCHORS_NORMALIZED, 26, "resource", errors)
	_validate_anchor_group(BUILD_SLOT_ANCHORS_NORMALIZED, 6, "build_slot", errors)
	return errors


static func _validate_anchor_group(anchors: Array[Vector2], expected_count: int, group_name: String, errors: PackedStringArray) -> void:
	if anchors.size() != expected_count:
		errors.append("%s anchor count must be %d, got %d" % [group_name, expected_count, anchors.size()])
	for index in range(anchors.size()):
		var anchor: Vector2 = anchors[index]
		if anchor.x < 0.0 or anchor.x > 1.0 or anchor.y < 0.0 or anchor.y > 1.0:
			errors.append("%s anchor %d is out of normalized bounds" % [group_name, index])
