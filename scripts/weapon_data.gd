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

## Set on a weapon that should look polished rather than merely tinted - it gets
## the shine shader over its sprite, so the gold shovel catches the light instead
## of just being a gold-coloured shovel.
var polished := false