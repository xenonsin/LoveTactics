-- ANTLER TOSS: a stag's answer to being stood next to. It gets its head under whatever reached in and
-- lifts, and the thing it lifted pays for wherever it comes down.
--
-- Read it beside data/traits/trait_shield_shove.lua, which is the same instinct wearing armour, and the
-- differences are the whole of what separates a guard from an animal:
--
--   Shield Shove   two tiles, answers an ANSWER as readily as an attack, and lives in the shield slot.
--   Antler Toss    one tile, answers an attack only, and lives wherever a rack or a charm can hang.
--
-- So it is the cheaper, shorter, less discriminating-in-the-other-direction version: a shield is a
-- thing somebody chose to carry instead of a second weapon, and this is a thing an animal was born
-- wearing. A guard drives you off; a stag only makes room.
--
-- `shoves` is what tells the rest of the machinery that this reflex is NOT a swing (models/trait.lua):
-- there is no weapon in the motion, so it is billed the stamina declared here rather than the antlers'
-- own sweep price, and the hover preview names it without promising damage. It deals nothing by
-- itself -- the wall, the fire, the spike trap and the next body in the rank do the talking, exactly
-- as a mace's shove does.
--
-- ONE TILE, AND THAT IS THE WHOLE TUNING. Two would be the shield's number on a body that shows up
-- three and four at a time (data/encounters/encounter_the_herd.lua), and a company shoved two tiles by
-- each of four animals every time it swings is not a fight, it is a tide. One tile costs the party a
-- step to answer and costs the stag the stamina to ask.
--
-- No cooldown, on the shield's reasoning: the escalating answer price (each answer this round costs
-- double the last -- see Trait.answerCost) is what paces it, so a stag tosses the first foe for 5, the
-- second for 10, and is then an animal with a rack and no wind left.
return {
    name = "Antler Toss",
    description = "Melee attackers are thrown back a tile. A collision hurts them.",
    cost = { stat = "stamina", amount = 5 },
    -- NO `answersReactions`, deliberately, and it is the one line that keeps this under the shield.
    -- A shield does not care whether the arm that reached in was attacking or answering; a rack comes
    -- up at a blow. Without this, two of these facing each other across one exchange would toss back
    -- and forth until somebody ran out of stamina.
    counter = { reach = "melee", requiresTag = "physical", shoves = 1 },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        ctx.knockback(ctx.attacker, ctx.def.counter.shoves)
        ctx.log("action", string.format("%s throws %s clear with its antlers!",
            (ctx.unit.char and ctx.unit.char.name) or "Unit",
            (ctx.attacker.char and ctx.attacker.char.name) or "the attacker"),
            { ctx.unit, ctx.attacker }) -- the doer and the done-to, so hovering the line rings both
    end,
}
