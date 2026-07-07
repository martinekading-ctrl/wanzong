extends Control

# 生成测试弟子按钮。
@onready var generate_button: Button = $MarginContainer/RootBox/ButtonBar/GenerateButton

# 返回主菜单按钮。
@onready var back_button: Button = $MarginContainer/RootBox/ButtonBar/BackButton

# 显示弟子数量的文本。
@onready var disciple_count_label: Label = $MarginContainer/RootBox/TopBar/DiscipleCountLabel

# 显示宗门总战力的文本。
@onready var power_label: Label = $MarginContainer/RootBox/TopBar/PowerLabel

# 左侧弟子列表。
@onready var disciple_list: ItemList = $MarginContainer/RootBox/ContentBox/ListBox/DiscipleList

# 右侧弟子详情。
@onready var disciple_detail_label: Label = $MarginContainer/RootBox/ContentBox/DetailBox/DiscipleDetailLabel


# 场景准备好后，绑定按钮点击事件。
func _ready() -> void:
	generate_button.pressed.connect(_on_generate_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	disciple_list.item_selected.connect(_on_disciple_selected)
	_refresh_disciple_list()
	_refresh_summary()


# 点击“生成测试弟子”后，生成 20 个测试弟子。
func _on_generate_button_pressed() -> void:
	DiscipleManager.generate_test_disciples(20)
	_refresh_disciple_list()
	_refresh_summary()
	disciple_detail_label.text = "已生成 20 名测试弟子，请从左侧选择一名弟子。"


# 点击“返回主菜单”后，回到主菜单。
func _on_back_button_pressed() -> void:
	SceneManager.go_to_main_menu()


# 点击左侧弟子列表后，显示弟子详情。
func _on_disciple_selected(index: int) -> void:
	var disciple_id: int = int(disciple_list.get_item_metadata(index))
	var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
	if disciple == null:
		disciple_detail_label.text = "没有找到这个弟子。"
		return

	_show_disciple_detail(disciple)


# 刷新左侧弟子列表。
func _refresh_disciple_list() -> void:
	disciple_list.clear()

	for disciple in DiscipleManager.get_all_disciples():
		var item_text: String = "%s  %s  战力：%d" % [disciple.name, disciple.realm, disciple.power]
		disciple_list.add_item(item_text)
		var item_index: int = disciple_list.get_item_count() - 1
		disciple_list.set_item_metadata(item_index, disciple.id)


# 刷新顶部弟子数量和宗门总战力。
func _refresh_summary() -> void:
	var disciples: Array[DiscipleData] = DiscipleManager.get_all_disciples()
	var total_power: int = 0

	for disciple in disciples:
		total_power += disciple.power

	disciple_count_label.text = "弟子：" + str(disciples.size())
	power_label.text = "战力：" + str(total_power)


# 显示单名弟子的详细属性。
func _show_disciple_detail(disciple: DiscipleData) -> void:
	disciple_detail_label.text = "\n".join(PackedStringArray([
		"编号：" + str(disciple.id),
		"姓名：" + disciple.name,
		"年龄：" + str(disciple.age),
		"境界：" + disciple.realm,
		"等级：" + str(disciple.level),
		"经验：" + str(disciple.exp),
		"资质：" + str(disciple.aptitude),
		"气运：" + str(disciple.luck),
		"忠诚：" + str(disciple.loyalty),
		"攻击：" + str(disciple.attack),
		"生命：" + str(disciple.hp),
		"战力：" + str(disciple.power),
	]))
