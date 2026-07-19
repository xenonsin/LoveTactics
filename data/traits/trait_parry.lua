-- Parry: the sword's answer, and the sword archetype's defining trait (docs/weapons.md). A swordsman
-- struck by a foe their blade can reach turns the blow aside and cuts back with that same blade,
-- costing stamina but none of the timeline.
--
-- Priced like every answer in the game (see Trait.answerCost in models/trait.lua): an answer is a
-- swing, so it costs exactly what swinging costs -- the answering weapon's own ability cost, doubled
-- for each answer already thrown since the bearer last acted. Nothing is declared here, because
-- nothing needs to be: an iron sword parries for 8 and a greatsword for 16 because that is what those
-- weapons charge to swing, which is also why the greatsword archetype cannot afford to parry at all
-- (docs/weapons.md).
--
-- No cooldown. What gates a parry is REACH and nothing else: strike a swordsman from an adjacent tile
-- and they answer, shoot them from four tiles off and they cannot. The player can see that on the
-- board before committing, which is the whole reason the timer went away -- "why didn't I get
-- countered?" must have an answer you can point at.
--
-- The `counter` rule declares no `reach`, so the default applies: the bearer answers anything a weapon
-- in their grid can reach back at. On a swordsman that is the tile beside them. On a swordsman also
-- carrying a bow it is the bow's band too -- deliberately, since the question this system asks is
-- "can you reach back", not "which slot sorted first".
return {
    name = "Parry",
    description = "When struck by a foe your weapon can reach, spend a swing's stamina to turn the blow and cut back.",
    -- A parry answers an ATTACK, never another answer (no answersReactions): "did they swing at me, or
    -- were they only answering me?" Without that every sword exchange becomes a three-hit volley --
    -- strike, counter, counter-back -- since both the knight and the common bandit carry an iron sword.
    -- One counter per attack; the trade stays legible.
    counter = {},
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        -- The one gate that spends anything, so it comes after every free refusal above: an exhausted
        -- swordsman simply eats the blow, and a parry that declines is never billed for it.
        if not ctx.pay() then return end
        ctx.log("action", string.format("%s parries!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(ctx.attacker)
    end,
}
