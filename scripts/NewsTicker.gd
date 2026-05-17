extends Control
##
## Rolling news ticker. Listens for GameState.news_emitted and also
## randomly fires ambient/backlash headlines from headlines.json.
##

@onready var label: Label = $Label

var _queue: Array[String] = []
var _ambient: Array = []
var _backlash: Array = []
var _ambient_timer: float = 0.0
var _scroll_x: float = 0.0
const SCROLL_SPEED := 80.0  # px per second

func _ready() -> void:
	_load_headlines()
	GameState.news_emitted.connect(_on_news)
	# Seed the ticker so it's not empty on launch.
	_enqueue("DROP THE WORLD — booting up. Pick a region to debut in.")

func _process(delta: float) -> void:
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_ambient_timer = randf_range(8.0, 16.0)
		var pool := _ambient
		if GameState.backlash > 30.0 and randf() < 0.4:
			pool = _backlash
		if pool.size() > 0:
			_enqueue(String(pool[randi() % pool.size()]))
	_scroll(delta)

func _scroll(delta: float) -> void:
	_scroll_x -= SCROLL_SPEED * delta
	label.position.x = _scroll_x
	# Use actual rendered text width, not the label's bounding box, so the
	# refresh fires when the text leaves the screen.
	var content_width: float = label.get_minimum_size().x
	if _scroll_x + content_width < 0:
		if _queue.size() > 1:
			_queue.pop_front()
		_refresh_label()

func _enqueue(headline: String) -> void:
	_queue.append(headline)
	if _queue.size() == 1:
		_refresh_label()

func _refresh_label() -> void:
	if _queue.is_empty():
		label.text = ""
		return
	# Show the next ~5 headlines joined so the strip feels populated.
	var joined: String = ""
	var n: int = mini(5, _queue.size())
	for i in range(n):
		joined += "   ◆   " + _queue[i]
	label.text = joined
	_scroll_x = size.x
	label.position.x = _scroll_x

func _on_news(headline: String) -> void:
	_enqueue(headline)

func _load_headlines() -> void:
	var f := FileAccess.open("res://data/headlines.json", FileAccess.READ)
	if f == null:
		push_error("Could not load headlines.json")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_ambient = parsed.get("ambient", [])
	_backlash = parsed.get("backlash", [])
