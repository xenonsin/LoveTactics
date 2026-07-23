-- The Demon Champion's phase-1 heavy: a telegraphed cleave down the lane. Like the axe archetype
-- (data/items/weapon/weapon_iron_axe.lua) it aims an adjacent tile that sets the facing and sweeps a
-- 3-wide arc in front, hitting everything in it -- but it WINDS UP over two ticks first, so it reads as
-- a threat the player answers rather than a swing that just lands. The answer is the lesson: Defend to
-- brace it, or step out of the arc, or break the wind-up with a Stun or a shove (Combat.interruptChannel).
--
-- The arc does not care whose side it sweeps (fx.aoeUnits returns everyone in it): the Champion will
-- catch its own Bomblets in it too, which is fine -- a Volatile it pops just bursts.
return {
    name = "Demon's Cleave",
    description = "Winds up a heavy sweep, cutting everything in a wide arc in front of it.",
    flavor = "It draws the blow back far enough that you can see it coming. Whether you move is your affair.",
    sprite = "assets/items/great_claws.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "slash", "physical", "melee" },
    activeAbility = {
        target = "tile",       -- aim an adjacent tile: it sets the facing the arc sweeps
        allowOccupied = true,
        range = 1,
        minRange = 1,          -- must pick a neighbor (a facing); never its own tile
        speed = 6,             -- heavy, and slow to come around again
        channel = 2,           -- the two-tick tell: brace, step, or break it
        cost = { stat = "stamina", amount = 10 },
        damage = { 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22 }, -- a real hit -- the reason to brace it
        aoe = { shape = "front", width = 3 }, -- a 3-wide arc in front, like an axe cleave
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u) end
            end
        end,
    },
}
