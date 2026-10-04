-- THE TRILL: the Frost Worm's (data/characters/character_frost_worm.lua; "Sloth's Bestiary", 2026-10-04, slice C;
-- from the D&D frost worm). Every other turn it rears and trills: a wind-up shown as a ring of radius 4, and
-- every body inside the ring when it lands, ON EITHER SIDE, falls Asleep. The worm's own line sleeps with you.
--
-- THE COUNTER IS THE TELL. Break the wind-up with hard control or a shove (Combat.interruptChannel), or be outside
-- the ring when it lands. A sleeper wakes when it is hit, so a company that does go down wakes its own by hitting
-- them. Centred on the worm (`target = "self"`), so the ring travels with it if it is moved -- and a shove breaks
-- it anyway.
--
-- "EVERY OTHER TURN" is a cooldown in ticks (14) measured to the worm's own pace: rear (windup 5), land (speed 5),
-- bite, rear again. An interrupted trill still spent its cooldown, so breaking it buys the turn after as well.
return {
    name = "The Trill",
    description = "Channeled: everyone in area falls Asleep.",
    flavor = "The note is pitched just under hearing. The body hears it anyway, and lies down.",
    sprite = "assets/items/ability_the_trill.png",
    type = "ability",
    class = "creature",
    tags = { "ice", "magical" },
    noSteal = true, -- the worm's throat, not a thing it carries
    bound = true,
    activeAbility = {
        target = "self",
        support = false, -- a self-centred blast, not a kindness (Combat.isSupportAbility)
        range = 0,
        windup = 5,
        speed = 5,
        cooldown = 14,
        aoe = { shape = "diamond", radius = 4 },
        ai = {
            { priority = "high", act = "cast", when = { subject = "any_foe", test = "exists" } },
        },
        effect = function(fx)
            fx.burst(fx.user.x, fx.user.y, { "ice" })
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.alive then fx.applyStatus(u, "status_sleep") end
            end
        end,
    },
}
