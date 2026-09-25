-- DRAGON EGG: the Kobold Broodkeeper's drop. Round 2 (2026-09-25), on Keno's note on the round-1 piece:
-- "Don't really like gold being used here". The first cut was fed out of the company purse; this one is
-- brooded, exactly as the kobolds brood theirs.
--
-- LAY AN EGG (character_dragon_egg, on the caster's side). Every ally that ends its turn beside it broods
-- it, and at three it hatches a Wyrmling that fights for the company for the rest of the fight
-- (trait_clutch). A summon paid for by standing still -- the same decision the kobolds face, handed to the
-- player. The hatchling rises at the layer's own level (`hatchLevel`) and is the layer's summon, so it
-- leaves with them.
--
-- Cast as SUPPORT (the planner scores a friendly board mutation). An unstocked trophy, the beastmaster's:
-- the house that keeps a creature by the body that raised it.
return {
    name = "Dragon Egg",
    description = "Lays a dragon egg. An ally ending its turn beside it broods it; brooded three times, it hatches a Wyrmling for you.",
    flavor = "It is warm when you pick it up. It is warmer every time somebody sits down beside it.",
    sprite = "assets/items/ability_dragon_egg.png",
    type = "ability",
    tags = { "summon", "beast" },
    class = "beastmaster",
    unlockLevel = 6,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 1,
        speed = 4,
        support = true,
        cooldown = 999, -- one egg a fight
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            if fx.unitAt(fx.tx, fx.ty) then return end
            local egg = fx.summon("character_dragon_egg", fx.tx, fx.ty, { timeless = true, control = "none", noClaim = true })
            if egg and egg.alive then
                egg.layer = fx.user
                egg.hatchLevel = fx.user.char and fx.user.char.level
                -- A summon, but not one that winks out with its summoner: an egg left on the ground is an
                -- egg. The hatchling is what belongs to the layer (trait_clutch).
                egg.summoner = nil
            end
        end,
    },
}
