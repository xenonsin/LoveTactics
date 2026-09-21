-- REBIND: move a hex onto the body standing next to you (models/curse.lua's Curse.move, docs/curses.md).
--
-- THE SHAMAN'S HEADLINE VERB, and the one that makes "manipulate, never remove" productive rather than
-- merely restrictive. The company's hex count is identical afterwards. What changed is WHO it happens
-- to -- and because a curse's penalties are live on the board, that is a real tactical act: pull The
-- Anchor off the knight who has to charge and onto the one already holding the chokepoint.
--
-- IT COSTS A TURN, A POSITION AND AN ADJACENCY. An earlier draft of this moved hexes between grid cells
-- from a menu, and a menu is not a play; the two bodies have to be standing together, in a fight, on
-- somebody's turn. That is the whole difference between a loadout screen and an ability.
--
-- IT TAKES THE DEEPEST ONE, which is not a convenience. A chooser would put a second modal on top of a
-- targeting mode for a decision the player almost always makes the same way -- the hex worth moving is
-- the one hurting most -- and Curse.deepestOn breaks its ties by cell so a replayed fight moves the same
-- piece twice.
--
-- The ally may refuse it: a grid with no cell that can take a hex (all hexed, all natural, consecrated)
-- simply does not receive one, and Curse.move checks the destination BEFORE it empties the source, so a
-- refused move can never destroy a binding.
return {
    name = "Rebind",
    description = "Moves the caster's deepest hex onto an adjacent ally's kit.",
    flavor = "It does not mind whose hand it is in. That was never the part it cared about.",
    sprite = "assets/items/ability_rebind.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "shaman",
    price = 330,
    unlockLevel = 5,
    activeAbility = {
        target = "ally",
        range = 1,
        speed = 4,
        cost = { stat = "mana", amount = 6 },
        description = "Moves the caster's deepest hex onto an adjacent ally's kit.",
        effect = function(fx)
            local t = fx.target
            if not (t and t.char and fx.user and fx.user.char) then return end
            local Curse = require("models.curse")
            local from = Curse.deepestOn(fx.user.char)
            if not from then return end
            for _, item in ipairs(require("models.character").eachItem(t.char)) do
                if Curse.canAfflict(item) and Curse.move(from, item) then return end
            end
        end,
    },
}
