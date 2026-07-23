-- Graven Circle: the mage cuts sigils into the ground it is standing on, and while it stays inside them
-- its casts and its steps cost less of the timeline (data/hazards/hazard_graven_circle.lua ->
-- data/status/status_graven.lua). The Arcanum's answer to a pool that will not last the fight -- not
-- more mana, but the same mana spent slower.
--
-- CENTRED ON THE CASTER, AND THAT IS THE ITEM. There is nothing to aim: `target = "self"`, and the
-- circle appears under the mage's own feet. Every other zone on this shelf is thrown somewhere -- the
-- Quicksand a mage churns is churned under SOMEONE ELSE (data/items/ability/ability_quicksand.lua). This
-- is the first ground the Arcanum lays for itself, and it is worthless the moment the mage leaves it.
-- The whole cast is one sentence: agree to stand here, and everything you do costs less.
--
-- WHY IT IS PRIDE'S, past "the mage shelf owns hazard creation". The circle pays the OWNER and nobody
-- else, ally or otherwise -- a knight standing in a mage's working gets exactly nothing from it. The
-- hazard file argues this at length; the short version is that a working another body could simply walk
-- into and profit from would be a gift, and the Arcanum does not give gifts, it demonstrates.
--
-- Note what it does NOT do: no damage, no denial, no reach. The enemy AI reads the ground as friendly
-- and walks through it freely (`disposition = "friendly"`), which is deliberate -- a circle that also
-- kept foes at bay would be area denial the mage never paid for.
return {
    name = "Graven Circle",
    description = "Cuts sigils around you. While you stand within, your abilities and steps cost less time.",
    flavor = "It is not a shelter. Anyone may walk in. It simply will not do a thing for them.",
    sprite = "assets/items/ability_graven_circle.png",
    type = "ability",
    tags = { "magical", "arcane" },
    class = "mage",
    price = 320,
    repRank = 2,
    activeAbility = {
        target = "self", -- centred on the caster; there is nothing to aim
        range = 0,
        speed = 5,
        support = true,  -- it lands no damage: it reads green
        cost = { stat = "mana", amount = 10 },
        aoe = { radius = 1, shape = "square" }, -- a 3x3, so the mage has a tile or two of slack inside it
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells()) do
                -- `owner` is what makes the circle answer to one name (see the hazard's onEnter). It is
                -- the CASTER rather than a planted object, so unlike a banner there is nothing on the
                -- board to cut down -- the circle answers only to its own duration, and to the mage
                -- dying, which Hazard.dropOwnedBy handles for free.
                fx.placeHazard(c.x, c.y, "hazard_graven_circle",
                    { owner = fx.user, duration = 16 + fx.level })
            end
        end,
    },
}
