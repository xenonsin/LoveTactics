-- Bleed: an open wound that costs the afflicted unit blood for every step it takes. Where Burn and
-- Poison (data/status/poison.lua) tick on a clock the victim cannot stop, Bleed ticks on a clock the
-- victim CONTROLS -- it fires from `onEnterTile`, so it damages once per tile walked and not at all
-- for standing still. The dagger's signature (docs/weapons.md).
--
-- That makes it the game's one positional debuff, and a real dilemma rather than a damage number: a
-- bleeding unit must choose between its position and its health. Fleeing a melee costs the most; a
-- turn spent holding the line, bracing, or casting from where it stands costs nothing. It pairs
-- viciously with the shove weapons -- a maced target pays for two tiles it never chose to cross --
-- and a blink escapes it clean, which is exactly the premium a blink should command.
--
-- Duration is in TICKS (initiative), not turns, like every status here: it bleeds for a window of
-- the timeline, however many steps the unit crowds into it.
return {
    name = "Bleed",
    abbr = "Bld",
    description = "Bleeding: takes damage for every tile it moves through. Standing still costs nothing.",
    color = { 0.78, 0.16, 0.20 }, -- badge tint (arterial red)
    duration = 6,
    magnitude = 3, -- damage per tile entered
    debuff = true, -- removable by Cure / Panacea
    onEnterTile = function(ctx)
        -- `raw`: armor turns a blade, but it does nothing whatever about a wound already open. This is
        -- also the only way the magnitude can mean anything -- defense stats run 6-10, so a mitigated
        -- 3 would floor at 1 against every armored foe in the game and the number would be decoration.
        -- Routed through ctx.damage (Combat.dealFlatDamage), so this CAN be the blow that kills: a unit
        -- that runs on a bad wound bleeds out mid-stride.
        ctx.damage(ctx.unit, ctx.magnitude, { "bleed" }, { raw = true })
    end,
}
