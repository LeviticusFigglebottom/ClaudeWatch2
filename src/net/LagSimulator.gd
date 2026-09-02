class_name LagSimulator
extends RefCounted
## Client-side network condition simulator: delays, jitters and drops callables (send & receive).

var latency_ms: int = 0
var loss: float = 0.0
var jitter_ms: int = 0
var _queue: Array = []   # [fire_time, callable]
var _time: float = 0.0
var rng := RandomNumberGenerator.new()


func configure(ms: int, l: float, j: int) -> void:
	latency_ms = ms; loss = l; jitter_ms = j


func enabled() -> bool:
	return latency_ms > 0 or loss > 0.0 or jitter_ms > 0


func send(c: Callable) -> void:
	_enqueue(c)


func receive(c: Callable) -> void:
	_enqueue(c)


func _enqueue(c: Callable) -> void:
	if not enabled():
		c.call()
		return
	if loss > 0.0 and rng.randf() < loss:
		return
	var delay := (latency_ms * 0.5 + rng.randf_range(0.0, jitter_ms)) / 1000.0
	_queue.append([_time + delay, c])


func step(dt: float) -> void:
	_time += dt
	if _queue.is_empty():
		return
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	while not _queue.is_empty() and float(_queue[0][0]) <= _time:
		var e: Array = _queue.pop_front()
		(e[1] as Callable).call()
