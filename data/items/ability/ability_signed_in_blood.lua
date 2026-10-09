-- SIGNED IN BLOOD: the Pit Imp's trophy (data/characters/character_pit_imp.lua; "The Crown's Bestiary", slice B,
-- approved 2026-10-09). The imp's Offer pointed at your own side: an ally is Signed into Blood Debt (data/status/
-- status_blood_debt.lua) -- +5 damage for 2 turns, and a third of what it deals meanwhile charged back when it
-- runs out. A Warlord's, because spending somebody else's blood on the push is what that house does.
return {
    name = "Signed in Blood",
    description = "Sign an ally: +5 damage for 2 turns. When it ends, they take a third of the damage they dealt.",
    flavor = "The terms are fair. They are printed very small, and in a colour that is hard to read later.",
    sprite = "assets/items/ability_signed_in_blood.png",
    type = "ability",
    tags = { "command" },
    class = "warlord",
    unlockLevel = 15,
    unstocked = true,
    activeAbility = {
        target = "ally", -- includes the caster: a warlord may sign for itself
        range = 3,
        speed = 3,
        support = true,
        cooldown = 15,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            if fx.target then fx.applyStatus(fx.target, "status_blood_debt") end
        end,
    },
}
