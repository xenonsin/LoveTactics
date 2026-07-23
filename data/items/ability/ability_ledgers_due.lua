-- The Ledger's Due: the rogue kneels over a body, takes what the Undercroft is owed, and the body is
-- gone. No corpse, nothing to raise, nothing to revive -- and the company's purse is heavier.
--
-- THE OTHER SIDE OF GREED'S ECONOMY, and it is deliberately built as a TRANSACTION rather than a
-- reward. A Price on the Head pays for a kill that was going to happen anyway; this charges a real
-- price for its coin, and the price is paid in things the party might have wanted:
--
--   * The corpse is CONSUMED (Combat.consumeCorpse). Anything that reads bodies -- Revive, Raise Dead,
--     the necromancer's whole shelf -- finds nothing there. In a party with a priest, spending a body
--     is spending a resurrection.
--   * It costs a full action, on a turn in the middle of a battle, standing over a corpse -- which is
--     to say, standing where somebody just died. That is rarely a safe tile.
--
-- So the item is a question asked every time a body drops: is the fight already won enough that a turn
-- is worth money? A rogue who answers yes too early loses fights, and one who never answers yes has
-- bought a slot that does nothing.
--
-- IT DOES NOT CARE WHOSE BODY IT IS. An ally's corpse pays exactly the same as an enemy's, and the
-- Undercroft would consider any other arrangement sentimental. That is the flavour and it is also the
-- sharpest decision the item offers: the party's own fallen companion is worth precisely as much as
-- the coin, and it is the player who has to say so.
--
-- ADJACENCY: any `utility` charm beside it, and the coin scales with how many. Same reading as the
-- Price -- the Undercroft settles more generously with somebody visibly in the trade.
return {
    name = "The Ledger's Due",
    description = "Spends a corpse for coin: nothing can raise or revive it afterwards.",
    flavor = "Every name in the book has a number beside it. The book does not ask how the name got there.",
    sprite = "assets/items/ability_ledgers_due.png",
    type = "ability",
    tags = { "dark" },
    class = "rogue",
    price = 260,
    repRank = 2,
    activeAbility = {
        target = "tile",
        range = 1, -- you have to be standing over it
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        support = true,
        requiresAdjacent = { type = "utility" },
        effect = function(fx)
            local body = fx.corpseAt(fx.tx, fx.ty)
            if not body then
                fx.log("action", "There is nothing here worth writing down.", fx.user)
                return
            end
            local charms = fx.adjacentMatching({ type = "utility" })
            local coin = 55 + 25 * charms + 10 * fx.level
            -- Consume FIRST, pay second: a body that could not be spent (already raised, already
            -- consumed) must not pay, and ordering it this way means the refusal is the same refusal
            -- Combat.consumeCorpse already makes rather than a second check that could disagree.
            if fx.consumeCorpse(body) then
                fx.bounty(coin)
                fx.log("action", string.format("%s settles the ledger: %d gold.",
                    fx.user.char and fx.user.char.name or "Unit", coin), fx.user)
            end
        end,
    },
}
