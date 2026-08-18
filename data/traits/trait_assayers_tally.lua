-- THE TALLY: what your company is carrying, and what you have taken off somebody else's body since the
-- bell.
--
--   baseline   the purse itself arms you -- a point of damage per `perCoin` gold the company holds,
--              capped. Greed read from the inside: what you have is what you swing with. It pays from
--              the first fight of a fresh save with nothing else equipped, and it is a `live` read, so
--              spending the money puts the damage back down again.
--   synergy    the Bottomless Purse lifts an item off an adjacent foe into your grid (its
--              activeAbility), and every piece that arrives that way is a permanent notch on top. The
--              Purse costs you an action and pays an item you may not even want; the tally makes the
--              theft itself worth doing, which is the sin.
--
-- TWO HALVES ON TWO SEAMS, and they have to be. The purse term is `live` because the bank moves between
-- turns without anything firing (models/traits/trait_assayed.lua reads it the same way); the theft term
-- is counted against a snapshot taken at the bell, because there is no onSteal event and comparing the
-- grid catches anything else that fills it too.
return {
    name = "The Tally",
    description = "Heavier for the coin your company holds, and for everything you have taken this fight.",
    perCoin = 250,  -- gold per point of damage
    ceiling = 10,   -- ...and the cap, so a rich save does not walk in unkillable
    perTaken = 3,   -- a point per item in your grid you did not start the fight with
    live = function(ctx)
        local purse = ctx.combat and ctx.combat.purse
        local gold = purse and purse.get and purse.get()
        if not gold or gold <= 0 then return nil end
        local n = math.min(ctx.def.ceiling, math.floor(gold / ctx.def.perCoin))
        if n <= 0 then return nil end
        return { damage = n }
    end,
    onCombatStart = function(ctx)
        local held = 0
        for _, item in pairs((ctx.unit.char and ctx.unit.char.inventory) or {}) do
            if type(item) == "table" then held = held + 1 end
        end
        ctx.trait.opened = held
    end,
    onCast = function(ctx)
        local held = 0
        for _, item in pairs((ctx.unit.char and ctx.unit.char.inventory) or {}) do
            if type(item) == "table" then held = held + 1 end
        end
        local want = math.max(0, held - (ctx.trait.opened or held)) * ctx.def.perTaken
        local have = ctx.trait.applied or 0
        if want == have then return end
        ctx.addBonus("damage", want - have)
        ctx.trait.applied = want
    end,
}
