class_name WorldSectRoster
extends RefCounted

## 正式世界初始宗门名册的唯一来源。
## 后续动态分宗仍可新增宗门；本名册只约束开局固定实例。

const ROSTER_VERSION: int = 2
const PLAYER_SECT_ID := "sect_001"
const ACTIVE_SECT_IDS: Array[String] = [
	"sect_001",
	"sect_002",
	"sect_003",
	"sect_004",
	"sect_005",
]
const AI_SECT_IDS: Array[String] = [
	"sect_002",
	"sect_003",
	"sect_004",
	"sect_005",
]
const REMOVED_DEVELOPMENT_SECT_IDS: Array[String] = [
	"sect_006",
	"sect_007",
	"sect_008",
	"sect_009",
	"sect_010",
]


static func expected_sect_count() -> int:
	return ACTIVE_SECT_IDS.size()


static func expected_ai_sect_count() -> int:
	return AI_SECT_IDS.size()


static func is_active_sect_id(sect_id: String) -> bool:
	return sect_id in ACTIVE_SECT_IDS


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if ACTIVE_SECT_IDS.size() != 5:
		errors.append("active roster must contain exactly five initial sects")
	if AI_SECT_IDS.size() != 4:
		errors.append("active roster must contain exactly four AI sects")
	if ACTIVE_SECT_IDS.is_empty() or ACTIVE_SECT_IDS[0] != PLAYER_SECT_ID:
		errors.append("player sect must be the first active roster entry")
	for sect_id in AI_SECT_IDS:
		if sect_id == PLAYER_SECT_ID or not sect_id in ACTIVE_SECT_IDS:
			errors.append("AI roster contains invalid sect id: " + sect_id)
	for sect_id in REMOVED_DEVELOPMENT_SECT_IDS:
		if sect_id in ACTIVE_SECT_IDS:
			errors.append("removed development sect remains active: " + sect_id)
	return errors
