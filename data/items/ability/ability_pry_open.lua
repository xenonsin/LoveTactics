-- Pry Open: the rogue half of the Vanguard's Breach. A precise strike that levers a foe's guard aside --
-- Sundered (data/status/status_sundered.lua): guards, reflexes and traits go quiet -- so the next blow,
-- from anyone, lands clean. Greed's guile pointed at a shield instead of a purse.
return {
    name = "Pry Open",
    description = "Strikes a foe and Sunders it: its guards and reflexes go quiet, opening it to the party.",
    flavor = "Every lock is a promise that the door will hold. She has never once believed one.",
    sprite = "assets/items/ability_pry_open.png",
    type = "ability",
    tags = { "pierce", "physical", "guile" },
    class = "rogue",
    discipline = "vanguard", -- knight x rogue; the Breach mechanic's first stock
    price = 240,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = { 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 12 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_sundered")
        end,
    },
}
