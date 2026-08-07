-- Sealed Hand: one FRIENDLY working, aimed squarely at this body, simply does not happen. The mirror of
-- data/status/status_sealed_ward.lua, and everything true of that one is true of this one with the sides
-- swapped -- so the notes there on why a categorical refusal is fair apply here unchanged:
--
--   * SINGLE TARGET ONLY. A heal that catches this body inside an area goes straight past it. A blast
--     does not aim at anybody, so there is nothing to refuse, and every healer who owns an aoe already
--     holds the answer without needing to know this exists.
--   * ONE CHARGE, spent through Status.consumeBarrier exactly as a barrier's is. The second heal lands.
--   * THE CASTER STILL PAID. The enemy priest spends cost, cooldown and the turn -- which is the entire
--     purchase. You are not reducing a heal, you are buying an enemy's whole action for one of yours.
--
-- WHY IT IS NOT THE UNCLOSING WOUND. Status.blocksHealing (the Unclosing Wound) forbids HEALING, all of
-- it, for as long as it holds -- a strictly stronger thing to do to a heal, and a different purchase.
-- This refuses a WORKING: the cure that would have lifted your Poison off them, the buff that would have
-- made them hit harder, the revive that would have put their champion back on its feet. It stops one of
-- those, whichever comes first, and then it is gone. A wound that cannot close is attrition; this is
-- tempo, and it is aimed at the enemy's support rather than at their hit points.
--
-- The gap it was written for: nothing in the catalog touched enemy SUPPORT. Every answer to an enemy
-- healer was to kill the healer or out-damage the healing, and against a body the party cannot reach in
-- one turn neither is a plan. This makes the healer's turn the thing you attack.
--
-- Shorter than the Sealed Ward's forty ticks, deliberately. That one is held up by a relic that is
-- wearing a slot for it and has to survive until the enemy's one dangerous spell arrives; this is thrown
-- by a wand, on a read about the enemy's NEXT turn, and a long one would stop being a read at all.
return {
    name = "Sealed Hand",
    abbr = "SHnd",
    description = "Sealed: the next single-target friendly working aimed at it is refused outright.",
    color = { 0.729, 0.612, 0.435 }, -- badge tint (tarnished gold: the Sealed Ward's colour, gone dull)
    duration = 18,                -- ~3-4 turns: long enough to cover the turn you read, not the fight
    magnitude = 1,                -- workings it refuses before it is spent
    debuff = true,                -- it is done TO a body, so Cure lifts it
    negates = "aid",
}
