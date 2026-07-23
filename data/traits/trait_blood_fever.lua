-- Blood Fever: the bearer gets stronger every time ANYONE dies. Not an ally, not an enemy -- anyone.
-- It is the only reflex in the game keyed to the field rather than to its own bearer (the `onAnyDeath`
-- broadcast, see models/trait.lua), and that indifference is the whole character of it.
--
-- Every other death-adjacent rule in this codebase picks a side. A vengeance trait answers a comrade
-- falling; an executioner's charm answers a kill of its own. This one does not ask whose body it was,
-- which is what separates wrath from grief and from ambition both: what feeds it is that the fight is
-- going badly for someone. Lose your own front rank and the bearer is delighted.
--
-- Two design consequences worth stating, because they are the tuning:
--   * CAPPED, at five bodies. Uncapped it would turn a long grind into an unanswerable one, and the
--     item would read as "win harder once you are already winning". Five is roughly a fight's worth of
--     corpses, so the ceiling is reached about when the outcome is decided anyway -- what the charm
--     actually sells is the middle of a bad battle.
--   * DAMAGE ONLY, never Magic Damage. It is the arm that shakes, not the argument. A mage carrying
--     this gets nothing for it, which is correct: this is wrath's charm, and wrath is a thing done at
--     arm's length with a blade.
--
-- Summons and decoys are deliberately not bodies (models/combat.lua's killUnit gates the broadcast on
-- the same condition the `allyDown` tally uses): a conjuration winking out is not somebody dying, and
-- without that rule the first thing anyone would do is call five wolves and kill them.
--
-- The bonus rides `ctx.addBonus`, which writes the unit's per-battle table -- never the shared
-- character instance -- so it drains away with the battle rather than following the bearer to the hub.
-- `ctx.trait.stacks` counts the bodies already banked, which is what enforces the cap.
return {
    name = "Blood Fever",
    description = "Every body that hits the ground, on either side, permanently raises your Damage this battle.",
    magnitude = 2,  -- Damage per body
    maxStacks = 5,  -- the ceiling; see above
    onAnyDeath = function(ctx)
        local cap = ctx.def.maxStacks or 5
        if ctx.trait.stacks >= cap then return end
        ctx.trait.stacks = ctx.trait.stacks + 1
        local total = ctx.addBonus("damage", ctx.def.magnitude)
        ctx.log("action", string.format("%s's blood is up (+%d Damage).",
            (ctx.unit.char and ctx.unit.char.name) or "Unit", total))
    end,
}
