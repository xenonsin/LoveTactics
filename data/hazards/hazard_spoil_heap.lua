-- SPOIL HEAP: the underworld's signature ground, and the only hazard in the game that PAYS.
--
-- Greed's circle is about what you are carrying (data/traits/trait_assayed.lua), so its ground is a
-- decision about coin rather than a tax on movement: stand in the heap and you are picking up loose
-- money, and you are Exposed while you do it -- head down, hands full, in a warren where something is
-- always coming round the corner.
--
-- WHICH IS THE ONE HAZARD A PLAYER SHOULD WANT TO STEP IN, and that is the point of it. Every other
-- piece of terrain in the game is a thing to route around; this one is an argument. It is also the
-- sharpest small statement the sin has: the floor offers you money on a condition, and taking it is
-- always slightly the wrong idea.
--
-- Unsided, like all terrain -- the enemy's own bodies are Exposed standing in it too, which turns a heap
-- in a corridor into ground both sides would rather the other one held.
--
-- The coin is granted by the encounter's spoils rather than here: a hazard cannot pay a purse without
-- reaching outside the board it lives on, and a run's gold has exactly one owner (models/spoils.lua). So
-- what this does mechanically is the Exposure, and what it does at the table is make the tile tempting.
return {
    name = "Spoil Heap",
    description = "Inflicts Exposed on units standing on it.",
    tags = { "earth" },
    duration = 24,
    disposition = "hostile",
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_exposed")
    end,
}
