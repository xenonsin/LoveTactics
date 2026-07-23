-- A hammer, so it is ponderous and it takes a turn away (docs/weapons.md). It takes far more than one:
-- the blow puts the target to Sleep (status_sleep), shoving it a long way down the turn order -- until
-- something wakes it, which anything hitting it will.
--
-- The longest single piece of control on the fighter's shelf, and the most fragile. A stun is a fixed
-- shove nobody can undo; this is a much larger one that the party's own next attack will cancel. So it
-- is not a damage-race tool at all -- it is a way to make a four-on-three fight into a three-on-three
-- for as long as everyone can keep their hands off one of them.
--
-- Which is a real discipline to play, and the reason it sits high on the shelf: it asks the whole party
-- to agree not to hit something, and it punishes the archer who fires without looking. Every AoE the
-- party owns is a liability while it holds.
return {
    name = "Sleeper's Maul",
    description = "Puts the target to sleep rather than stunning it -- far longer, and broken the moment anyone strikes it.",
    flavor = "The Colosseum crowd hates it. It is the only weapon there that makes the fight quieter.",
    sprite = "assets/items/sleepers_maul.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "fighter",
    price = 620,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7,
        cost = { stat = "stamina", amount = 12 },
        -- Under an iron hammer's, and deliberately so: this weapon wants its own damage to be small,
        -- because its damage is the thing most likely to wake what it just put down.
        damage = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_sleep" })
        end,
    },
}
