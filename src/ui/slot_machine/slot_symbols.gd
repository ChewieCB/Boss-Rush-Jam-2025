class_name SlotSymbols
extends RefCounted
## Static definition of the slot machine symbol set - art, reel weights and payouts.
##
## Payouts are multipliers applied to the bet. WEIGHTS are the odds of a symbol
## landing on any single reel, out of TOTAL_WEIGHT.
## With the current table the machine returns ~91% of the money bet and pays
## out on roughly one spin in five, which is about what a real three reel
## machine does - the house is meant to grind the player down slowly.

enum Id {
	CHERRY,
	BANANA,
	BELL,
	CLOVER,
	HORSESHOE,
	DIAMOND,
	SEVEN,
}

## Cheapest to richest - also the order the paytable is listed in (reversed).
const ORDER: Array[Id] = [
	Id.CHERRY,
	Id.BANANA,
	Id.BELL,
	Id.CLOVER,
	Id.HORSESHOE,
	Id.DIAMOND,
	Id.SEVEN,
]

const TEXTURES: Dictionary = {
	Id.CHERRY: preload("res://src/ui/slot_machine/sprite/cherry.png"),
	Id.BANANA: preload("res://src/ui/slot_machine/sprite/banana.png"),
	Id.BELL: preload("res://src/ui/slot_machine/sprite/bell.png"),
	Id.CLOVER: preload("res://src/ui/slot_machine/sprite/clover.png"),
	Id.HORSESHOE: preload("res://src/ui/slot_machine/sprite/horseshoe.png"),
	Id.DIAMOND: preload("res://src/ui/slot_machine/sprite/diamond.png"),
	Id.SEVEN: preload("res://src/ui/slot_machine/sprite/number7.png"),
}

const NAMES: Dictionary = {
	Id.CHERRY: "CHERRY",
	Id.BANANA: "BANANA",
	Id.BELL: "BELL",
	Id.CLOVER: "CLOVER",
	Id.HORSESHOE: "HORSESHOE",
	Id.DIAMOND: "DIAMOND",
	Id.SEVEN: "LUCKY SEVEN",
}

## Chance of landing on a reel, out of TOTAL_WEIGHT.
const WEIGHTS: Dictionary = {
	Id.CHERRY: 24,
	Id.BANANA: 20,
	Id.BELL: 16,
	Id.CLOVER: 13,
	Id.HORSESHOE: 11,
	Id.DIAMOND: 9,
	Id.SEVEN: 7,
}

const TOTAL_WEIGHT: int = 100

## Bet multiplier for three matching symbols.
const PAYOUT_TRIPLE: Dictionary = {
	Id.CHERRY: 10,
	Id.BANANA: 12,
	Id.BELL: 16,
	Id.CLOVER: 25,
	Id.HORSESHOE: 40,
	Id.DIAMOND: 80,
	Id.SEVEN: 200,
}

## Bet multiplier for exactly two matching symbols. The two commonest symbols
## pay nothing on a pair, otherwise the machine would pay out more than it takes.
const PAYOUT_PAIR: Dictionary = {
	Id.CHERRY: 0,
	Id.BANANA: 0,
	Id.BELL: 1,
	Id.CLOVER: 1,
	Id.HORSESHOE: 2,
	Id.DIAMOND: 4,
	Id.SEVEN: 8,
}


static func random_id(rng: RandomNumberGenerator) -> Id:
	var roll: int = rng.randi_range(1, TOTAL_WEIGHT)
	for id: Id in ORDER:
		roll -= WEIGHTS[id]
		if roll <= 0:
			return id
	return ORDER[0]


static func get_texture(id: Id) -> Texture2D:
	return TEXTURES[id]


## Scores a line of three reels.
## Returns { "multiplier": int, "symbol": Id, "reels": Array[int] } where reels
## holds the indices of the matching reels. A losing line has multiplier 0 and
## no reels.
static func score_line(line: Array[Id]) -> Dictionary:
	if line[0] == line[1] and line[1] == line[2]:
		return {"multiplier": PAYOUT_TRIPLE[line[0]], "symbol": line[0], "reels": [0, 1, 2]}

	for pair: Array in [[0, 1], [1, 2], [0, 2]]:
		var id: Id = line[pair[0]]
		if id == line[pair[1]] and PAYOUT_PAIR[id] > 0:
			return {"multiplier": PAYOUT_PAIR[id], "symbol": id, "reels": pair}

	return {"multiplier": 0, "symbol": line[0], "reels": []}
