class_name SlotReel
extends Control
## A single spinning reel showing one symbol at a time.
##
## The reel owns three tiles - one above the window, one in it, one below - and
## scrolls them downwards, recycling the bottom tile back to the top with a new
## random symbol every time a full cell has passed. Calling stop_at() eases the
## reel down over a few more cells and lands on the symbol it was given.

signal stopped(symbol_id: SlotSymbols.Id)

## Scroll speed while free spinning, in symbols per second.
const SPIN_SPEED: float = 16.0
## Scroll speed of the very last symbol before the reel lands.
const LANDING_SPEED: float = 3.0
## How many symbols pass by between stop_at() and the reel coming to rest.
const STOP_CELLS: int = 7

const TILE_COUNT: int = 3
const SYMBOL_META: StringName = &"symbol_id"

enum State { IDLE, SPINNING, STOPPING }

var _tiles: Array[TextureRect] = []
var _rng := RandomNumberGenerator.new()
var _state: State = State.IDLE
var _speed: float = 0.0
## Position within the current cell, 0..1, growing downwards.
var _scroll: float = 0.0
## Extra offset used by the landing bounce, in cells.
var _bounce: float = 0.0
var _cells_left: int = 0
var _target: SlotSymbols.Id = SlotSymbols.Id.CHERRY
var _bounce_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	_rng.randomize()
	clip_contents = true

	for i in TILE_COUNT:
		var tile := TextureRect.new()
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tile)
		_tiles.append(tile)

	resized.connect(_layout)
	set_process(false)
	randomize_symbols()


func _process(delta: float) -> void:
	_scroll += _speed * delta

	while _scroll >= 1.0:
		_scroll -= 1.0
		if not _advance():
			return

	if _state == State.STOPPING:
		# Ease the reel down over the remaining cells so it settles instead of
		# snapping to a halt.
		var cells_to_go: float = float(_cells_left) - _scroll
		var t: float = clampf(cells_to_go / float(STOP_CELLS), 0.0, 1.0)
		_speed = lerpf(LANDING_SPEED, SPIN_SPEED, ease(t, 0.45))

	_layout()


## Fills the reel with random symbols without any animation.
func randomize_symbols() -> void:
	for tile in _tiles:
		_set_tile_symbol(tile, SlotSymbols.random_id(_rng))
	_scroll = 0.0
	_bounce = 0.0
	_layout()


func spin() -> void:
	if _bounce_tween and _bounce_tween.is_running():
		_bounce_tween.kill()
	_bounce = 0.0
	_state = State.SPINNING
	_speed = SPIN_SPEED
	set_process(true)


## Brings a spinning reel to rest on `symbol_id`.
func stop_at(symbol_id: SlotSymbols.Id) -> void:
	if _state != State.SPINNING:
		return
	_state = State.STOPPING
	_target = symbol_id
	_cells_left = STOP_CELLS


func is_spinning() -> bool:
	return _state != State.IDLE


## The symbol currently sitting in the window.
func get_symbol() -> SlotSymbols.Id:
	return _tiles[1].get_meta(SYMBOL_META)


## Pulses the symbol in the window to call out a win.
func flash_win() -> void:
	clear_win_flash()
	var tile: TextureRect = _tiles[1]
	_flash_tween = create_tween()
	_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flash_tween.set_loops(3)
	_flash_tween.tween_property(tile, "modulate", Color(2.2, 2.0, 1.2), 0.14)
	_flash_tween.tween_property(tile, "modulate", Color.WHITE, 0.18)


func clear_win_flash() -> void:
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	for tile in _tiles:
		tile.modulate = Color.WHITE


## Recycles the bottom tile back to the top. Returns false once the reel has
## come to rest, so _process knows to bail out.
func _advance() -> bool:
	if _state == State.STOPPING:
		_cells_left -= 1
		# The tile currently on top is the one that lands in the window after
		# this rotation, so it is the one that has to carry the target symbol.
		if _cells_left <= 0:
			_set_tile_symbol(_tiles[0], _target)

	var recycled: TextureRect = _tiles.pop_back()
	_tiles.push_front(recycled)

	if _state == State.STOPPING and _cells_left <= 0:
		_land()
		return false

	_set_tile_symbol(recycled, SlotSymbols.random_id(_rng))
	return true


func _land() -> void:
	_scroll = 0.0
	_speed = 0.0
	_state = State.IDLE
	set_process(false)
	_layout()
	_play_bounce()
	stopped.emit(get_symbol())


func _play_bounce() -> void:
	if _bounce_tween and _bounce_tween.is_running():
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_bounce_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_bounce_tween.tween_method(_set_bounce, 0.14, 0.0, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _set_bounce(value: float) -> void:
	_bounce = value
	_layout()


func _set_tile_symbol(tile: TextureRect, symbol_id: SlotSymbols.Id) -> void:
	tile.set_meta(SYMBOL_META, symbol_id)
	tile.texture = SlotSymbols.get_texture(symbol_id)
	tile.modulate = Color.WHITE


func _layout() -> void:
	var cell: float = maxf(size.y, 1.0)
	var offset: float = (_scroll + _bounce) * cell
	for i in _tiles.size():
		var tile: TextureRect = _tiles[i]
		tile.size = Vector2(size.x, cell)
		tile.position = Vector2(0.0, (i - 1) * cell + offset)
