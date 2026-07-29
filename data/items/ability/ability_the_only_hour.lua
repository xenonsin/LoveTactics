-- Ira Unbound's signature (data/characters/character_general_wrath_demon.lua carries it in phase two):
-- her whole rule made a single swing. Its force climbs with the fraction of health she is MISSING --
-- an ordinary blow at full, twice that at death's door -- which, past the transform, is exactly where
-- she lives. She is most awake dying, and this is the blow she is most awake to throw.
--
-- It WINDS UP (windup 2), so it reads as a threat the party answers rather than a hit that just lands:
-- brace it (Defend), burst her below it, or break the wind-up with a Stun or a shove
-- (Combat.interruptChannel). Not fast on purpose -- a fast blow is a blow held back, and nothing is
-- held back now. Modeled on Desperate Strike (data/items/ability/ability_desperate_strike.lua), which pins
-- the missing-health scaling that this reads live off her current/max at the moment it resolves.
--
-- No `class`/`price`: an enemy's kit, never a shelf item; only its base value is ever seen.
return {
    name = "The Only Hour",
    description = "Increase damage by 1% per 1% of the wielder's missing health.",
    flavor = "Come and hit me properly. Not fast. Every blow you land wakes a little more of me up.",
    sprite = "assets/items/ability_desperate_strike.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "slash", "physical", "melee" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6,             -- heavy, and slow to come around again
        windup = 2,            -- the two-tick tell: brace, burst, or break it
        cost = { stat = "stamina", amount = 8 },
        damage = { 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36 }, -- the base, at full health; scaled up below
        effect = function(fx)
            local hp = fx.user.char.stats.health
            local ratio = (hp.max and hp.max > 0) and (hp.current / hp.max) or 1
            local missing = math.max(0, 1 - ratio)
            fx.damage(fx.target, { amount = fx.amount * (1 + missing) }) -- x1 full -> x2 at death's door
        end,
    },
}
