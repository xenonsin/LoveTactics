-- Empty Vessel: the standing rule of the Spellbreaker's charm. The bearer's blows land far harder
-- against an enemy with no mana left.
--
-- The payoff Mana Sunder has been missing since it shipped. Draining a caster dry accomplished nothing
-- on its own -- a mage at zero mana is inconvenienced, and the spellbreaker had spent a turn to
-- inconvenience it. This turns the empty bar into an execute condition, and makes two items that were
-- already on the shelf into a combination.
--
-- Runs through damageBonusVs, which is a PURE query fired on every damage preview -- so the number the
-- hover promises is the number the blow lands, and nothing here may mutate.
--
-- Reads "has a mana pool at all, and it is empty". A body that never had mana -- a wolf, a construct, a
-- fighter -- is not an empty vessel, it is a different kind of thing, and rewarding a spellbreaker for
-- hitting the party's dog would make the charm a flat damage bonus wearing a condition.
return {
    name = "Empty Vessel",
    description = "Increase damage by 8 against a foe whose mana is 0.",
    magnitude = 8, -- flat damage against a caster whose pool is spent
    damageBonusVs = function(ctx)
        local t = ctx.target
        local pool = t and t.char and t.char.stats and t.char.stats.mana
        if not pool or (pool.max or 0) <= 0 then return 0 end
        if (pool.current or 0) > 0 then return 0 end
        return ctx.def.magnitude or 8
    end,
}
