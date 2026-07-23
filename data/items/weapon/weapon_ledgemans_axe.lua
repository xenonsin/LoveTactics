-- An axe, so it cleaves (docs/weapons.md). Its extra is that the arc does not land evenly: the two OUTER
-- tiles are driven back two paces and the centre tile is not moved at all. One swing splits a rank of
-- three into a lone body with a gap on either side of it.
--
-- Quest-only: `class` with no `price`.
--
-- What it sells is isolation, which is a thing no other weapon in this game produces. Every other way of
-- separating an enemy line moves ONE body (a mace's shove, a pull, a blink), so the line closes up again
-- next turn. This moves the line and leaves the man you actually want exactly where he was -- which is
-- to say it manufactures, in one swing, the single-target duel that the rogue's whole shelf and the
-- greatsword's whole design are priced around.
--
-- Note it is the tiles that decide, not the sides: your own knight standing at the edge of the arc gets
-- thrown two paces exactly as readily. Aim it along the enemy rank, not across a melee.
return {
    name = "Ledgeman's Axe",
    description = "Cleaves a wide arc, hurling the outer two tiles back and leaving the centre standing alone.",
    flavor = "A ledgeman is paid to take one tree out of a stand without touching its neighbours. This does the opposite, and is paid better.",
    sprite = "assets/items/ledgemans_axe.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    class = "fighter",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 11 },
        damage = { 4, 5, 5, 6, 6, 7, 8, 8, 9, 9, 10 },
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                -- The centre of the arc is the AIMED cell, which is how a `front` footprint is built
                -- (docs/weapons.md): everything else in it is an outer tile by construction, so the
                -- split needs no geometry of its own.
                local centre = (u.x == fx.tx and u.y == fx.ty)
                if centre then
                    fx.damage(u)
                else
                    -- The shove rides IN the blow rather than following it, so a body the swing kills is
                    -- still thrown before it drops -- the same rule the Iron Mace's header sets out.
                    fx.damage(u, { knockback = { distance = 2, amount = fx.amount } })
                end
            end
        end,
    },
}
