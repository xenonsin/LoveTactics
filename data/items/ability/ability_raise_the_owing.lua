-- RAISE THE OWING: a corpse gets up as a skeleton OF ITSELF -- its own body, its own kit, Bare Bones and
-- Grave-Cold -- on your side, at half its bar. The skeleton rule (a skeleton is the body you knew, with what
-- happened to it) made into a spell, beside Raise Dead's generic zombie. A raised bear is a bone bear; a
-- raised mage is a bone mage. Sustained by the caster, reserving a quarter of the pool.
return {
    name = "Raise the Owing",
    description = "Raises a corpse as a skeleton of itself on your side. Reserves a quarter of your max mana.",
    flavor = "It owed him a life. He is being generous: he only asked for what was left.",
    sprite = "assets/items/ability_raise_the_owing.png",
    type = "ability",
    tags = { "dark", "summon" },
    class = "necromancer",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 6,
        support = true,
        reserve = { stat = "mana", percent = 0.25 },
        effect = function(fx)
            local corpse = fx.corpseAt(fx.tx, fx.ty)
            if not corpse then return end
            local x, y = corpse.x, corpse.y
            if fx.consumeCorpse(corpse) then
                fx.copyOf(corpse, x, y, { bones = true, health = 0.5 })
            end
        end,
    },
}
