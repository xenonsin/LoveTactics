-- SHATTERS TO SHARDS: a Glass-Mote's death, carried on its Glass Shard (data/items/weapon/weapon_glass_shard.lua).
-- Creature identity pass, 2026-11-19.
--
-- The mote falls and the tile it stood on becomes Glass Shards (data/hazards/hazard_glass_shards.lua): whoever of
-- the company ends a turn there is cut and loses a blessing. So killing a mote is no longer the end of it -- WHERE
-- you kill it decides where the company cannot stop for the next few turns, and a mote that dies in the doorway
-- has closed the doorway.
--
-- A death hook rather than the weapon's own effect, because the weapon only runs when the mote swings, and the
-- ground has to land however the mote goes down -- a blade, a burn, a bomb.
return {
    name = "Shatters to Shards",
    description = "When it falls, leaves Glass Shards on its tile.",
    notAReaction = true, -- a body coming apart is what it is, not an answer it chooses; a stun does not stop it
    -- A death that leaves ground, weighed beside the Curse-Bearer's (0.5). On the def rather than in
    -- Grade.TRAIT_GRADE for trait_ashen_echo's reason.
    grade = 0.5,
    onDeath = function(ctx)
        local u = ctx.unit
        if not (u and u.x and ctx.combat) then return end
        ctx.placeHazard(u.x, u.y, "hazard_glass_shards")
        ctx.log("status", string.format("%s shatters across the floor.", (u.char and u.char.name) or "The glass"), u)
    end,
}
