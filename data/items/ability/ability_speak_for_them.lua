-- SPEAK FOR THEM: the spirits bound in the caster's own gear say something, and everything nearby stops
-- being able to work (models/curse.lua, docs/curses.md).
--
-- THE COUNT BUYING DURATION RATHER THAN DAMAGE, which is the half of the counting shelf the weapons
-- cannot express. One turn of Silence per hex carried, on every enemy in arm's reach -- so a clean body
-- casting this does almost nothing and a body four hexes deep shuts a caster line down for most of a
-- fight.
--
-- WHICH MAKES IT THE ITEM THAT WANTS THE CHEAP HEXES. The Reckoning is happiest under The Anchor and The
-- Hollow -- deep, dreadful, worth a lot per point. This does not care HOW bad they are, only how many,
-- so it is the one piece of gear that would rather carry four Witnesses than one Anchor. That is a real
-- second axis for a player to build along, and it comes free out of counting instead of weighing.
--
-- NO DAMAGE AT ALL, on purpose: it is a support body's reason to be carrying curses, and a support body
-- that also hits would make the Shaman's shelf answer every question at once.
return {
    name = "Speak for Them",
    description = "Silences every adjacent enemy for one turn per hex the caster carries.",
    flavor = "Not words. The shapes a room makes when too many things are listening.",
    sprite = "assets/items/ability_speak_for_them.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "shaman",
    price = 495,
    unlockLevel = 9,
    activeAbility = {
        target = "self",
        range = 0,      -- a self-cast offers no reach to choose; the footprint says which tiles
        aoe = { radius = 1, shape = "square" },
        speed = 6,
        -- IT LANDS ONLY ON FOES, so it may not wear the friendly reach band. `support` is declared
        -- rather than guessed here because Combat.isSupportAbility reads `target == "self"` as a
        -- kindness by default, and a ring that silences everything around the caster is not one.
        support = false,
        cost = { stat = "mana", amount = 9 },
        counter = function(unit)
            return require("models.curse").countOn(unit and unit.char)
        end,
        counterGates = false,
        counterLabel = "Hexes",
        description = "Silences every adjacent enemy for one turn per hex the caster is carrying.",
        effect = function(fx)
            local n = require("models.curse").countOn(fx.user and fx.user.char)
            if n <= 0 then return end
            for _, u in ipairs(fx.aoeUnits() or {}) do
                if u ~= fx.user and u.side ~= fx.user.side then
                    fx.applyStatus(u, "status_silenced", { duration = n * 10 })
                end
            end
        end,
    },
}
