-- THE SOUNDER: boar, plural. A sounder is what a group of them is actually called.
--
-- encounter_boar.lua fields one animal and reads as texture; three of them read as a decision about
-- where to stand. Nothing new is needed for it -- the body has always been there and has never been
-- brought in numbers.
--
-- Deliberately NOT built around character_pig, which is a shape a hunter wears rather than a body that
-- fights (one health, tier 0). See character_wyrmling.lua on why a worn shape and a combatant have to
-- be separate blueprints.
return {
    name = "The Sounder",
    kind = "combat",
    weight = 4,
    minDay = 1,
    composition = function(ctx)
        local list = {}
        for _ = 1, 3 + math.floor((ctx.day or 1) / 13) do
            list[#list + 1] = "character_boar"
        end
        return list
    end,
}
