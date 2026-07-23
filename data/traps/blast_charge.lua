-- Blast charge: a sealed powder pot buried under a flagstone with a pressure fuse. The first opposing
-- unit to cross it sets it off, and the blast catches everything in the 3x3 around the tile -- the one
-- trap in the game with an area.
--
-- Which makes it the only trap that hits people who never stepped on anything. That is its whole
-- claim over data/traps/spike_trap.lua, and it is the Crucible's reading of a trap rather than the
-- Lodge's: a hunter's trap answers the animal that walked into it, and an alchemist's answers the
-- three men walking behind him. Set it in a doorway or a corridor and the tile you buried it under
-- matters far less than the shape of the room it is in.
--
-- IT DOES NOT PICK SIDES. The powder is not the placer's friend -- `unitsNear` catches allies standing
-- in the burst exactly as readily as enemies, and the party's own line pursuing a routed foe over its
-- own charge will pay for it in full. Only the TRIGGER is sided (Trap.trigger refuses the owner's own
-- units), which is the honest reading: your own men know where it is buried and step around it, and
-- know nothing at all about where they are standing when somebody else treads on it.
--
-- Per-body damage is well under a spike trap's, since it may land on five bodies at once, and the
-- charge is fragile (health 3) -- a revealed pot is a pot, and one blow spoils the powder.
return {
    name = "Blast Charge",
    description = "Buried powder: the first enemy across it detonates, wounding everything in the surrounding tiles.",
    sprite = "assets/traps/blast_charge.png",
    health = 3,
    tags = { "trap", "fire", "impact" },
    damage = 9, -- pre-mitigation, PER BODY caught; the area is what it is paying for
    onTrigger = function(ctx)
        -- Everything within one tile of the charge, the victim included (it is standing on it) and
        -- friend or foe alike. Trap.preview's stand-in unitsNear hands back the lone victim, so the
        -- tooltip quotes the per-body number rather than a total nobody could predict.
        for _, u in ipairs(ctx.unitsNear(ctx.trap.x, ctx.trap.y, 1)) do
            ctx.damage(u, ctx.trap.amount or ctx.trap.def.damage, ctx.trap.tags)
        end
    end,
}
