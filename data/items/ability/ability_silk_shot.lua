-- SILK SHOT: the spider line's reach. The web catches whoever walks into it; this catches whoever
-- stayed off it. A foe in sight is Rooted (cannot walk, cannot be moved) and Halted (cannot use any
-- ability) for about a turn -- two ordinary debuffs, so a Cure answers both, and Halted leaves reflexes
-- alone by its own rule, so a bound knight still parries.
--
-- THE LOCKDOWN CEILING, stated because three spiders take turns: `notOn` keeps the planner from aiming
-- it at a body already Rooted or Halted (Combat.abilityTargets), so a second spider does not chain the
-- first one's catch out of the fight -- and the stamina bill against a regen of 3 is one shot in about
-- three turns per spider.
return {
    name = "Silk Shot",
    description = "Inflicts Root and Halted on a foe in sight.",
    flavor = "It does not need you close. It needs you still.",
    sprite = "assets/items/ability_silk_shot.png",
    type = "ability",
    class = "creature",
    tags = { "silk", "physical" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        notOn = { "status_root", "status_halted" },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.applyStatus(t, "status_root")
            fx.applyStatus(t, "status_halted")
        end,
    },
}
