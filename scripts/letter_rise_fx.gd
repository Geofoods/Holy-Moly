extends RichTextEffect

## Per-letter reveal effect. Each letter after `TYPE_SPEED` stagger fades in from
## transparent and rises up into its slot, so the box types one letter at a time
## while each letter fades in and "comes up".

const TYPE_SPEED := 0.018
const FADE_TIME := 0.26
const RISE := 16.0

var bbcode := "fadeup"

## Shared reveal clock, advanced by the dialogue box while typing. Nudge it far
## forward to reveal everything instantly.
var clock := 0.0

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var start := float(char_fx.relative_index) * TYPE_SPEED
	if clock <= start:
		char_fx.color.a = 0.0
		return true
	var p := clampf((clock - start) / FADE_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - p, 3.0)
	char_fx.color.a = eased
	char_fx.offset = Vector2(0.0, RISE * (1.0 - eased))
	return true
