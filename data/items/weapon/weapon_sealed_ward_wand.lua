-- A wand, so it strikes at range and needs only a direction (docs/weapons.md). Its extra is that the shot
-- WARDS THE ONE WHO FIRED IT: the bolt lands, and the mage is left holding a Sealed Ward
-- (data/status/status_sealed_ward.lua) -- the next single-target spell aimed at them is refused outright.
--
-- Quest-only: `class` with no `price`.
--
-- ONE OF THREE, and they are meant to be read together. This wand, data/items/weapon/
-- weapon_reflecting_wand.lua and data/items/weapon/weapon_second_utterance_wand.lua are the Arcanum's
-- quest wands, and all three do the same structural thing: a bolt at a foe that pays its own caster.
-- That shape is deliberate and it is the family's answer to a real problem -- every protective working in
-- this game costs a whole turn, and a mage who spends the turn is a mage who did not cast. These buy the
-- ward as a RIDER, and the price is that you have to be attacking to get one.
--
-- It used to be aimed at an ALLY and dealt nothing to anybody, which docs/weapons.md carried a ⚠️ against.
-- A weapon pointed at your own side is not a weapon and cannot be graded either -- "what should this deal
-- at its slot" has no honest answer when the answer would wound the friend it is aimed at
-- (Balance.gradesOnMagnitude). The protective cast belongs on the ability shelf, where it already lives.
--
-- WHY IT DOES NOT UNDERCUT WHAT ALREADY GRANTS THIS. armor_sealed_coat and utility_sealed_reliquary both
-- hold up a Sealed Ward, and the status's own header explains that its forty ticks are long "on purpose:
-- it is granted by a relic that is holding it up". Nothing is holding this one up. The wand's ward runs
-- TEN ticks -- about two turns, which covers the reply to the shot you just took and nothing else. That is
-- the whole difference between a relic that wears a slot to keep a ward standing all fight and a shot that
-- happens to leave you covered while the enemy answers it.
--
-- The read it is for: fire it at the enemy caster. You have spent no turn on defence, they are hurt, and
-- the working they were going to throw back at you does not happen. Against a line of melee it wards
-- nothing at all -- a Sealed Ward answers single-target SPELLS and a sword goes straight through it -- so
-- knowing whether their kit even contains the thing this stops is the mage's problem, and it is a read
-- rather than a stat.
local Curve = require("models.curve")

return {
    name = "Wand of the Sealed Ward",
    description = "The bolt leaves its caster holding a Sealed Ward.",
    flavor = "The Arcanum is very clear that it is not a shield. A shield would have to be hit.",
    sprite = "assets/items/sealed_ward_wand.png",
    type = "weapon",
    tags = { "wand", "magical", "arcane", "ranged" },
    class = "mage",
    dropTier = 7,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 10 }, -- dearer than a plain wand's: the ward is not free
        -- Its slot's number, which at slot 0 is the plain wand's exactly (Balance.slotTarget): same
        -- family, same slot, same magnitude, and the ward is the whole of what tells them apart.
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            fx.damage(fx.target)
            -- On the CASTER, and short. Ten ticks against the status's own default of forty -- see the
            -- header: forty is a relic's number, and no relic is holding this one up.
            fx.applyStatus(fx.user, "status_sealed_ward", { duration = 10 })
        end,
    },
}
