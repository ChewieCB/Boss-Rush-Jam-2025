extends Control
## Three reel, single payline slot machine played with GameManager.player_currency.
##
## Match three symbols for the big multipliers, or two of the rarer symbols for
## a smaller one. See slot_symbols.gd for the odds and the paytable.

signal closed
## Emitted once the reels have settled. `payout` is 0 on a losing spin.
signal spin_finished(payout: int)

## Chip amounts the player can bet, cheapest first.
const BET_STEPS: Array[int] = [5, 10, 25, 50, 100]
## How long the reels free spin before the first one starts landing.
const FREE_SPIN_TIME: float = 0.9
## Delay between one reel starting to land and the next one following it.
const REEL_STAGGER: float = 0.45
## Pause after the last reel lands before the controls come back.
const PAYOUT_HOLD_TIME: float = 0.6

const COLOR_IDLE := Color(0.85, 0.83, 0.78)
const COLOR_WIN := Color(1.0, 0.84, 0.33)
const COLOR_LOSE := Color(0.78, 0.35, 0.35)

@onready var _reels: Array[SlotReel] = [
	$CenterContainer/Cabinet/Margin/Columns/MachineColumn/ReelPanel/ReelMargin/ReelRow/Reel1,
	$CenterContainer/Cabinet/Margin/Columns/MachineColumn/ReelPanel/ReelMargin/ReelRow/Reel2,
	$CenterContainer/Cabinet/Margin/Columns/MachineColumn/ReelPanel/ReelMargin/ReelRow/Reel3,
]
@onready var result_label: Label = $CenterContainer/Cabinet/Margin/Columns/MachineColumn/ResultLabel
@onready var balance_label: Label = $CenterContainer/Cabinet/Margin/Columns/MachineColumn/BetRow/BalanceLabel
@onready var bet_label: Label = $CenterContainer/Cabinet/Margin/Columns/MachineColumn/BetRow/BetLabel
@onready var bet_down_button: Button = $CenterContainer/Cabinet/Margin/Columns/MachineColumn/BetRow/BetDownButton
@onready var bet_up_button: Button = $CenterContainer/Cabinet/Margin/Columns/MachineColumn/BetRow/BetUpButton
@onready var spin_button: Button = $CenterContainer/Cabinet/Margin/Columns/MachineColumn/SpinButton
@onready var paytable_container: VBoxContainer = $CenterContainer/Cabinet/Margin/Columns/PaytableColumn/PaytableContainer
@onready var close_button: Button = $CloseButton

var _rng := RandomNumberGenerator.new()
var _bet_index: int = 0
var _is_spinning: bool = false


func _ready() -> void:
	_rng.randomize()
	_build_paytable()

	spin_button.pressed.connect(_on_spin_pressed)
	bet_down_button.pressed.connect(_on_bet_changed.bind(-1))
	bet_up_button.pressed.connect(_on_bet_changed.bind(1))
	close_button.pressed.connect(close)
	GameManager.currency_changed.connect(_on_currency_changed)

	for reel in _reels:
		reel.randomize_symbols()
		reel.stopped.connect(_on_reel_stopped)

	_set_result("PLACE YOUR BET", COLOR_IDLE)
	_refresh_controls()


func _unhandled_input(event: InputEvent) -> void:
	if _is_spinning or not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		close()


func open() -> void:
	visible = true
	_refresh_controls()
	spin_button.grab_focus()


func close() -> void:
	if _is_spinning:
		return
	SoundManager.play_button_click_sfx()
	visible = false
	closed.emit()


func get_bet() -> int:
	return BET_STEPS[_bet_index]


func _on_bet_changed(direction: int) -> void:
	var new_index: int = clampi(_bet_index + direction, 0, BET_STEPS.size() - 1)
	if new_index == _bet_index:
		return
	_bet_index = new_index
	SoundManager.play_button_click_sfx()
	_refresh_controls()


func _on_currency_changed(_new_currency: int) -> void:
	_refresh_controls()


