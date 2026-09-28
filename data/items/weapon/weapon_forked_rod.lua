-- FORKED ROD: the Arc's Forking in a caster's hand (models/storm.lua; "Fire, Lightning, and Dirty Thunder",
-- 2026-09-27), and one of the three things it drops. A wand, so it owes the family's contract (docs/weapons.md):
-- ranged, magical, no dead zone.
--
-- The bolt forks ONCE, to the nearest other body within 2 of the one it struck, for half -- friend or foe. So it
-- asks where your own side is standing, which no other wand does. Not the Conductor (which needs Wet) and not the
-- Twinned Sigil (which forks only into a foe beside the target): this goes through whoever is closest.
local Curve = require("models.curve")

return {
    name = "Forked Rod",
    description = "A bolt that forks once to the nearest other body within 2, friend or foe, for half.",
    flavor = "Aim it at the one you want. Stand well back from the one you do not.",
    sprite = "assets/items/weapon_forked_rod.png",
    type = "weapon",
    tags = { "wand", "magical", "lightning", "ranged" },
    class = "mage",
    unlockLevel = 7,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line, as every wand's does
        speed = 3,
        cost = { stat = "mana", amount = 6 },
        damage = Curve.ramp(10, 20), -- the slot-7 wand target: the fork is on top of it
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t)
            require("models.storm").fork(fx, t, 1)
        end,
    },
}
