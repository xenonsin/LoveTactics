-- Battleborn: the Warlord's charm for needing nothing set up. Carries trait_battleborn -- fell a foe
-- that nothing had weakened and the turn is handed back, once a turn.
--
-- THE OPPOSITE HALF OF THE SAME MECHANISM the Poacher's Thrill of the Hunt spends, and the pair is the
-- point. Both hand back a turn for a kill; one requires the body to have been prepared and the other
-- requires that it was not. Read together they say what separates the two shelves better than either
-- says alone: gluttony's hunter earns its tempo a turn in advance, and wrath's warlord refuses to
-- spend a turn in advance at all. Wrath is what happens directly in front of you (docs/classes.md).
--
-- WHY THE WARLORD'S rather than the Barbarian's, since both are fighter subclasses and both like a
-- kill. Barbarian's vocabulary is fury and self-harm -- it buys power by spending its own body. Warlord
-- buys tempo for the LINE: banners, rally ground, inspiration, the extra action. This is an extra
-- action, and it belongs with the others.
--
-- It sits deliberately awkwardly beside the Culling Stroke, which is the fighter's other "a kill hands
-- the turn back" and is the Barbarian's. That is not a duplication: the Stroke pays for finishing
-- something ALREADY nearly dead (its whole arc is being worthless on turn one and decisive on turn
-- five), and this pays for finishing something that was not hurt at all. The two charms want opposite
-- moments of the same fight, and a fighter carrying both has bought the beginning and the end of it.
local Curve = require("models.curve")

return {
    name = "Battleborn",
    description = "Felling a foe that nothing had weakened hands your turn back, once a turn.",
    flavor = "Others soften a man first. He regards this the way a carpenter regards being handed a sawn plank.",
    sprite = "assets/items/battleborn.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    discipline = "warlord", -- deeper cut of the shelf: buyable only once the warlord gate is cleared
    price = 575,
    unlockQuests = 6,
    traits = { "trait_battleborn" },
    -- A floor for the fights where every kill is a mercy blow on something already bleeding. Damage,
    -- matching the Poacher's charm: what this bearer is short of on a quiet turn is the killing swing.
    bonus = { damage = Curve.ramp(1, 11) },
}
