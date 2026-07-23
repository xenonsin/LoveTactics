-- A wand, so it strikes at range and needs only a direction (docs/weapons.md). Its extra is that it does
-- not really strike at all: the bolt turns its target into a pig (status_polymorph), which can move and
-- can do nothing else whatsoever.
--
-- Quest-only: `class` with no `price`.
--
-- The hardest single piece of control in the game, and the reason it is a quest weapon rather than a
-- shelf one. A stun shoves a body down the order and a Halt takes its abilities; this takes everything --
-- no attack, no cast, no reflex, no relic -- and leaves it walking. The enemy's champion spends the
-- duration being a pig with somewhere to be.
--
-- What keeps it honest is the same thing that keeps the Sleeper's Maul honest, and it is worth naming:
-- Polymorph is a debuff on the magical school, so a Cure ends it instantly, and a warded body resists its
-- duration. Against a warband with a priest this is a turn spent making their healer act. Against a boss
-- with no cleanse it is a fight-defining spell, which is exactly the sort of thing that should be given
-- rather than sold.
--
-- Its damage is nearly nothing on purpose. A weapon that removed a body from the fight AND hurt it would
-- have no decision in it at all.
return {
    name = "The Swineherd's Wand",
    description = "A bolt at range that turns its target into a pig: it can walk, and it can do nothing else.",
    flavor = "The Arcanum records it as a transmutation. Everyone else records it as the reason nobody argues with the Arcanum.",
    sprite = "assets/items/swineherds_wand.png",
    type = "weapon",
    tags = { "wand", "magical", "arcane", "ranged" },
    class = "mage",
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4, -- slower than a plain wand: this is a working, not a bolt
        cost = { stat = "mana", amount = 10 },
        -- The lowest curve of any wand. See the header: the transformation is the whole item.
        damage = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t)
            if t.alive then fx.applyStatus(t, "status_polymorph") end
        end,
    },
}
