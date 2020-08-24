.nodes |
    to_entries |
	map_values(.value + { node: .key }) | .[]  |
	select(.type | test("'$type'"; "ig")) |
	{ item: "node=\(.node) type=\(.type) agent=\(.agent)
	db=\(.db)" } | .[]
