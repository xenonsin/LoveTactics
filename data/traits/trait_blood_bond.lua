-- BLOOD BOND and TITHE: the Sire's two rules (data/items/utility/utility_blood_bond.lua; Wrath's vampires,
-- 2026-09-26, the alpha).
--
--   BLOOD BOND   while the Sire stands, no vampire on its side can enter Bloodlust: their Thirst stops at 2
--                (models/thirst.lua's Thirst.bonded). When the Sire falls, every vampire it bonded enters
--                Bloodlust at once, whatever its Thirst -- so killing it first turns the whole brood loose on
--                whoever is nearest, its own ghouls included.
--   TITHE        each time one of its brood draws blood, the Sire heals 10% of that drink (Thirst.feed).
return {
    name = "Blood Bond",
    description = "Allied vampires cannot enter Bloodlust; when you fall, they all do. Heal 10% of every drink they take.",
    bloodBond = true,
    tithe = true,
    notAReaction = true,
    onDeath = function(ctx)
        if ctx.unit and ctx.combat then require("models.thirst").bondBreaks(ctx.combat, ctx.unit) end
    end,
}
