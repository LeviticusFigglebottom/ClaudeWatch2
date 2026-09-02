class_name NetChannel
extends Node
## The single RPC endpoint per branch. Node path relative to the branch root must match on
## server and client ("Net"), so RPCs resolve across the separate MultiplayerAPI instances.

signal input_received(peer: int, bytes: PackedByteArray)
signal client_msg_received(peer: int, bytes: PackedByteArray)
signal snapshot_received(bytes: PackedByteArray)
signal event_received(bytes: PackedByteArray)
signal server_msg_received(bytes: PackedByteArray)

var bytes_in: int = 0
var bytes_out: int = 0


func _ready() -> void:
	name = "Net"


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func c_input(bytes: PackedByteArray) -> void:
	bytes_in += bytes.size()
	input_received.emit(multiplayer.get_remote_sender_id(), bytes)


@rpc("any_peer", "call_remote", "reliable", 2)
func c_msg(bytes: PackedByteArray) -> void:
	bytes_in += bytes.size()
	client_msg_received.emit(multiplayer.get_remote_sender_id(), bytes)


@rpc("authority", "call_remote", "unreliable", 1)
func s_snapshot(bytes: PackedByteArray) -> void:
	bytes_in += bytes.size()
	snapshot_received.emit(bytes)


@rpc("authority", "call_remote", "reliable", 2)
func s_event(bytes: PackedByteArray) -> void:
	bytes_in += bytes.size()
	event_received.emit(bytes)


@rpc("authority", "call_remote", "reliable", 2)
func s_msg(bytes: PackedByteArray) -> void:
	bytes_in += bytes.size()
	server_msg_received.emit(bytes)


# --- send helpers (count bytes) ---
func send_input(bytes: PackedByteArray) -> void:
	bytes_out += bytes.size()
	c_input.rpc_id(1, bytes)


func send_client_msg(bytes: PackedByteArray) -> void:
	bytes_out += bytes.size()
	c_msg.rpc_id(1, bytes)


func send_snapshot(peer: int, bytes: PackedByteArray) -> void:
	bytes_out += bytes.size()
	s_snapshot.rpc_id(peer, bytes)


func send_event(peer: int, bytes: PackedByteArray) -> void:
	bytes_out += bytes.size()
	s_event.rpc_id(peer, bytes)


func send_server_msg(peer: int, bytes: PackedByteArray) -> void:
	bytes_out += bytes.size()
	s_msg.rpc_id(peer, bytes)
