-- Grants the Opportunist trait: afflict a foe with any debuff and the bearer gains Haste (on a
-- cooldown). Rewards a debuff-heavy kit -- carry it beside your poisons, marks and cripples.
return {
    name = "Opportunist's Charm",
    description = "When you afflict a foe with a debuff, you gain Hasted. Then it goes on cooldown.",
    flavor = "The Undercroft's whole philosophy: someone else's bad turn is your good one.",
    sprite = "assets/items/opportunists_charm.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    price = 245,
    unlockQuests = 2,
    traits = { "trait_opportunist" },
    -- The game's plain fortune charm, and the right item to be it: an opportunist is somebody things
    -- keep going well for, which is what Luck models -- harder to hit, and much harder to hit BADLY,
    -- since luck comes off every attacker's crit chance outright (docs/accuracy.md).
    --
    -- Greed is the house for it twice over. The Markets deal in guile and in taking what is not yours,
    -- and the rogue roster is the only one authored high in both Skill and Luck (7/7).
    bonus = { luck = 3 },
}
