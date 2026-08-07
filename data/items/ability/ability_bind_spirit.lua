-- Bind Spirit: the mage half of the Shaman (hunter x mage), and the discipline's signature made literal.
-- A wind spirit is called AND a squall is bound into it: the storm is owned by the spirit, so it travels
-- wherever the spirit goes.
--
-- The mechanic is entirely borrowed and none of it is new. Hazard.place takes an `owner`; Combat's
-- movement path already calls Hazard.carry on whatever a moving body holds open (that is how a heaved
-- banner drags its rally square with it); and Hazard.dropOwnedBy takes the ground away when the owner
-- falls. Put together, those three give a spirit that IS the weather -- kill it and the storm stops.
--
-- That last part is the counterplay and the reason this is fair. Every other zone in the game has to be
-- waited out or walked around. This one has a throat.
--
-- One inherited rule worth knowing before you buy it: held ground travels with a body that WALKS or is
-- MOVED, and stays put when one BLINKS (Hazard.carry rides the `walk`/`forced` gate). So a spirit shoved
-- down the lane drags the squall with it, and a spirit teleported across the field arrives bare. That is
-- the engine's existing rule for banners rather than anything this file chose, and it cuts both ways --
-- an enemy that shoves your spirit has moved your weather for you.
--
-- The squall is a Gagging Storm: everything standing in it is Silenced, and a channel caught in it
-- shatters. So the Shaman's answer to an enemy caster is not a counterspell, it is a weather front with
-- legs that walks over and stands on them.
return {
    name = "Bind Spirit",
    description = "Summons a wind spirit carrying a Gagging Storm that follows it.",
    flavor = "It asked the wind to come along. The wind has never really understood the difference between yes and here.",
    sprite = "assets/items/ability_bind_spirit.png",
    type = "ability",
    tags = { "summon", "lightning" },
    class = "mage",
    discipline = "shaman",
    price = 680,
    unlockQuests = 10,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        description = "Summons a wind spirit carrying a Gagging Storm that travels with it.",
        effect = function(fx)
            local spirit = fx.summon("character_wind_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                amount = 8 + fx.level,
                duration = 20,
            })
            if not (spirit and spirit.alive) then return end
            -- Owned by the SPIRIT, not the caster: that is what makes it travel with the spirit and
            -- lapse when the spirit does (Hazard.carry / Hazard.dropOwnedBy).
            for dy = -1, 1 do
                for dx = -1, 1 do
                    fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_gagging_storm",
                        { owner = spirit, duration = 9999 })
                end
            end
        end,
    },
}
