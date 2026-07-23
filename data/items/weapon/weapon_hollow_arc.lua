-- An axe, so it cleaves (docs/weapons.md) -- and the arc lands `magical`, which is the deviation and the
-- weapon. It also leaves everything it caught Hollowed (status_hollowed): physical blows barely land on
-- those bodies afterwards, and magic bites far deeper.
--
-- Quest-only: `class` with no `price`.
--
-- The two halves are one idea. An axe that only APPLIED Hollowed would be a setup weapon whose own
-- follow-up swing had been made worthless by its own debuff -- the classic shape of a trap. Because this
-- arc is magical, it is the thing Hollowed was made to reward, so the second swing into the same crowd
-- lands harder than the first. It sets itself up.
--
-- What it costs is everything a caster's weapon costs, which no other axe in the game has ever had to
-- think about: a status_magic_denied, a magical barrier or a `resist magical` shuts it down, and against
-- a heavily-warded enemy it is the worst axe on the rack. Its price is still stamina -- a fighter swings
-- it, and only the wound is sorcery.
--
-- The party consequence is worth stating plainly: Hollowed makes your OWN fighters worse against these
-- bodies. Swing this into a crowd the knight is holding and you have just made the knight's sword
-- useless. It is an axe for a party built around the Arcanum, and a liability in a line of steel.
return {
    name = "The Hollow Arc",
    description = "Cleaves a wide arc with magic, leaving everything it caught Hollowed: weak to magic, and hard for steel to touch.",
    flavor = "The edge is real. What it opens is not, particularly.",
    sprite = "assets/items/hollow_arc.png",
    type = "weapon",
    -- `magical` in place of the family's usual physical: routes through Magic Damage / Magic Defense.
    tags = { "axe", "slash", "magical", "melee" },
    class = "fighter",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 11 },
        -- Measured against Magic Defense, which the heavy infantry an axe is aimed at have bought almost
        -- none of -- so the number is modest and what arrives is not.
        damage = { 4, 5, 5, 6, 7, 7, 8, 8, 9, 10, 11 },
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u) -- tags default to the item's, so the arc is magical
                if u.alive then fx.applyStatus(u, "status_hollowed") end
            end
        end,
    },
}
