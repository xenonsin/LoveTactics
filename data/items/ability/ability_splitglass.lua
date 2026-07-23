-- Splitglass: the rogue puts a lie between themself and the next few blows. Two hits of ANY kind --
-- steel, fire, poison, an execution -- land on the reflection instead of the body.
--
-- COUNT, NOT SIZE, and that inversion is the entire item. Every other defence in this game is
-- arithmetic: armor subtracts, resist subtracts, a mana shield pays in the wrong pool, a barrier
-- answers one school. All of them are worth most against many small hits and least against the one big
-- one -- which is backwards from what anybody actually fears. Splitglass does not ask what is coming.
-- Two charges shrug off two arrows or two greatswords with exactly the same indifference.
--
-- So it is the rogue's answer to the thing a rogue cannot survive: being FOUND. A skirmisher's whole
-- defence is not being where the blow is, and the turn that goes wrong is the turn somebody guessed
-- right. This buys that turn back -- and only that turn, because the counterplay is deliberately
-- trivial. Throw anything at it, twice.
--
-- ADJACENCY, and this is the clever half: it counts the ITEMS AROUND IT. Each neighbour in the 3x3
-- grid adds a charge, so the same spell is worth two hits tucked in a corner and four in the centre
-- cell of a full loadout. That is a real cost -- the centre is the most contested cell on the grid,
-- and everything else the rogue owns wants to be adjacent to something too. A build that maximises
-- Splitglass is a build that has stopped optimising its knives.
return {
    name = "Splitglass",
    description = "Turns aside the next few hits of any kind -- one more for each item beside it.",
    flavor = "The Undercroft's first lesson: never be where they are looking. The second is for when you are.",
    sprite = "assets/items/ability_splitglass.png",
    type = "ability",
    tags = { "arcane" },
    class = "rogue",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2, -- very fast: a reflex you can afford to spend a turn on and still act next turn
        cost = { stat = "mana", amount = 10 },
        support = true,
        effect = function(fx)
            -- The grid is the magnitude. `adjacentMatching` with an empty predicate counts every
            -- neighbour whatever it is -- a knife, a potion, a boot -- because what the glass is
            -- splitting into is the rest of the kit, and the kit does not have to be sharp to be a
            -- reflection. Floored at the base so a cornered item still does something.
            local neighbours = fx.adjacentMatching({})
            local hits = 2 + neighbours + math.floor(fx.level / 3)
            fx.applyStatus(fx.user, "status_splitglass", { magnitude = hits })
        end,
    },
}
