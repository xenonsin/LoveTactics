-- A staff, so it swaps Wait into Focus (docs/weapons.md). Its extra is that meditating CUTS SIGILS: every
-- Focus lays hazard_graven_circle on the ground the holder is standing in, and a mage inside its own
-- circle casts and moves for less.
--
-- Quest-only: `class` with no `price`.
--
-- What it produces is a caster with a position worth defending, which the Arcanum has never had. A mage's
-- whole shape in this game is mobile and fragile -- stand anywhere, cast, step back -- and this inverts it:
-- the first Focus of a battle plants a workshop, and every turn spent inside it is worth more than the
-- same turn spent anywhere else. The party's job stops being "protect the mage" and becomes "hold this
-- square."
--
-- The circle is ground rather than a status, which is the important half: it does not travel. A mage
-- driven off it by a shove, a charge or a fire is a mage back to ordinary costs, and the enemy can read
-- exactly where the mage does not want to leave. That is the counterplay, and it is visible on the board.
--
-- On the machinery: `waitBehavior.hazard` plants rather than carries. It is deliberately NOT incense --
-- a censer's cloud is lifted and laid again wherever the bearer walks (Combat.layIncense), and that
-- lifting is precisely what separates the two families (docs/weapons.md). A staff plants and leaves it.
return {
    name = "Staff of the Graven Circle",
    description = "Replaces Wait with Focus: recover mana and cut sigils into the ground, where you cast and move for less.",
    flavor = "Every Archmage's first workshop was a floor they refused to be moved off.",
    sprite = "assets/items/graven_circle_staff.png",
    type = "weapon",
    tags = { "staff", "magical", "arcane", "melee" },
    class = "mage",
    waitBehavior = {
        kind = "focus",
        mana = { 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 },
        speed = 10,
        -- The 3x3 the mage stands in the middle of. `radius` does not scale with the forge, on the same
        -- principle a censer's does not (models/item.lua): an upgrade buys a deeper working, never a
        -- wider floor.
        hazard = { id = "hazard_graven_circle", radius = 1, duration = 20 },
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
