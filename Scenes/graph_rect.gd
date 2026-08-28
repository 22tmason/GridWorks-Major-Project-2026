extends ColorRect

var graph_data: Dictionary = {} # Key: item_id, Value: Array of counts
var item_colors: Dictionary = {} # Key: item_id, Value: Color

func _draw() -> void:
	if graph_data.is_empty(): return
	
	# Find the highest peak so we can scale the graph properly
	var max_val = 1
	for item in graph_data:
		for val in graph_data[item]:
			if val > max_val: max_val = val
			
	var w = size.x
	var h = size.y
	
	# Draw horizontal grid lines
	for i in range(1, 5):
		var y = h - (h * (i / 4.0))
		draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.1), 1.0)
		
	# Draw the colored polylines for each item
	for item in graph_data:
		var data = graph_data[item]
		var color = item_colors.get(item, Color.WHITE)
		var points = PackedVector2Array()
		
		for i in range(data.size()):
			var x = (float(i) / max(1, data.size() - 1)) * w
			var y = h - ((float(data[i]) / max_val) * h)
			points.append(Vector2(x, y))
			
		if points.size() > 1:
			draw_polyline(points, color, 2.0, true)
