-- SWALLOW: the Giant Toad takes a foe beside it down whole (status_swallowed) and becomes a far worse
-- animal for as long as it is holding one. Settled on review 2026-09-25: "have the swallow buff the toad a
-- lot and he turns tankier and stronger".
--
-- THE MEAL IS THE POWER SPIKE. The Sated's Full (status_full), handed the toad's own table at apply time
-- -- about double the Sated's per meal -- so a toad with a body inside it hits much harder and shrugs off
-- much more, and every digestion tick heals it besides. The movement it costs is a price it does not pay:
-- it hops (utility_toad_legs), and a hop does not read the movement stat.
--
-- THE COUNTER IS ON THE TOAD. A blow of a quarter of its health, a stun, or its death makes it spit the
-- body out Wet, and the Full goes with it (trait_gullet, carried here so the rule rides the verb). Cure
-- does nothing: the body is not wearing anything, it is inside something.
--
-- One at a time (`usable`), never a boss, never a body bigger than a tile (Combat.canSwallow). The status
-- is only landed when the swallow is legal, so a refused one costs nothing and forecasts nothing.
local Combat = setmetatable({}, { __index = function(_, k) return require("models.combat")[k] end })

-- One meal, in status_full's own units. Double the Sated's +3/+3, and a magic line the Sated's has not
-- got: a toad that has eaten is a wall against a mage as well as a sword.
local MEAL = { damage = 6, defense = 6, magicDefense = 4, movement = -1 }

return {
    name = "Swallow",
    description = "Swallows an adjacent foe to digest for 3 turns; while it is inside, gain +6 damage, "
        .. "+6 defense and +4 magic defense.",
    flavor = "The jaw unhinges. Then there is one fewer of you, and the toad is sitting differently.",
    sprite = "assets/items/ability_swallow.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "physical" },
    noSteal = true,
    traits = { "trait_gullet" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        ai = { priority = "high", act = "cast" },
        usable = function(unit)
            if unit.swallowing then return false, "Its mouth is full" end
            return true
        end,
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if fx.combat and not Combat.canSwallow(fx.combat, fx.user, t) then return end
            local st = fx.applyStatus(t, "status_swallowed", { magnitude = 6, duration = 15, applier = fx.user })
            if st then fx.applyStatus(fx.user, "status_full", { magnitude = 1, statBonus = MEAL }) end
        end,
    },
}
