-- CAN'T BE BOTHERED: Sloth's Ogre's rule and its whole turn (data/characters/character_sloth_ogre.lua). Approved
-- 2026-10-04 ("Sloth's Bestiary", slice B).
--
-- An ogre never walks. Aimed at the body beside it -- either side, the nearest -- it lifts it and throws it up to 4
-- tiles at the company's body farthest from it: both take the impact, and the thrown body lands beside its target.
-- Aimed anywhere else, it tears up a slab of ice and throws that at whoever stands there, for half. The planner
-- that picks the aim is models/sloth_trolls.lua's (Trolls.ogrePlan, asked by AI.preempt); the throw is a forced
-- move with a landing, so a body nothing can move is not lifted.
--
-- A tile cast so it can be aimed at a friend as readily as a foe. A creature's own kit: never loot.
local Curve = require("models.curve")

return {
    name = "Can't Be Bothered",
    description = "Throw a body beside you at the farthest foe within 4. Both take impact. Nobody beside: a slab, for half.",
    flavor = "It has never once walked over to anyone. It has never once needed to.",
    sprite = "assets/items/ability_cant_be_bothered.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4, -- the throw's reach: a body beside it, or the slab's mark
        speed = 6,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(14, 24),
        effect = function(fx)
            require("models.sloth_trolls").ogreThrow(fx.combat, fx.user, fx.tx, fx.ty, fx.amount)
        end,
    },
}
