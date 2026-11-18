extends Node
## Central signal hub. Gameplay nodes never reach into the UI; they emit here.

signal money_changed(amount: int, delta: int)
signal hotbar_changed
signal slot_selected(index: int)
signal toast(text: String)
signal prompt_changed(text: String)
signal plant_changed(pot)
signal order_board_changed
signal trust_changed(customer_id: String, trust: int)
signal sale_completed(customer_id: String, total: int)
signal ui_blocked(blocked: bool)
signal shop_requested
signal sell_requested(customer_id: String)
signal board_requested
signal pack_requested
signal pause_requested


func notify(text: String) -> void:
	toast.emit(text)
