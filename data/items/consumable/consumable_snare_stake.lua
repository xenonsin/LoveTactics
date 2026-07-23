-- A Snare Stake sold by the handful: the Lodge's oldest tool (data/traps/snare_stake.lua), driven into
-- the floor from a kit instead of cast as an ability. It plants a hidden stake that Roots the first foe
-- across it and draws no blood -- the pure hold, gluttony's setup (docs/classes.md, `traps`) as a fight
-- decision you spend rather than a turn you invest.
--
-- The difference from the Snare Stake ABILITY (data/items/ability/ability_snare_stake.lua) is the whole
-- reason both exist: the ability is a repeatable investment that gates on a bow beside it, and holds
-- longer for being forged. This is the disposable version -- one stake, no adjacency gate, gone when it
-- is used -- for the hunter who wants the ground held for a volley without building their grid around
-- laying it. It seeds the floor in ADVANCE, hidden, which is exactly what separates a trapper's control
-- from the rogue's throw-it-now denial (compare the Ball Bearings).
return {
    name = "Snare Stake Kit",
    description = "Plants a hidden stake: Roots the first enemy across it, and draws no blood.",
    flavor = "The Lodge never improved the stake. It did learn to sell you a bundle of them.",
    sprite = "assets/items/snare_stake_kit.png",
    type = "consumable",
    tags = { "trap" },
    class = "hunter",
    price = 110,
    repRank = 2,
    activeAbility = {
        target = "tile", -- planted on open ground, not on a foe
        range = 2,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        support = true, -- a placement lands nothing on the turn it is set
        consumesItem = true,
        effect = function(fx)
            -- The trap's `amount` rides in as the root's DURATION (see the trap's onTrigger), a touch
            -- shorter than the forge-able ability's hold since a kit stake is spent, not honed.
            fx.placeTrap(fx.tx, fx.ty, "snare_stake", { amount = 8 + fx.level })
        end,
    },
}
