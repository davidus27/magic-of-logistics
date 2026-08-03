class_name InkPalette
extends RefCounted
## The complete colour set of the game. Specification section 10.1.
##
## The game uses black, white and grey only. Do not add a colour here without a
## matching change to the specification.

## Off-white paper background. Also the project clear colour.
const PAPER := Color("f3efe4")
## Primary ink. Every important world line uses this.
const INK := Color("1a1a1a")
## Light line colour. Road edges and other secondary lines.
const LINE_LIGHT := Color("b7b2a8")
## Medium grey. Fills, mud, and dead paper marks.
const GRAY_MEDIUM := Color("77736c")
