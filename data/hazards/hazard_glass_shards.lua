-- GLASS SHARDS: what Envy's glass leaves on the floor (creature identity pass, 2026-11-19). A Glass-Mote shatters
-- into a tile of it when it falls (trait_shatters_to_shards), and the Unwanted's cracks run out as lines of it at
-- each threshold (trait_fracture_line).
--
-- WHY THE TURN'S END. The mote's whole job was to strip one blessing, and on the floor that fields it from 11 the
-- body that cashes the stripping in (the Second Self) is not there until 12. Shards keep the stripping on the
-- board after the mote is gone, and they ask where you STOP: crossing a shard tile costs nothing, ending a turn on
-- one cuts you and takes a blessing. Read at the turn's end for the Lethe Shallows' reason
-- (data/hazards/hazard_lethe_shallows.lua): a tile that bit on the step in would be a toll on walking, and this is
-- a toll on standing.
--
-- THE CUT IS THE HALF EVERY COMPANY FEELS. A company with no blessings to lose still loses the ground: the glass
-- cuts whoever stops on it, so the motes and the Unwanted read "where are you standing" as well as "what are you
-- wearing" (the same-envy-support row: half of Envy now reads something every company does).
--
-- Sided to whoever shattered (Trait ctx.placeHazard stamps it), so the glass does not cut its own line.
return {
    name = "Glass Shards",
    description = "A foe that ends a turn here takes 3 damage and loses a blessing. Damage ignores armor.",
    tags = { "glass" },
    duration = 36, -- about six turns: a fight's worth of the middle of it, not the whole of it
    disposition = "hostile", -- the company's planner and the enemy's both read it as ground to stop off
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if ctx.isAlly(u) then return end
        local Combat = require("models.combat")
        -- Through the gaps in the armour: a cut a coat turned to 1 would be no reason to step off the tile. Routed
        -- past ctx.damage only for the `raw` flag, so the one rule that closure keeps for every zone -- a spirit
        -- whose summoner wears the Ancestor Mask takes nothing from ground -- is asked here as well.
        if not (u.summoner and require("models.trait").flag(u.summoner, "summonsShrugHazards")) then
            Combat.dealFlatDamage(ctx.combat, u, 3, { "physical", "slash" }, ctx.hazard.name, nil, { raw = true })
        end
        if u.alive then Combat.dispelUnit(ctx.combat, u, 1) end
    end,
}
