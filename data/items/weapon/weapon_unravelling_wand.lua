-- A wand, so it strikes at range and needs only a direction (docs/weapons.md) -- and its bolt is
-- `physical`, which is the deviation and the weapon. It scales off Damage, is turned by Defense, and
-- passes straight through every ward in the game. What it leaves behind is Unravelled (status_unravelled):
-- extra damage taken from every MAGICAL hit.
--
-- Quest-only: `class` with no `price`.
--
-- It is the mirror of data/items/weapon/weapon_whitening.lua and data/items/weapon/weapon_hollow_arc.lua,
-- which take melee weapons into the magical school. This takes the caster's weapon out of it, and it
-- answers the one enemy a mage genuinely cannot fight: the warded one. A magical barrier, a sealed ward,
-- a status_magic_denied, a stack of `resist magical` -- all of them make a wand useless, and all of them
-- are irrelevant here.
--
-- The setup half is what makes it more than a curiosity. The mage spends one physical bolt getting
-- through the ward, and the body on the other side is now taking MORE from every magical hit -- including
-- every other spell the Arcanum owns. It is a can-opener that hands the tin to the rest of the party.
--
-- Its cost is still mana, so a Silence still gags it: what deviates is the school of the WOUND, not of
-- the working. That line is drawn deliberately and is the same one the Whitening draws from the other
-- side.
return {
    name = "The Unravelling Wand",
    description = "A physical bolt at range that no ward can turn, leaving the target open to every spell that follows.",
    flavor = "The Arcanum spent two centuries making things that wards could not stop. This one simply is not magic.",
    sprite = "assets/items/unravelling_wand.png",
    type = "weapon",
    -- `physical` in place of the family's usual magical: the deviation, and the whole item.
    tags = { "wand", "physical", "ranged" },
    class = "mage",
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 3,
        -- Mana, like every wand: the working is still sorcery even though the wound is not, which is what
        -- keeps a Silence a real answer to it.
        cost = { stat = "mana", amount = 6 },
        -- Poor, and it must be: it is measured against Defense, which is the stat a mage's target usually
        -- has plenty of, and a caster with a good physical attack would not need the rest of its shelf.
        damage = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 8, 8 },
        effect = function(fx)
            fx.damage(fx.target) -- tags default to the item's, so the bolt is physical
            if fx.target and fx.target.alive then
                fx.applyStatus(fx.target, "status_unravelled")
            end
        end,
    },
}
