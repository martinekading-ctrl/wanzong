extends Node

const DAILY_BASE_INCOME: int = 10
const DAILY_DISCIPLE_COST: int = 5


func daily_update(sect: SectData = GameState.player_sect) -> Dictionary:
	if sect == null or sect.id == "":
		push_warning("EconomyManager：没有可结算的玩家宗门。")
		return {}
	var income: int = DAILY_BASE_INCOME
	var cost: int = sect.disciples_count * DAILY_DISCIPLE_COST
	var before_amount: int = sect.spirit_stone
	sect.add_resource("spirit_stone", income)
	sect.consume_resource("spirit_stone", mini(cost, sect.spirit_stone))
	return {
		"income": income,
		"cost": cost,
		"spirit_stone_change": sect.spirit_stone - before_amount,
	}
