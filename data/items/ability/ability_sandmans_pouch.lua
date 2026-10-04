-- SANDMAN'S POUCH: the Sandman's sowing, lifted off him for a trapper (data/characters/character_the_sandman.lua;
-- "Sloth's Bestiary", slice G, approved word for word). Sow sand on a 3x3; anything standing in it at the start of
-- your next turn falls Asleep.
--
-- A WIND-UP, which is what "at the start of your next turn" is in this engine (the Undertow's reading): the channel's
-- ghost is the sown sand, a turn early, and the sleep is its resolution. A Trapper's because it is ground laid for
-- whoever is standing there when it comes due -- and, like every snare, it does not ask whose side they are on.
--
-- Plain Sleep: Bad Dreams is the Sandman's own and stays on him. An unstocked trophy on the approach's rung (floor
-- 9, the stair he stands on), noSteal like every stair piece.
return {
    name = "Sandman's Pouch",
    description = "Sow sand on a 3×3. Anything standing in it at the start of your next turn falls Asleep.",
    flavor = "Never quite empty. Nobody has ever been awake long enough to check.",
    sprite = "assets/items/ability_sandmans_pouch.png",
    type = "ability",
    tags = { "earth", "magical", "relic" }, -- a stair's own piece (tests/sin_drops_spec.lua)
    class = "trapper",
    unlockLevel = 9,
    unstocked = true,
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        speed = 5,
        windup = 5, -- a turn: the sand comes due as your next turn comes round
        cost = { stat = "stamina", amount = 10 },
        support = true, -- it lands no damage at all, and damage is the thing that undoes it
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user then fx.applyStatus(u, "status_sleep", { applier = fx.user }) end
            end
        end,
    },
}
