class_name ItemInstanceStub
extends Node


static func dummy_proto(item_type: ItemBase.ItemType) -> ItemBase:
  var p := ItemBase.new()
  p.id = "proto_%s" % item_type
  p.item_type = item_type
  p.display_name = "Dummy %s" % item_type
  p.icon = preload("res://icon.svg")  # 何でも良い
  return p


## prototype.id を明示したいテスト（同種判定など）向け
static func dummy_proto_with_id(proto_id: StringName, item_type: ItemBase.ItemType) -> ItemBase:
  var p := dummy_proto(item_type)
  p.id = proto_id
  return p


static func dummy_item(uid: String, item_type: ItemBase.ItemType) -> ItemInstance:
  var inst := ItemInstance.new(dummy_proto(item_type))
  inst.uid = uid
  return inst


static func dummy_item_with_proto(
  uid: String, proto_id: StringName, item_type: ItemBase.ItemType
) -> ItemInstance:
  var inst := ItemInstance.new(dummy_proto_with_id(proto_id, item_type))
  inst.uid = uid
  return inst
