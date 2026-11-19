-- Wound Gift: the barbarian's Blood Price grid piece (docs/engines.md). An ability beside it whose
-- stamina price the body cannot meet is paid in health instead (Engine.bloodCosts, read by
-- Combat.abilityCosts so the gate, the forecast and the spend agree). Paid on your own turn, so it is a
-- self-wound, and every one banks Blood for a Sanguine Font.
--
-- The piece that builds the engine out of any shelf: whatever abilities sit next to it become things a
-- barbarian can afford by bleeding.
return {
    name = "Wound Gift",
    description = "Abilities next to it are paid in health when you lack the stamina.",
    flavor = "Given by one fighter to another, the night before the second one's first bout.",
    sprite = "assets/items/utility_wound_gift.png",
    type = "utility",
    tags = { "trinket" },
    class = "barbarian",
    unlockLevel = 4,
    aura = {
        appliesTo = { "ability" },
        bloodPay = true,
    },
    bonus = { defense = 1 },
}
