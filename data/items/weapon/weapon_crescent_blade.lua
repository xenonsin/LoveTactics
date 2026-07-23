-- The first blade that cuts with something other than its edge. A sword by family (docs/weapons.md):
-- one-handed, and it parries like every sword does. What it buys with its price is where the cut
-- LANDS -- the swing releases a crescent of force that runs three tiles down the line it was aimed
-- along, so the blade never has to reach what it kills.
--
-- Its extra over `weapon_iron_sword`, which is what a named weapon owes:
--
--   * The arc carries. A sword answers the one foe in front of it; this one opens a lane through
--     three, which makes a corridor its best ground and an open field its worst.
--   * The cut is MAGICAL, so it is routed through Magic Damage and the target's Magic DEFENSE. A
--     column of infantry that turns an iron sword aside all day has nothing between it and this.
--
-- And it is paid for out of BOTH pools -- see the cost below, which is the point of the weapon.
--
-- Two deliberate deviations, per docs/weapons.md's "say so in a comment":
--
--   1. `target = "tile"`, where every other sword aims a unit. A released arc needs a DIRECTION
--      rather than a victim, exactly as weapon_iron_spear's thrust does, so the aimed tile sets the
--      line the crescent travels. `allowOccupied` because the foe in your face is the usual first
--      tile of that line, not an obstacle to it.
--   2. It still parries, and the parry is a single answering blow rather than another crescent --
--      Trait's counter path swings the weapon at the one attacker (Combat.dealDamage), and does not
--      broadcast an aoe. That is correct rather than a shortcut: a reflex is a blade going up in
--      time, not a working released on purpose. It is priced as a swing all the same, which is to
--      say in mana AND stamina (Trait.answerCost) -- a crescent blade guards a doorway expensively.
return {
    name = "Crescent Blade",
    description = "Looses a crescent of force three tiles down the line you aim it, cutting through armor rather than at it.",
    flavor = "The Bastion's smiths tempered it in something they will not name. It has never needed sharpening, and it has never been lent out.",
    sprite = "assets/items/crescent_blade.png",
    type = "weapon",
    -- `magical` is the school (routes damage through Magic Damage / Magic Defense) and `slash` the
    -- hit tag armor `resist` reads; `sword` is the family and `melee` the reach. All four are peers --
    -- position is never read (Item.archetype finds the family by membership).
    tags = { "sword", "slash", "magical", "melee" },
    hands = 1, -- one-handed, like every sword: the free hand is half of what the family is
    traits = { "trait_parry" }, -- swords answer a melee blow (docs/weapons.md)
    class = "knight", -- a sword, so the Bastion's shelf -- the same rule that puts weapon_demon_bane there
    price = 260,
    repRank = 4, -- above Demon Bane's 3; rank 4 is the vendor ceiling (data/vendors/)
    activeAbility = {
        target = "tile",      -- a direction, not a victim: the aimed tile sets the line the arc runs
        allowOccupied = true, -- the first tile may hold a foe; the crescent starts there and carries on
        range = 1,
        minRange = 1,         -- must pick a neighbor (a facing); never the wielder's own tile
        speed = 4,            -- a beat slower than an iron sword's 3: the arc has to be drawn before it is thrown
        -- BOTH pools, every swing. The mana is the crescent and the stamina is the arm that throws
        -- it, and neither half is optional -- a silenced bearer cannot swing this at all (the mana in
        -- the price makes it sorcery: Combat.isMagicItem, and the silence gate beside it), and an
        -- exhausted one cannot either. That is the weapon's real cost: it draws on the pool a knight
        -- has plenty of AND the pool a knight has none of, so carrying it is a build decision rather
        -- than an upgrade. See Item.costs for the shape.
        cost = {
            { stat = "mana", amount = 4 },
            { stat = "stamina", amount = 6 },
        },
        -- Per-target power (levels 0..10), deliberately under weapon_iron_sword's 6..16: it can catch
        -- three bodies where a sword catches one, and it declines armor on top of that. Tuned nearer
        -- weapon_iron_spear's 2-tile line, a step lower again for the extra tile and the routing.
        --        level:  0  1  2  3  4  5  6  7   8   9  10
        damage = { 5, 5, 6, 7, 7, 8, 9, 9, 10, 11, 12 },
        aoe = { shape = "line", length = 3 }, -- three tiles in a straight line away from the wielder
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
