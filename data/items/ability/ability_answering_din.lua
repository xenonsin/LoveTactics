-- The Answering Din: a shock that runs out through the ground, and grows louder for every body it has
-- to travel through. One target and it is a poor spell; five and it is the largest number on the board.
--
-- SCALES ON CROWDING, which is a thing this game rewards nowhere else on the magic shelf. `frenzy` does
-- it for a swing (see castAmount in models/combat.lua) and belongs to the fighter -- being surrounded
-- stops being the danger and becomes the point. This is the mage's version of that inversion, and it
-- arrives from the opposite direction: the fighter is rewarded for being IN the crowd, and the mage for
-- putting the crowd somewhere and then being nowhere near it.
--
-- Which makes it the natural second half of the Indrawn Breath, and the pairing is deliberate. Breathe
-- in on turn one to make the heap; ring the din on turn two to charge every body in it for being part
-- of a heap. Two mage slots and two turns for a payoff nothing else in the catalog can reach -- and
-- completely dead against a disciplined line that never clumps.
--
-- Written as an explicit count rather than as `frenzy`, because frenzy raises the number EVERY body
-- takes and this needs the count itself: the din is the same shock arriving at each of them, and what
-- it is measuring is the crowd, not the crowd's effect on one victim. Reading fx.aoeUnits twice --
-- once to count and once to strike -- is what says that out loud.
--
-- ADJACENCY: a `staff` beside it. The din is struck out of the ground, and it wants something to strike
-- the ground WITH -- which is the mage's own weapon family, so the spell asks its caster to be armed
-- rather than to carry another charm.
return {
    name = "The Answering Din",
    description = "A shock through the ground that hits harder for every body caught in it.",
    flavor = "One man hears a knock. Six hear an argument. The Arcanum finds this very funny.",
    sprite = "assets/items/ability_answering_din.png",
    type = "ability",
    tags = { "earth", "impact", "magical" },
    class = "mage",
    price = 400,
    repRank = 4,
    activeAbility = {
        target = "self", -- it runs out from the caster's own feet: no aiming, only placement
        range = 0,
        speed = 4,
        cost = { stat = "mana", amount = 16 },
        damage = { 5, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11 }, -- the base, before the crowd is counted
        aoe = { radius = 2, shape = "square" },
        requiresAdjacent = { tag = "staff" },
        ai = { priority = "high", act = "attack",
               when = { subject = "any_foe", test = "count_at_least", value = 3 } },
        effect = function(fx)
            local caught = fx.aoeUnits()
            -- Bodies OTHER than the caster: standing in your own din should not make it louder, or the
            -- spell would quote a bonus for existing.
            local crowd = 0
            for _, u in ipairs(caught) do
                if u ~= fx.user then crowd = crowd + 1 end
            end
            if crowd == 0 then return end
            -- Each body past the first adds its share to what EVERY body takes. Written flat rather
            -- than as a multiplier so the arithmetic stays something a player can do at the table:
            -- four bodies is three extra shares, and the tooltip's base number plus three of these.
            local bonus = (crowd - 1) * (3 + fx.level)
            for _, u in ipairs(caught) do
                if u ~= fx.user then
                    fx.damage(u, { amount = (fx.amount or 0) + bonus })
                end
            end
        end,
    },
}
