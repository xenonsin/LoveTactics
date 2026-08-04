-- The Question: the rogue half of the Inquisitor (rogue x priest). Takes one blessing off a Marked body
-- and puts it on yourself.
--
-- Not a dispel -- a theft. The shelf's priest half (Sentence) destroys what it strips; this keeps it,
-- which is the difference between the two halves of this discipline and the reason it is rogue x priest
-- rather than two clerics. The Cathedral burns the heresy; the Undercroft finds a use for it.
--
-- One at a time, and always the FIRST it finds, so it is not a shopping trip: an Inquisitor who wants a
-- particular blessing has to ask more than once, and every asking costs a turn during which the mark can
-- still walk away.
--
-- Marked only, like Sentence. The mark is the licence, and the whole discipline is built on the idea
-- that you must accuse before you may act.
return {
    name = "The Question",
    description = "Takes a blessing from a Marked foe and puts it on yourself.",
    flavor = "He does not want the answer. He wants the thing they were holding while they gave it.",
    sprite = "assets/items/ability_the_question.png",
    type = "ability",
    tags = { "guile" },
    class = "rogue",
    discipline = "inquisitor",
    price = 380,
    unlockQuests = 9,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        description = "Moves one blessing off a Marked foe and onto you.",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if not fx.hasStatus(t, "status_mark") then
                fx.log("action", "There is nothing to ask an unaccused body.")
                return
            end
            local taken = fx.dispelUnit(t, 1)
            if #taken == 0 then
                fx.log("action", "They were holding nothing worth taking.")
                return
            end
            fx.applyStatus(fx.user, taken[1])
        end,
    },
}