func _on_reel_stopped(_symbol_id: SlotSymbols.Id) -> void:
	SoundManager.play_button_click_sfx()


func _on_spin_pressed() -> void:
	if _is_spinning:
		return
	if get_bet() > GameManager.player_currency:
		_set_result("NOT ENOUGH CHIPS", COLOR_LOSE)
		return
	_spin()


func _spin() -> void:
	_is_spinning = true
	_refresh_controls()
	SoundManager.play_button_click_sfx()

	var bet: int = get_bet()
	GameManager.player_currency -= bet
	_set_result("GOOD LUCK", COLOR_IDLE)

	# The outcome is rolled up front, then the reels are told where to land.
	var line: Array[SlotSymbols.Id] = []
	for reel in _reels:
		line.append(SlotSymbols.random_id(_rng))
		reel.clear_win_flash()
		reel.spin()

	await get_tree().create_timer(FREE_SPIN_TIME).timeout

	for i in _reels.size():
		_reels[i].stop_at(line[i])
		if i < _reels.size() - 1:
			await get_tree().create_timer(REEL_STAGGER).timeout

	for reel in _reels:
		if reel.is_spinning():
			await reel.stopped

	_resolve(line, bet)


func _resolve(line: Array[SlotSymbols.Id], bet: int) -> void:
	var score: Dictionary = SlotSymbols.score_line(line)
	var multiplier: int = score["multiplier"]
	var payout: int = multiplier * bet

	if payout > 0:
		GameManager.player_currency += payout
		for reel_index: int in score["reels"]:
			_reels[reel_index].flash_win()

		var label: String = "%s x%d - WIN %d" % [SlotSymbols.NAMES[score["symbol"]], multiplier, payout]
		if score["reels"].size() == 3 and score["symbol"] == SlotSymbols.Id.SEVEN:
			label = "JACKPOT! WIN %d" % payout
		_set_result(label, COLOR_WIN)
	else:
		_set_result("NO LUCK - SPIN AGAIN", COLOR_LOSE)

	await get_tree().create_timer(PAYOUT_HOLD_TIME).timeout

	_is_spinning = false
	_refresh_controls()
	spin_finished.emit(payout)


func _set_result(text: String, color: Color) -> void:
	result_label.text = text
	result_label.modulate = color


func _refresh_controls() -> void:
	var bet: int = get_bet()
	bet_label.text = str(bet)
	balance_label.text = "CHIPS %d" % GameManager.player_currency

	spin_button.disabled = _is_spinning or bet > GameManager.player_currency
	bet_down_button.disabled = _is_spinning or _bet_index == 0
	bet_up_button.disabled = _is_spinning or _bet_index == BET_STEPS.size() - 1
	close_button.disabled = _is_spinning

	if not _is_spinning and bet > GameManager.player_currency:
		_set_result("NOT ENOUGH CHIPS", COLOR_LOSE)


func _build_paytable() -> void:
	for child in paytable_container.get_children():
		child.queue_free()

	# Richest symbol first - that is the one players look for.
	var listed: Array[SlotSymbols.Id] = SlotSymbols.ORDER.duplicate()
	listed.reverse()

	for id: SlotSymbols.Id in listed:
		paytable_container.add_child(_make_paytable_row(id))


func _make_paytable_row(id: SlotSymbols.Id) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon := TextureRect.new()
	icon.texture = SlotSymbols.get_texture(id)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	row.add_child(_make_paytable_label("x3", SlotSymbols.PAYOUT_TRIPLE[id], COLOR_WIN))

	var pair_payout: int = SlotSymbols.PAYOUT_PAIR[id]
	var pair_label: Label = _make_paytable_label("x2", pair_payout, COLOR_IDLE)
	pair_label.modulate.a = 1.0 if pair_payout > 0 else 0.35
	row.add_child(pair_label)

	return row


func _make_paytable_label(prefix: String, payout: int, color: Color) -> Label:
	var label := Label.new()
	label.text = "%s  %s" % [prefix, str(payout) if payout > 0 else "-"]
	label.custom_minimum_size = Vector2(110, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	return label
