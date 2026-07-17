-- Polymorph: turn a foe into a pig. It keeps its health and its tile and loses every verb it had --
-- see data/characters/pig.lua, a body with no items and no fangs, which can walk and can do nothing
-- else. The mage's answer to a thing it cannot kill: you do not have to beat the champion if the
-- champion is livestock for the next eight ticks.
--
-- Landing it is DETERMINISTIC -- there is no roll here, unlike Charm, which is the other "take a foe
-- out of the fight" spell on the shelf. What varies is the DURATION: the victim's magicDefense (plus
-- any statusResist it wears) shortens the shape, and every previous Polymorph on that same victim this
-- battle halves it again, until the fourth or so simply does not land at all. See the resistance
-- contract in models/status.lua. The player can therefore read the board and know exactly what this
-- buys before spending the mana on it -- and so can the victim, which is the point: "he might be a pig
-- for a while" is not a thing anyone can plan around.
--
-- The whole spell lives in the status (data/status/polymorph.lua), which wears the shape on apply and
-- takes it off on expiry. This file only aims it. That means the resistance gate runs BEFORE anything
-- transforms -- a shrugged-off cast is a wasted turn and nothing else, never a pig with no timer.
--
-- A boss is unmoved, exactly as it is by Charm and Coup de Grace: the fights the game builds around a
-- single body are not fights a single spell gets to end.
return {
    name = "Polymorph",
    description = "Turns a foe into a pig: it can move, and nothing else. Bosses are unmoved.",
    flavor = "You do not have to beat the champion if the champion is livestock.",
    sprite = "assets/items/ability_polymorph.png",
    type = "ability",
    tags = { "arcane", "magical", "illusion", "utility" },
    class = "mage",
    price = 380,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 7,
        cost = { stat = "mana", amount = 20 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if t.char.boss then
                fx.log("action", string.format("%s is unmoved.", t.char.name or "The target"))
                return
            end
            fx.applyStatus(t, "status_polymorph")
        end,
    },
}
