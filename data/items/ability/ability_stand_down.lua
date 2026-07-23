-- Stand Down: one word, and the thing in front of you does not get to act.
--
-- The knight's other verb. Shout (data/items/ability/ability_shout.lua) takes an enemy's CHOICE of
-- target -- come at me and bring nothing clever; this takes the choice of acting at all
-- (data/status/status_halted.lua). Between them the shelf finally owns both halves of what a wall is
-- for: the first says where the blows land, the second says that this one doesn't land anywhere.
--
-- Sloth inflicted rather than suffered. Every other vendor's sin is the thing its line has to be
-- talked out of; the Bastion's is the thing it does to other people. A commanded foe keeps its weapon,
-- its pools and its feet -- and spends its turn holding all three.
--
-- Single target and short-ranged (2), because an order has to be heard. It is priced in stamina AND
-- mana, which is unusual for the shelf and is the point: the word is a working, not a bark, so a
-- silenced knight cannot give it (any mana in the price makes a cast sorcery -- see docs/weapons.md,
-- "paying for a cast out of more than one pool"). The Bastion's authority is a thing that can be
-- gagged, and a knight who has been gagged has only Shout left.
--
-- Deals nothing. `support = true` reads it green: it is a refusal, not a blow.
return {
    name = "Stand Down",
    description = "Halts one foe: it cannot use any ability on its next turn. It may still move.",
    flavor = "The order does not care whether it is obeyed. It only cares that it was given.",
    sprite = "assets/items/ability_shout.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "impact" },
    class = "knight",
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "unit",
        range = 2,
        speed = 4,
        requiresSight = true, -- an order has to be heard, and a wall between you eats it
        support = true,       -- a refusal, not a strike: it reads green and lands no damage
        cost = { { stat = "stamina", amount = 6 },
                 { stat = "mana",    amount = 6 } },
        effect = function(fx)
            if not fx.target or fx.target.side == fx.user.side then return end
            -- Duration scales with the forge: a better-kept commission is obeyed a beat longer.
            fx.applyStatus(fx.target, "status_halted", { duration = 5 + fx.level })
        end,
    },
}
