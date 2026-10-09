-- CAUTERISE: one of the Lernaean Hydra's three trophies, on the Crusader's shelf. Approved 2026-10-09 ("The
-- Crown's Bestiary", slice E): what Iolaus did to the necks with a torch, turned on anything that comes back.
--
-- TWO EXISTING WORDS, NO NEW ONE. It lays Burn and an Unclosing Wound -- the one word this game has for "cannot be
-- healed", which already closes a Regeneration tick and a troll's regrowth because both are heals. The third
-- promise, "or stand back up", is the Unclosing Wound's too: Combat.reanimate refuses a body under it, Envy's
-- rule for the Homunculus ("a body that cannot be healed cannot be put back together") made general. That is what
-- stops an Archon's wisp raising its body (models/spirit.lua goes through Combat.reanimate). The wound is laid at
-- two turns' length; a Cure lifts both, as it lifts any debuff.
return {
    name = "Cauterise",
    description = "Burn a foe: for 2 turns it can't be healed, regenerate, or stand back up.",
    flavor = "The trick was never the cutting. It was having somebody behind you with a torch.",
    sprite = "assets/items/ability_cauterise.png",
    type = "ability",
    tags = { "fire" },
    class = "crusader",
    unlockLevel = 15,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        speed = 4,
        requiresSight = true,
        cost = { stat = "mana", amount = 12 },
        effect = function(fx)
            local target = fx.target
            if not target then return end
            fx.applyStatus(target, "status_burn")
            fx.applyStatus(target, "status_unclosing_wound", { duration = 10 })
        end,
    },
}
