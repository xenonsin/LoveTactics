-- An axe, so it cleaves (docs/weapons.md): a 3-wide arc perpendicular to the aimed tile. Its extra is
-- that the arc is BILLED -- every body it opens pays the company coin (Combat.bounty, reached through
-- fx.bounty), so a swing through three is a swing through three purses.
--
-- The entry-rank alternative to the Butcher's Wedge, and the axe that makes the family's own pitch in
-- money instead of damage. An axe is already the weapon you carry when there is more than one thing in
-- front of you; this one means the crowd you were going to have to fight anyway is also the payroll.
--
-- Deliberately the WEAKEST axe on the shelf per target. The coin has to be the reason, or it is simply a
-- better hatchet -- and a fighter who wants the crowd dead faster already has the Wedge for that.
return {
    name = "Tithe-Axe",
    description = "Cleaves a wide arc. Every foe it opens pays the company coin.",
    flavor = "The Colosseum's quartermasters do not call it looting. They call it the tithe, and they take theirs first.",
    sprite = "assets/items/tithe_axe.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    class = "fighter",
    price = 210,
    repRank = 2,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        -- Under the iron axe's, which is already under a sword's. The tithe is the rest of the weapon.
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 },
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                -- Coin only for a body that was actually opened, and only for the enemy's: cleaving
                -- through your own line is already a mistake and should not also be a payday.
                local dealt = fx.damage(u)
                if dealt > 0 and u.side ~= fx.user.side then
                    fx.bounty(6 + 2 * fx.level) -- scales with the forge, as a sharper axe bills more
                end
            end
        end,
    },
}
