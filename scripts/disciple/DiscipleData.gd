extends RefCounted
class_name DiscipleData

# 弟子唯一编号。
var id: int = 0

# 弟子姓名。
var name: String = ""

# 弟子年龄。
var age: int = 0

# 弟子境界。
var realm: String = ""

# 弟子等级。
var level: int = 1

# 弟子当前经验。
var exp: int = 0

# 资质，影响弟子潜力。
var aptitude: int = 1

# 气运，影响随机事件表现。
var luck: int = 1

# 忠诚，影响弟子稳定性。
var loyalty: int = 50

# 攻击力。
var attack: int = 1

# 生命值。
var hp: int = 10

# 战力，由属性计算得到。
var power: int = 0


# 根据弟子当前属性计算战力。
func calculate_power() -> int:
	power = attack * 10 + hp + level * 100 + aptitude * 30 + luck * 10 + loyalty * 5
	return power
