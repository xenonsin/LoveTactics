-- SENTENCE OF THE COURT: the spell the Archon Duke Ascends into (data/characters/character_archon_duke_ascended.lua;
-- "The Crown's Bestiary", slice A, 2026-10-09). The review approved "a new form, healed to full, with new spells" and
-- left the spells to the build: this is the one the Duke did not have before it took three wisps. Magic damage to a
-- foe within 4 and to every body beside it -- the court's judgement falls on a company standing together, which is
-- the second reason (after its own beam) the Duke's fight is fought spread out.
--
-- `creature` and no price: the Ascended body's own art, never a scroll in its pocket.
local Curve = require("models.curve")

return {
    name = "Sentence of the Court",
    description = "Magic damage to a foe within 4 and every body beside it.",
    flavor = "It does not raise its voice. It has never needed to say anything twice.",
    sprite = "assets/items/ability_sentence_of_the_court.png",
    type = "ability",
    class = "creature",
    tags = { "magical" },
    noSteal = true, -- the Ascended body's own art
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        minRange = 2, -- far enough that the square never covers the Duke's own cell
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 12 },
        damage = Curve.ramp(14, 24),
        aoe = { radius = 1, shape = "square" },
        ai = { priority = "high", act = "attack", when = { subject = "any_foe", test = "exists" } },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
