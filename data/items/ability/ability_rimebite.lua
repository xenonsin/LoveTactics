-- Rimebite: a splinter of cold left in one body, which reopens every single time anything hits it.
--
-- A MULTIPLIER ON ATTENTION, which is a shape of debuff the game did not have. Burn and Poison are
-- clocks: they pay the same whether the party ignores the target or piles onto it, so they reward
-- casting and then leaving. This pays per HIT, from anyone, of any kind -- so it is worth almost
-- nothing cast at a body nobody is going to touch, and enormous cast at the one the party has already
-- decided to kill.
--
-- Which makes it the pride shelf's contribution to a kill the mage is not personally making. That is a
-- role the class could not previously fill: every other mage item is a number the mage produces, and
-- this is a number four other people produce because the mage spent a turn. The dagger that hits for 6
-- four times a round is suddenly the best weapon on the field.
--
-- Deliberately cheap and fast, and deliberately not stacking with itself -- one instance per body (as
-- every status in this game is), so the play is to spread it, not to deepen it. A mage with Rimebite
-- and three turns has marked three targets, and the party chooses which of the three is convenient.
--
-- ADJACENCY: an `ice` item beside it. The splinter is cold, and the ice slot is the one the Ice Bolt,
-- the ice bomb and the frost fists all want -- so a party that leans on rime has to decide whether the
-- mage is the one carrying it.
return {
    name = "Rimebite",
    description = "Leaves cold in a foe: it takes extra damage every time anything hits it.",
    flavor = "It is not the cold that does it. It is that the wound keeps remembering the cold.",
    sprite = "assets/items/ability_rimebite.png",
    type = "ability",
    tags = { "ice", "magical" },
    class = "mage",
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 5,
        requiresSight = true,
        speed = 3, -- fast: it is a setup, and a setup that costs a full turn is rarely worth it
        cost = { stat = "mana", amount = 10 },
        requiresAdjacent = { tag = "ice" },
        effect = function(fx)
            -- No damage of its own at all. Everything this spell is worth is paid by somebody else's
            -- weapon, which is the entire idea -- and it is why the magnitude, not a damage row, is
            -- what the forge raises.
            fx.applyStatus(fx.target, "status_rimebitten", { magnitude = 4 + fx.level })
        end,
    },
}
