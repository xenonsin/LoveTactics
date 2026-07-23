-- The Held Reaction: the alchemist mixes something and does not throw it. Every turn it is held the
-- mixture gets worse -- and if it is held too long it goes off in their hand.
--
-- THE CHARGEABLE WIND-UP, used the way the mechanic was built to be used. `windup` is the extra ticks
-- poured into a channel beyond its minimum, handed to the effect as `fx.windup` (see Combat.useItem's
-- channel branch and the signature contract). Everything else that reads it scales a blow with it;
-- this one scales a blow AND a risk, which is the version envy should have.
--
-- Why it is envy's rather than wrath's: the alchemist's whole shelf covets other people's power rather
-- than casting any (docs/classes.md), and what this covets is TIME. It is the only item in the game
-- that converts patience directly into damage, and it charges interest -- past the safe window the
-- mixture answers to whoever is holding it, which is always the alchemist.
--
-- The blast is unsided at radius 1, so a held reaction that goes off in hand takes the alchemist's own
-- neighbours with it. Standing beside your own bomb-thrower is a decision the party gets to make every
-- turn they can see the badge.
--
-- ADJACENCY, and this is the whole build: it scales off the `consumable` items around it. Each vial,
-- bomb or elixir in the neighbouring cells feeds the mixture, so a Held Reaction in the middle of a
-- satchel loadout is enormous and one tucked next to two knives is not. That is the alchemist's grid
-- doing exactly what the class says it does -- borrowing from what is beside it.
return {
    name = "The Held Reaction",
    description = "Mixes a blast that grows every turn it is held -- and goes off in hand if held too long.",
    flavor = "The Crucible measures its apprentices in fingers. It is not being cruel; it is being accurate.",
    sprite = "assets/items/ability_held_reaction.png",
    type = "ability",
    tags = { "fire", "explosive" },
    class = "alchemist",
    price = 400,
    repRank = 4,
    activeAbility = {
        description = "Held longer, it hits harder -- past the safe window it bursts on the alchemist.",
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 4,
        channel = 2,      -- the minimum mix
        windup = 4,       -- and up to four more ticks of holding it, at the player's discretion
        cost = { stat = "mana", amount = 12 },
        damage = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
        aoe = { radius = 1, shape = "square" },
        adjacencyScaling = { type = "consumable" },
        effect = function(fx)
            local held = fx.windup or 0
            local satchel = fx.adjacentMatching({ type = "consumable" })
            -- Every tick held adds a share, and every neighbouring consumable makes the share bigger.
            -- Flat arithmetic rather than a multiplier so the tooltip's number and the number the
            -- player counts on their fingers are the same number.
            local bonus = held * (3 + 2 * satchel)
            -- THE SAFE WINDOW. Past three ticks of holding, the mixture answers to the hand rather
            -- than the target: the blast is centred on the alchemist instead, at full strength. Not a
            -- reduced penalty -- the whole thing, where they are standing, because a risk the player
            -- can absorb is not a risk they will ever think about.
            local burstsInHand = held > 3
            local victims = burstsInHand
                and fx.unitsNear(fx.user.x, fx.user.y, 1)
                or fx.aoeUnits()
            if burstsInHand then
                fx.log("action", string.format("%s holds it a beat too long.",
                    fx.user.char and fx.user.char.name or "The alchemist"), fx.user)
            end
            for _, u in ipairs(victims) do
                fx.damage(u, { amount = (fx.amount or 0) + bonus })
            end
        end,
    },
}
