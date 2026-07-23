-- Mirror Image: the mage half of the Ninja's Shadowclone (rogue x mage). Plants a fragile double
-- (fx.copy -- it holds position and dies to one hit) and turns the caster Invisible until its next turn:
-- the enemy strikes the image while the real body is already elsewhere. Illusion as the mage's answer to
-- "where do I stand" -- the honest answer being "not here". Modeled on utility_decoy.
return {
    name = "Mirror Image",
    description = "Plants a fragile double of you and turns you Invisible until your next turn.",
    flavor = "They will swing at the one that does not flinch. That was always going to be the wrong one.",
    sprite = "assets/items/ability_mirror_image.png",
    type = "ability",
    tags = { "illusion", "utility" },
    class = "mage",
    discipline = "ninja", -- rogue x mage; the Shadowclone mechanic's first stock
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 1,
        speed = 4,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            local double = fx.copy(fx.tx, fx.ty, { fragile = true, control = "none", decoy = true })
            if not double.alive then return end -- planted onto a trap and already gone; nothing to hide behind
            fx.applyStatus(fx.user, "status_invisible")
        end,
    },
}
