extends Node

# 可随机生成的测试弟子姓名。
const TEST_NAMES: Array[String] = [
	"林长歌",
	"苏清雪",
	"叶青玄",
	"楚无尘",
	"顾云舟",
	"陆玄机",
	"沈星河",
	"白初寒",
	"萧问道",
	"秦牧",
]

# 目前 Day 2 只使用三个练气境界。
const TEST_REALMS: Array[String] = [
	"练气一层",
	"练气二层",
	"练气三层",
]

# 当前宗门拥有的弟子列表。
var disciples: Array[DiscipleData] = []

# 随机数工具，用来生成测试数据。
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


# 管理器启动时初始化随机数。
func _ready() -> void:
	rng.randomize()


# 生成指定数量的测试弟子。
func generate_test_disciples(count: int) -> void:
	disciples.clear()

	for index in range(count):
		var disciple: DiscipleData = DiscipleData.new()
		disciple.id = index + 1
		disciple.name = TEST_NAMES[rng.randi_range(0, TEST_NAMES.size() - 1)]
		disciple.age = rng.randi_range(14, 35)
		disciple.realm = TEST_REALMS[rng.randi_range(0, TEST_REALMS.size() - 1)]
		disciple.level = rng.randi_range(1, 3)
		disciple.exp = rng.randi_range(0, 300)
		disciple.aptitude = rng.randi_range(1, 10)
		disciple.luck = rng.randi_range(1, 10)
		disciple.loyalty = rng.randi_range(50, 100)
		disciple.attack = rng.randi_range(10, 50)
		disciple.hp = rng.randi_range(100, 500)
		disciple.calculate_power()

		disciples.append(disciple)


# 获取全部弟子。
func get_all_disciples() -> Array[DiscipleData]:
	return disciples


# 根据编号查找弟子，找不到时返回空。
func get_disciple_by_id(disciple_id: int) -> DiscipleData:
	for disciple in disciples:
		if disciple.id == disciple_id:
			return disciple

	return null
