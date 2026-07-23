-- Snare stake: a hooked iron peg driven into a seam of the floor, with a loop of wire round it. It
-- deals nothing at all. The first opposing unit across it is Rooted, and that is the entire trap.
--
-- The pure-hold trap. The Lodge already sells a snare (data/traps/snare_trap.lua) and a bear trap that
-- does both halves, and this is neither -- it is the ROOT sold with no damage and no cost of its own,
-- and what it buys instead of a wound is a much longer hold and a much cheaper cast. A trapper who
-- wants a body kept in one place for the fireball that is already on its way does not want it bloodied
-- first: a wounded target might well be finished by somebody else, and then the ground was wasted.
--
-- HIDDEN, like every authored trap, and that is what separates it from the Grasping Hollow the knight
-- lays -- the hollow is a visible piece of terrain the enemy AI paths around, and this is a thing the
-- enemy AI does not know is there until it is standing in it. Same effect, opposite counterplay: one
-- is denied ground, and one is a lie about safe ground.
--
-- Tougher than a spike trap (health 5) because there is nothing to disarm here except the peg itself,
-- and a revealed one genuinely has to be pulled out of the floor.
return {
    name = "Snare Stake",
    description = "A wire loop round an iron peg: roots the first enemy across it, and draws no blood.",
    sprite = "assets/traps/snare_stake.png",
    health = 5,
    tags = { "trap", "physical" },
    damage = 0, -- deliberately: what this trap sells is the tile, not the wound
    onTrigger = function(ctx)
        -- The trap's own `amount` (scaled by the placing item's upgrade level) rides in as the root's
        -- DURATION rather than as damage, which is the only axis a hold has to grow along -- exactly
        -- the reasoning a barrier's upgrade buys coverage rather than a bigger number.
        ctx.applyStatus(ctx.victim, "status_root", { duration = ctx.trap.amount })
    end,
}
