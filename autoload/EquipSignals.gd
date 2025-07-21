extends Node

# 装備 UI 内部で使うグローバル・シグナル
signal drag_started(data)  # data := { inst: ItemInstance, src: Node }
signal drag_ended
signal page_changed(page: int)  # Inventory のページ切替
signal swap_request(src: Node, dst: Node)  # src, dst は ItemSlotPanel または EquipSlotPanel
signal return_item_to_inventory(pane: Node)  # 装備スロットからインベントリへ戻す
signal request_show_item(item: ItemInstance)  # アイテム情報を表示
signal swap_to_each_grid(src: Node, grid: Node)  # 別のインベントリへのアイテム移動要求
