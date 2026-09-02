class_name StatusInstance
extends RefCounted

var data: StatusData
var remaining: float = 0.0
var stacks: int = 1
var source: Pawn
var applied_tick: int = 0
var accum_dot: float = 0.0    # accumulated DoT for batched application
var accum_hot: float = 0.0
