-- Veil of Night: puts out the light over a 3x3 patch of ground (data/hazards/hazard_darkness.lua).
-- Nothing standing in it is harmed. Nothing can see a line ACROSS it.
--
-- The Arcanum's answer to a bow. Every ranged thing in the game -- a shot, a bolt, an overwatch stance,
-- the enemy AI's own reckoning of what it can hit -- gates on Combat.hasLineOfSight, and this is the
-- first cast that can put a wall in front of that gate without putting a wall in front of anybody's
-- feet. Drop it between your line and their archers and the archers have nothing to do; drop it on
-- your own retreat and the shots that were going to follow you do not.
--
-- Unsided, like the Emberwand's fire and for the same stated reason: it is a wall you have to be
-- willing to stand behind. Your own bows go just as blind, so a party built on arrows should think
-- twice about buying this and a party built on steel should buy it immediately. That asymmetry is the
-- item choosing which army it belongs to, which is more interesting than a number would be.
--
-- Bodies pass through untouched -- there is no damage, no status and no cost to walking in. A foe that
-- closes is a foe the veil has stopped helping against, and closing is therefore the counter: visible
-- on the board, payable in movement, and decided before anyone commits.
--
-- Compare Summon Wall (data/items/ability/ability_summon_wall.lua), which stops feet and arrows both
-- and can be broken down. This stops only the arrows and cannot be broken at all -- a hazard is not
-- destructible (models/hazard.lua). Two ways to cut a board in half, and the choice between them is
-- whether you want the enemy to be unable to reach you or unable to shoot you.
return {
    name = "Veil of Night",
    description = "Blots out a 3x3 of ground. Nothing can see a line across it; walking through is free.",
    flavor = "It is not a shadow. A shadow is what light leaves behind, and there is nothing behind this.",
    sprite = "assets/items/ability_silence.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "magical", "dark" },
    class = "mage",
    price = 380,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- the dark falls on people as readily as on empty ground
        range = 5,
        speed = 5,
        requiresSight = true, -- you have to be able to see the place you are about to unsee
        support = true,       -- it lands no damage
        aoe = { shape = "square", radius = 1 }, -- the 3x3 the veil covers
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            -- Painted over the footprint, one hazard per cell, exactly as Fireball leaves its fire.
            -- Duration scales with the forge; the RADIUS does not -- an upgrade buys a longer night,
            -- never a wider one (the same principle Combat.layIncense holds to).
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_darkness", { duration = 15 + 2 * fx.level })
            end
        end,
    },
}
