-- Everflask: a self-replenishing vessel with no ability of its own. Through the 3x3 item grid it
-- spares the consumables sitting adjacent to it (diagonals included) from being spent: a Fire Bomb
-- next to it can be thrown again and again without draining its stack. The Crucible's most coveted
-- charm, and rank-gated to match -- a bomb that never runs out is the whole class's dream.
--
-- The `preserve` flag is read in Combat.useItem, which skips the stack decrement for a consumed item
-- whose grid neighbor grants it. It changes nothing else: the throw still costs its stamina/mana and
-- still ends the turn, so it is free ammunition, not a free action.
return {
    name = "Everflask",
    description = "Adjacent consumables are not spent when used.",
    flavor = "The Crucible's most coveted charm. A bomb that never runs out is the whole trade's dream.",
    sprite = "assets/items/everflask.png",
    type = "utility",
    tags = { "arcane" },
    class = "alchemist",
    price = 520,
    repRank = 3,
    aura = {
        appliesTo = { "consumable" }, -- only the throwables and potions it sits beside
        preserve = true,              -- the neighbor consumable's stack is not decremented on use
    },
}
