-- Power Strike: a committed, heavy swing that leaves the target reeling. It can only be thrown with a
-- MELEE weapon sitting adjacent to it in the 3x3 item grid (Combat.adjacencyMet gates the cast). It
-- deals its damage and STUNS -- shoving the victim down the turn order (data/status/stun.lua) -- so it
-- both hurts and buys tempo. The disciplined cousin of the War Hammer: the same stun, off any blade.
return {
    name = "Power Strike",
    description = "Deals damage and inflicts Stun. Requires an adjacent melee weapon.",
    flavor = "The disciplined cousin of the war hammer: the same stun, off any blade at all.",
    sprite = "assets/items/ability_power_strike.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "fighter",
    price = 320,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 12 },
        damage = { 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16 },
        requiresAdjacent = { type = "weapon", tag = "melee" }, -- a melee weapon must sit adjacent in the grid
        effect = function(fx)
            -- The stun rides the blow, so the reeling target does not answer it (see the War Hammer).
            fx.damage(fx.target, { inflicts = "status_stun" })
        end,
    },
}
