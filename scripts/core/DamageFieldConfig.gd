# DamageFieldConfig.gd - 爆発の後に残るダメージフィールドの設定
# ExplosionConfig.damage_field に設定すると、爆発した位置にフィールドが生成される（DamageField）
class_name DamageFieldConfig extends Resource

@export_group("Damage")
@export var radius: float = 50.0  # フィールドの半径（px）
@export var duration: float = 2.0  # 持続時間（秒）
@export var damage: int = 1  # 1回のダメージ
@export var tick_sec: float = 1.0 / 15.0  # ダメージを与える間隔（秒）

@export_group("Visual")
@export var area_color: Color = Color(1.0, 0.15, 0.1, 0.25)  # 範囲を示す円の色（半透明）
@export var particle_color: Color = Color(1.0, 0.2, 0.15, 1.0)  # パーティクルが出たときの色
@export var particle_end_color: Color = Color(1.0, 1.0, 1.0, 1.0)  # 寿命に沿って変わっていく先の色
@export var particle_amount: int = 32  # 同時に出ているパーティクルの数の目安
@export var particle_lifetime: float = 0.6  # パーティクル1粒の寿命（秒）
@export var particle_scale_min: float = 3.0  # パーティクル（既定の四角）の大きさ
@export var particle_scale_max: float = 6.0
