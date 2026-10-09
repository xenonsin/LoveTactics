-- HOOK AND DRAG: the Chain Fiend's trophy (data/characters/character_chain_fiend.lua; "The Crown's Bestiary",
-- slice B, approved 2026-10-09). The fiend's Drag Below handed over without the blow: a foe within 3 is pulled in
-- beside you and Rooted for 1 turn (models/crown_demons.lua's dragBelow). A Trapper's, because hauling a body onto
-- the ground you chose and holding it there is the whole of that house.
return {
    name = "Hook and Drag",
    description = "Hook a foe within 3: pull it next to you and Root it for 1 turn.",
    flavor = "Down there they use it on people. Up here it works on people just as well.",
    sprite = "assets/items/ability_hook_and_drag.png",
    type = "ability",
    tags = { "physical" },
    class = "trapper",
    unlockLevel = 15,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2, -- pointless on something already beside you
        requiresSight = true,
        speed = 3,
        cooldown = 10,
        cost = { stat = "stamina", amount = 7 },
        effect = function(fx)
            require("models.crown_demons").dragBelow(fx, fx.target)
        end,
    },
}
