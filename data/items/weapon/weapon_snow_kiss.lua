-- THE SNOW KISS: the Yuki-onna's natural weapon ("Sloth's Bestiary", 2026-10-04).
--
-- A KISS THAT MAKES YOU DROWSY (the creature identity pass, 2026-11-19). It used to deal double to a sleeper and
-- leave it asleep -- the Alraune's Nightshade with the opposite ending, and one of three Sloth bodies that fed on
-- a sleeper. The Mare rides one and Baku eats them; the Yuki-onna is the one who PUTS them there. So the kiss
-- lays a stack of Drowsy (status_drowsy: at 3 the body falls Asleep), beside her Snow-Sleep, which lays it on
-- anyone who stands still near her. Two ways to reach 3, and she is the body to kill before the Mare arrives.
--
-- Paid in mana, so a snapped horn (the oni race's rule) takes the kiss off her. ICE and MAGICAL. A natural
-- weapon: no class, no price, noSteal.
local Curve = require("models.curve")

return {
    name = "Snow Kiss",
    description = "Inflicts Drowsy. Does not wake a sleeping foe.",
    flavor = "It is very cold, and then it is not cold at all. That is the part to worry about.",
    sprite = "assets/items/weapon_snow_kiss.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "ice", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "mana", amount = 6 },
        damage = Curve.ramp(6, 16),
        -- THE KISS DOES NOT WAKE (`sparesSleep`, Combat.sparesSleep): Sleep's answer to a wound is to wake, and it
        -- is heard after the blow resolves -- so without this the kiss that lays the third stack would put the body
        -- under and wake it in the same beat. It also leaves a sleeper someone else put down asleep, which is what
        -- makes her the Mare's partner rather than her rival. No doubling: she lays sleep, she does not feed on it.
        effect = function(fx)
            local tgt = fx.target
            fx.damage(tgt, { sparesSleep = true })
            if tgt and tgt.alive then fx.applyStatus(tgt, "status_drowsy") end
        end,
    },
}
