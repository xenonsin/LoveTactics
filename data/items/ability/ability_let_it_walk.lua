-- LET IT WALK: the Shaman puts a binding into something that can be killed, and lets somebody else swing
-- (models/curse.lua, docs/curses.md).
--
-- THE ONE WAY A CURSE ENDS WITHOUT A PRIEST, and the ruling still holds: the Shaman never lifts
-- anything. They take the hex off the piece, give it legs, and send it into the fight. If it is still
-- standing at the bell the binding comes home. If it died, it died carrying the curse.
--
-- WHICH MAKES A SUMMON YOU MIGHT WANT DEAD. Every other conjuration in the game is a body you are trying
-- to keep alive; this is the only one where feeding it to a boss on purpose is the correct play, and the
-- only place in the system where a Shaman is ever rid of something. Both of those are new decisions that
-- cost no new vocabulary at all.
--
-- IT PRICES ITSELF WHILE IT LASTS. For the length of the fight the hex is off the caster's gear, so
-- every counting item they own -- The Reckoning, The Gathered Weight, Speak for Them -- reads one lower.
-- Spending a curse and being paid for carrying it are the same resource pulled two ways.
--
-- THE SPIRIT WEARS THE WIND ELEMENTAL'S BODY for now, which is the one the Shaman's own Bind Spirit
-- already calls, so this ships on a body that is authored, tuned and tested. A bound-curse blueprint of
-- its own is the obvious later pass; nothing about the mechanic depends on it.
return {
    name = "Let It Walk",
    description = "Consumes a hex to summon a spirit. If it survives the fight, the hex returns.",
    flavor = "Whatever was in the blade is out of the blade now. It is looking around.",
    sprite = "assets/items/ability_let_it_walk.png",
    type = "ability",
    tags = { "summon", "dark" },
    class = "shaman",
    price = 575,
    unlockLevel = 11,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 7,
        cost = { stat = "mana", amount = 10 },
        counter = function(unit)
            return require("models.curse").countOn(unit and unit.char)
        end,
        counterGates = true,   -- no hex, nothing to spend: the cast is refused rather than wasted
        counterLabel = "Hexes",
        counterEmpty = "Nothing bound -- this needs a hex to spend",
        description = "Consumes the caster's deepest hex to summon a spirit carrying it.",
        effect = function(fx)
            local Curse = require("models.curse")
            local source = Curse.deepestOn(fx.user and fx.user.char)
            if not source then return end
            local id = Curse.lift(source)
            local spirit = fx.summon("character_wind_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                duration = 9999,
            })
            -- THE LEASH, read at the bell by Combat.releaseClaims. Parked on the ITEM the hex came off
            -- rather than on the caster, so the binding knows exactly where to go home to even if the
            -- grid has been rearranged in the meantime.
            if spirit then
                source.lentCurse = { id = id, spirit = spirit }
            else
                Curse.afflict(source, id) -- nowhere to put it: nothing was spent
            end
        end,
    },
}
