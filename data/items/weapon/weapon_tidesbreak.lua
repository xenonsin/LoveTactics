-- A spear, so it skewers a line (docs/weapons.md). Two extras, and they are one idea: the thrust lands
-- `water`-tagged and leaves both tiles Wet (status_wet), and the same sweep drives the whole line one
-- tile back while the wielder steps forward into the space it made.
--
-- Quest-only: `class` with no `price`.
--
-- It is the only weapon in the game that ADVANCES its bearer. Every other displacement effect here moves
-- somebody else -- a mace shoves, a pull drags, a blink relocates the caster without touching the board.
-- This moves the enemy line back and the spearman up, which is how a shield wall actually takes ground,
-- and it means the weapon's own reach is preserved across the advance rather than spent on it.
--
-- The `water` tag pays somebody else. Nothing in this game is vulnerable to water itself -- what Wet does
-- is +6 from lightning and ice and -6 against fire (data/status/status_wet.lua). So this spear does not
-- combo with itself at all; it soaks a rank and hands them to the Arcanum. Read it beside
-- data/items/weapon/weapon_wetstone_mace.lua, which soaks and then shocks on its own, and
-- data/items/weapon/weapon_conductor.lua, which does no soaking and only ever harvests it: three weapons,
-- three shelves, one chain.
--
-- The fire resistance it hands the enemy is real and is the cost. Soaking a rank in front of your own
-- fire mage is a way to turn their turn off.
return {
    name = "Tidesbreak",
    description = "Skewers and soaks the two tiles ahead, driving them back a pace as you step into it.",
    flavor = "The tide does not push. It arrives, and afterwards the beach is somewhere else.",
    sprite = "assets/items/tidesbreak.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "water", "melee" },
    hands = 2,
    class = "knight",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = { 4, 4, 5, 5, 6, 7, 7, 8, 8, 9, 10 },
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                -- The shove rides IN the blow, so a body the thrust kills is still thrown before it
                -- drops (the rule the Iron Mace's header sets out). One tile only: this is a wall
                -- taking ground, not a mace clearing a room.
                fx.damage(u, { knockback = { distance = 1, amount = 0 } })
                if u.alive then fx.applyStatus(u, "status_wet") end
            end
            -- ...and the wielder follows into the vacated cell, if the line actually cleared it. Checked
            -- rather than assumed: a rank pinned against a wall does not move, and the spearman must not
            -- walk into an occupied tile.
            if not fx.unitAt(fx.tx, fx.ty) then
                fx.teleportUser(fx.tx, fx.ty)
            end
        end,
    },
}
