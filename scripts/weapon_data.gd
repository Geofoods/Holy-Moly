extends Resource
class_name WeaponData

enum Type { MELEE, RANGED, ABILITY }

var id := ""
var display_name := ""
var description := ""
var price := 0
var weapon_type := Type.MELEE

var min_damage := 5.0
var max_damage := 10.0

var swing_arc := 2.4
var swing_duration := 0.3

var cooldown := 0.45
var projectile_speed := 1500.0

var icon_color := Color.WHITE