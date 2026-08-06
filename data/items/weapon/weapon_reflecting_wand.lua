-- A wand, so it strikes at range and needs only a direction (docs/weapons.md). Its extra is that the shot
-- MIRRORS THE ONE WHO FIRED IT: the bolt lands, and the mage is left Mirrored
-- (data/status/status_reflect_magic.lua) -- the next single-target spell aimed at them rebounds onto the
-- caster who threw it.
--
-- Quest-only: `class` with no `price`.
--
-- THE GREEDY TWIN of data/items/weapon/weapon_sealed_ward_wand.lua, and the pairing is the oldest thing
-- about both of them -- it survived every rewrite because it is the good idea in the pair. A Sealed Ward
-- REFUSES the spell: the working fails and the enemy has spent a turn. This one RETURNS it, so the enemy
-- has spent a turn AND taken their own best cast in the face. Refusal is the safe read; reflection is the
-- greedy one. Against a caster whose big spell would kill you outright, seal. Against one whose spell is
-- merely painful, mirror, and win the fight with their own working.
--
-- The third of the trio is data/items/weapon/weapon_second_utterance_wand.lua; the note at the top of the
-- Sealed Ward wand explains why all three pay their own caster and what that shape is for.
--
-- It used to be aimed at an ALLY and dealt nothing, which docs/weapons.md carried a ⚠️ against -- a weapon
-- pointed at your own side is not a weapon, and its damage cannot be graded when the honest number would
-- wound the friend it is aimed at (Balance.gradesOnMagnitude).
--
-- WHY IT DOES NOT UNDERCUT data/items/ability/ability_reflect_magic.lua. That one is a whole turn -- speed
-- 8, twenty-two mana, no damage -- and it can be pointed at ANYBODY, which is what you are paying for:
-- the ability protects the body that is actually about to be targeted, which is usually not the mage. This
-- wand only ever mirrors ITSELF, it has to be attacking to do it, and the mirror runs ten ticks against
-- the status's own fifteen. It is the mage covering its own reply while doing its job, not a protective
-- cast, and a party that needs the knight mirrored still has to buy the ability.
--
-- It also pairs across shelves with armor_reflecting_shield, which does the same thing for physical blows
-- off the knight's Defend. One word -- mirrored -- split between the two schools and the two shelves.
--
-- Single-target only, like every reflection here: a blast passes straight through, which keeps it a read
-- on the enemy caster's kit rather than a blanket answer to magic.
local Curve = require("models.curve")

return {
    name = "The Reflecting Wand",
    description = "The bolt leaves its caster Mirrored.",
    flavor = "It does not argue with the spell. It agrees with it, and then asks where it was going.",
    sprite = "assets/items/reflecting_wand.png",
    type = "weapon",
    tags = { "wand", "magical", "arcane", "ranged" },
    class = "mage",
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 11 }, -- dearer than the Sealed Ward wand: greed costs more
        -- Its slot's number, which at slot 0 is the plain wand's exactly (Balance.slotTarget): same
        -- family, same slot, same magnitude, and the mirror is the whole of what tells them apart.
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            fx.damage(fx.target)
            -- On the CASTER, and shorter than the status's own fifteen: this covers the answer to the shot,
            -- not the fight. The ability is what you buy to have it standing.
            fx.applyStatus(fx.user, "status_reflect_magic", { duration = 10 })
        end,
    },
}
