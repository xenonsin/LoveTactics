-- Wrath's rule, and the plainest example of a trait (models/trait.lua): every blow it survives makes
-- the next one it lands hurt more. Hit it harder and you sharpen it; the fight is a question about
-- whether you can finish faster than you feed it.
--
-- The bonus lives in `ctx.addBonus`, which writes to the unit's per-battle `bonus` table -- never to
-- the shared character instance -- so rage does not follow the blueprint into the next battle, nor a
-- party member back to the hub. The `wrath` status applied alongside it grants NOTHING: it exists so
-- the player can watch the badge climb. The trait is the mechanic; the status is the tell.
--
-- Ira, the Unappeased carries it (data/characters/general_wrath.lua). So does the mail lifted off her
-- body (data/items/armor/armor_mail_of_the_unappeased.lua) -- an item's `traits` reach its bearer exactly
-- the same way a character's do.
return {
    name = "Rising Wrath",
    description = "Every wound it walks away from is added to its next blow.",
    magnitude = 3, -- damage gained per hit survived
    onDamaged = function(ctx)
        local gain = ctx.def.magnitude
        ctx.trait.stacks = ctx.trait.stacks + 1
        ctx.addBonus("damage", gain)
        ctx.applyStatus(ctx.unit, "status_wrath", { magnitude = ctx.trait.stacks * gain })
    end,
}
