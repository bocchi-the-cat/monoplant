extends Node
## Run-wide state: money, progression, and the numbers the economy hangs off.

const START_MONEY := 60
const START_POTS := 6
const MAX_POTS := 18

var money: int = START_MONEY
var total_earned: int = 0
var pots_owned: int = START_POTS
var spent_total: int = 0
var plants_harvested: int = 0
var deliveries_made: int = 0


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	money = START_MONEY
	total_earned = 0
	pots_owned = START_POTS
	spent_total = 0
	plants_harvested = 0
	deliveries_made = 0
	EventBus.money_changed.emit(money, 0)


func add_money(amount: int) -> void:
	if amount == 0:
		return
	money += amount
	if amount > 0:
		total_earned += amount
	EventBus.money_changed.emit(money, amount)


func spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if money < amount:
		return false
	money -= amount
	spent_total += amount
	EventBus.money_changed.emit(money, -amount)
	return true


func can_afford(amount: int) -> bool:
	return money >= amount


func is_unlocked(flower_id: String) -> bool:
	return FlowerDB.unlocked(flower_id, total_earned)


func next_unlock() -> Dictionary:
	var best := {}
	for id in FlowerDB.all_ids():
		var data := FlowerDB.get_flower(id)
		var need := int(data.get("unlock_earned", 0))
		if need > total_earned:
			if best.is_empty() or need < int(best.get("unlock_earned", 0)):
				best = data.duplicate()
				best["id"] = id
	return best


func add_pot() -> bool:
	if pots_owned >= MAX_POTS:
		return false
	pots_owned += 1
	return true
