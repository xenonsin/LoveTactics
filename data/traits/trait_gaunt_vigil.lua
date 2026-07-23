-- The Gaunt Vigil's objection: whenever anyone works a spell within its sight, the vigil bites them
-- for it. Hangs on Trait.onAnyCast -- the broadcast hook this trait is the reason for -- so it fires on
-- a working done BY SOMEBODY ELSE, which is a thing no other reflex in this file can see.
--
-- It answers SORCERY, not actions: Combat.isMagicItem is the gate, so a sword swing beside the vigil
-- costs nothing and a mana-priced working costs blood. That is the whole of its identity, and it is
-- why it is worth carrying against one enemy line and worthless against another.
--
-- IT DOES NOT PICK SIDES, and that is the sharpest thing about it. A vigil driven into the middle of
-- the field taxes the party's own mage exactly as hard as the enemy's. Sloth's items decide where
-- people stand and what it costs them to work there; a ward that politely exempted its owner would be
-- a damage aura wearing a ward's clothes. Place it where YOUR casters are not.
--
-- No cooldown and no cost -- an iron post has no stamina to run out of and no reflexes to pace. What
-- limits it is its own health: an enemy caster that wants to work freely has to spend a turn breaking
-- it, and that turn is the vigil's real payment, collected whether or not it survives to collect
-- anything else.
return {
    name = "Gaunt Vigil",
    description = "Bites anyone who works a spell within reach of it.",
    magnitude = 9,  -- the toll, flat and pre-mitigation
    range = 3,      -- how far the objection carries
    onAnyCast = function(ctx)
        local caster = ctx.caster
        if not (caster and caster.alive) then return end
        -- `ctx.castItem`, not ctx.item: on this hook the latter is the vigil's own kit. See the note on
        -- the shadowing in Trait.onAnyCast.
        if not require("models.combat").isMagicItem(ctx.castItem) then return end
        local dist = math.abs(caster.x - ctx.unit.x) + math.abs(caster.y - ctx.unit.y)
        if dist > (ctx.def.range or 3) then return end
        ctx.damage(caster, ctx.def.magnitude or 9, { "magical", "dark" })
        ctx.log("status", string.format("%s objects to %s's working.",
            ctx.unit.char and ctx.unit.char.name or "The vigil",
            caster.char and caster.char.name or "someone"), { ctx.unit, caster })
    end,
}
