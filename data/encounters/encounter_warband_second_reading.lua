-- THE SECOND READING: the anti-caster company.
--
-- Mana Sunder burns the pool, Arcane Cleave lands into a party that can no longer answer, and Garan's
-- folded word punishes casting at all. Genuinely miserable for a mage-heavy company -- which is the
-- point. It is the fight that makes a roster's composition a decision the player made rather than a
-- shape they drifted into, and the only warband in the set that a party can be built WRONG for.
--
-- The two knights are not filler. A caster company with no front rank is answered by walking at it, and
-- this one has to survive contact long enough for the burn to matter.
return {
    name = "The Second Reading",
    kind = "elite",
    weight = 2,
    minDay = 10,
    composition = function(ctx)
        local list = {
            "character_spellbreaker", -- setup: Mana Sunder, and the whole company is priced on it
            "character_battlemage",   -- payoff: Arcane Cleave into a party that cannot reply
            "character_battlemage",        -- multiplier: casting itself becomes expensive
            "character_knight",
            "character_knight",
        }
        for _ = 1, math.floor((ctx.day or 1) / 20) do list[#list + 1] = "character_knight" end
        return list
    end,
}
