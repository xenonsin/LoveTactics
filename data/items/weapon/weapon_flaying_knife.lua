-- THE FLAYING KNIFE: the Skin-Thief's drop (data/characters/character_skin_thief.lua), its flaying worn small.
-- Reviewed 2026-10-01..03 ("Envy's Bestiary", round 2).
--
-- A dagger, so it owes the family's Bleed and its quickness (docs/weapons.md). What it adds is the thief's own
-- reading of Larceny: a cut Halts the body for 1 turn -- it can do nothing -- and for the rest of this turn the
-- bearer holds one of that body's abilities ON LOAN, with one more action to cast it (trait_flaying_knife). You
-- do not take the spell; you wear the hand that casts it, once. The review's text read "Dagger; bleeds"; the
-- corpus names the status ("Inflicts Bleed"), so that is how it is printed.
--
-- On the seat's dagger line (13-23, the Cutpurse Knife's and the Nightjar's slot). An unstocked trophy.
local Curve = require("models.curve")

return {
    name = "Flaying Knife",
    description = "Inflicts Bleed. A hit Halts the target for 1 turn, and you may cast one of its abilities this turn.",
    flavor = "It is not for killing. It is for taking the part of you worth having.",
    sprite = "assets/items/weapon_flaying_knife.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "guile", "melee" },
    class = "thief",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_flaying_knife" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, as every dagger is
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(13, 23),
        effect = function(fx)
            local dealt = fx.damage(fx.target, { inflicts = "status_bleed" }) -- the wound rides the blow
            if (dealt or 0) > 0 and fx.target and fx.target.alive then
                fx.applyStatus(fx.target, "status_halted", { duration = 5 })
            end
        end,
    },
}
