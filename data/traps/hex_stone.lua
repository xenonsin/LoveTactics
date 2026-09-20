-- HEX STONE: a marked stone set into the floor that puts a curse on what the first body to cross it is
-- carrying (models/curse.lua). See models/trap.lua for the hook contract; ctx.curse / ctx.victim are
-- provided.
--
-- THE TRAP IS THE CURSE'S NATURAL VECTOR, and the reason is what a curse is FOR: a hex has to arrive
-- from somewhere the player was not looking, attach to something the player chose to bring, and outlive
-- the fight it landed in. A trap is all three at once -- it is hidden until it is stepped on, it reads
-- the victim's own kit for a target, and what it writes is on the item rather than on the body.
--
-- IT DEALS NO DAMAGE AT ALL, which is deliberate and is the whole of its design. Every other trap in the
-- folder answers "how much"; this one answers "what did that cost me later". A number on top would blur
-- the two, and a player who took nine damage and a hex in the same beat reads the nine.
--
-- AND IT NAMES NO CURSE, so it rolls the rift's shallowest (Combat.curseItem's default). That is the
-- right default for a trap that can be laid on any floor by anyone: a piece of ground has no opinion
-- about how deep it is, and the deep hexes belong to the things that chose them -- a caster's ability, a
-- boss's rule, a find the Touchstone reads.
--
-- PERSISTENT WOULD BE A DIFFERENT ITEM. `consumedOnTrigger` defaults true, so this is one hex and then
-- a spent stone -- a trap that hexed every body that crossed it would strip a whole company's kit off a
-- single tile, which is not a trap, it is a wipe with a save roll.
return {
    name = "Hex Stone",
    description = "Lays a curse on one piece of the first enemy's kit, then goes cold.",
    sprite = "assets/traps/hex_stone.png",
    health = 4,                            -- HP: how much damage a revealed stone soaks before it breaks
    tags = { "trap", "dark" },
    onTrigger = function(ctx)
        -- `ctx.trap.curse` lets the ability or arena that placed this name the hex; nil rolls a shallow
        -- one. Same shape `ctx.trap.amount` has on the damaging traps -- the blueprint states the
        -- default and the placer may sharpen it.
        ctx.curse(ctx.victim, ctx.trap.curse)
    end,
}
