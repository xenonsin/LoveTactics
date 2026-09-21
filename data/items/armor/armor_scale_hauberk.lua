-- Scale Hauberk: naga scale, cut in plates and sewn onto a backing. Somebody in the city will do this
-- work if you bring them enough of it and do not ask what it was.
--
-- IT ADMITS THE FACTION'S OWN FLAW, which is the whole of why it is worth wearing and worth thinking
-- about. Water runs off it and ice slides off it, and it takes lightning the way the thing it was cut
-- from did. That is the honest reading of the Mere: they own the water, and the water is what kills
-- them -- so a company that puts on their armour inherits both halves of the bargain.
--
-- NO NAGA EVER WEARS ONE, and that is a deliberate arrangement rather than an oversight. The race
-- already carries `lightning = -4` (data/races/naga.lua); a naga in naga plate would sit at -8 and
-- fold to a single bolt, with no file saying why. A body's `drops` list is read separately from its
-- grid (docs/drops.md), so the coat falls off a Fen Lancer that never had one on -- which is the
-- cheapest possible way to keep a fact from being stated twice on the same body.
--
-- The one place the two CAN still meet is a naga in the player's own roster, wearing this. That is left
-- alone on purpose: it is a loadout the player built badly, which is the precedent this codebase
-- already sets for two conflicting movement items in one grid. The alternative is a guard that reads a
-- body's race from inside an armour blueprint, which is one item claiming to know about another sheet.
--
-- IT COSTS A SQUARE OF PACE, like every armour in the game with no exceptions for being clever
-- (tests/armor_spec.lua).
local Curve = require("models.curve")

return {
    name = "Scale Hauberk",
    description = "Turns water and ice. Takes lightning badly.",
    flavor = "The plates still lie the way they grew. It is a little like being held.",
    sprite = "assets/items/scale_hauberk.png",
    type = "armor",
    tags = { "light" },
    class = "knight",
    dropOnly = true,
    -- HAND-PLACED, and `. drop-tier` says 1. A coat whose resist table carries a large NEGATIVE
    -- grades near nothing -- correctly, as a sum -- but what it is worth to a player is the two
    -- positive lines plus a decision about lightning, and a decision does not grade at all.
    unlockLevel = 7,
    bonus = { defense = 2, movement = -1 },
    resist = { water = 3, ice = 2, lightning = -4 },
    upgrade = { defense = Curve.ramp(2, 12) },
}
