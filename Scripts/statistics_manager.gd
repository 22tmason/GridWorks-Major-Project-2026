extends Node

var production_history: Dictionary = {}

func log_production(item_id: String, amount: int = 1) -> void:
	var current_time = Time.get_ticks_msec()
	if not production_history.has(item_id):
		production_history[item_id] = []
	for i in range(amount):
		production_history[item_id].append(current_time)

# Gets total produced in the last X seconds
func get_production_count(item_id: String, window_sec: float) -> int:
	if not production_history.has(item_id): return 0
	
	var current_time = Time.get_ticks_msec()
	var cutoff = current_time - int(window_sec * 1000)
	var history = production_history[item_id]
	
	# Prevent memory leaks by cleaning up data older than 1 hour
	var max_cutoff = current_time - 3600000 
	while history.size() > 0 and history[0] < max_cutoff:
		history.pop_front()
		
	var count = 0
	for i in range(history.size() - 1, -1, -1):
		if history[i] >= cutoff:
			count += 1
		else:
			break
	return count

# Returns an array of bucketed counts for the line graph
func get_graph_data(item_id: String, window_sec: float, points: int) -> Array[int]:
	var data: Array[int] = []
	data.resize(points)
	data.fill(0)
	
	if not production_history.has(item_id): return data
	
	var current_time = Time.get_ticks_msec()
	var history = production_history[item_id]
	var bucket_duration = (window_sec * 1000.0) / points
	
	for t in history:
		var age = current_time - t
		if age <= window_sec * 1000.0:
			var bucket_idx = points - 1 - int(age / bucket_duration)
			if bucket_idx >= 0 and bucket_idx < points:
				data[bucket_idx] += 1
				
	return data
