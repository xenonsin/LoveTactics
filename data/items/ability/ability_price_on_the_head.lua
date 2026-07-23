-- A Price on the Head: the rogue writes a body into the Undercroft's ledger. It is lit up for as long
-- as the price stands, and when it falls -- to anyone, to anything -- the company is paid.
--
-- THE FIRST ITEM IN THE GAME THAT MAKES GOLD IN COMBAT, and greed's shelf is the only one that should
-- have one. Every other ability here is measured in damage, tempo or ground; this one is measured in
-- the thing the player actually spends between battles, which makes it the only ability whose value is
-- decided by what is on sale at the vendors this week.
--
-- It pays out through the status rather than through this file (data/status/status_struck_ledger.lua),
-- because the promise is made about the TARGET and has to travel with it -- through a Cure, through a
-- Charm that flips its side, onto whoever the mark ends up on. And it pays only on a WON battle: the
-- bounty is banked on the combat (Combat.bounty) and collected with the spoils, so marking everything
-- and then losing pays exactly nothing.
--
-- THE SECOND HALF is the part that makes it worth casting on a hard target rather than an easy one: a
-- priced body is LIT (`revealsBearer`), so it cannot hide from being aimed at. That is the answer to
-- an enemy rogue, and it costs the same turn as the money.
--
-- ADJACENCY: it counts the `utility` charms around it. The Undercroft pays more for a contract written
-- by somebody who is obviously equipped for the work, which mechanically means the bounty scales with
-- how much of the rogue's grid is given over to trinkets rather than blades -- a thief's loadout, not
-- an assassin's, and a genuinely different build from the one Stillshade wants.
return {
    name = "A Price on the Head",
    description = "Marks a foe: it cannot hide, and its death pays the company in coin.",
    flavor = "The Undercroft does not want it dead. The Undercroft wants the receipt.",
    sprite = "assets/items/ability_price_on_the_head.png",
    type = "ability",
    tags = { "dark" },
    class = "rogue",
    price = 280,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 6,
        requiresSight = true,
        speed = 2, -- cheap and quick: a turn spent on paperwork should not cost the fight
        cost = { stat = "stamina", amount = 5 },
        support = true, -- it deals nothing at all
        effect = function(fx)
            -- The purse scales with the trinkets beside it in the grid, and with the forge. Both are
            -- flat adds rather than multipliers so the number stays something a player can read off
            -- the tooltip and plan a purchase around -- which is the whole reason to run this item.
            local charms = fx.adjacentMatching({ type = "utility" })
            local purse = 40 + 20 * charms + 8 * fx.level
            fx.applyStatus(fx.target, "status_struck_ledger", { magnitude = purse })
        end,
    },
}
