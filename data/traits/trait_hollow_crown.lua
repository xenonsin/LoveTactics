-- The Demon Lord's rule. It has no sin of its own -- the seven were its appetites -- and so it has no
-- fight of its own either. As it is worn down it reaches for a name and puts it on.
--
-- Mechanically this is the same `onDamaged` hook Wrath's general uses (data/traits/wrath_rising.lua),
-- pointed at health thresholds instead of a damage counter. One engine feature, two bosses. Because
-- onDamaged fires only on a SURVIVOR (see Combat.dealFlatDamage), a blow that kills the Crown outright
-- never summons the shade it was owed -- which is the correct reading: burst it down and it never gets
-- to wear anything.
--
-- WHOSE NAME IT REACHES FOR IS THE CROWN'S OWN DEAD -- `shades` below, the generals the player already
-- put down, in the order it wants them.
--
-- IT USED TO BE A CHOICE, and the history is worth keeping because the mechanism it left behind is
-- still here. models/temptation.lua asked the player, once per quest for ten quests, whether they would
-- take the Crown's offer; a line whose companion CAVED ended with her wearing her dead general's relic
-- and still at the player's shoulder, and this hook reached past its own corpses for her. That model is
-- cut, so the list is the generals and nothing else -- but `ctx.defect` below is untouched, because
-- turning a body that is already deployed is the right move for ANY name on this list that happens to
-- be standing there, and it costs nothing to leave working.
--
-- So there are still two ways a name arrives:
--
--   * it is DEPLOYED -- `ctx.defect` re-bodies it where it stands and moves it onto the Crown's side
--     (models/trait.lua). No second copy: summoning a duplicate of something that is right there would
--     read as a bug rather than a betrayal.
--   * it is not on the board -- so it comes through the Gate as an ordinary summon.
--
-- A defector is NOT a summon, so it does not vanish with the Crown. Harmless: the objective is
-- `assassinate`, so the fight ends on the Crown whoever else is still standing. The generals it
-- summons still go with it, which is what keeps that objective honest.

-- The Crown's own dead, in the order it reaches for them when the player has given it nobody better.
-- All seven generals are authored, so any of them could stand here; this curated trio is a deliberate
-- choice, not a limit of what exists -- three thresholds fire (75/50/25%), so only three names are ever
-- worn, and these are the three whose return argues the hardest.
--
-- Sloth second is deliberate. The Crown wearing Acedia at half health is her own thesis argued by the
-- board: you already killed her, and here she is, and nothing you did stuck. That is the argument the
-- whole middle act is a rebuttal to (docs/story.md). Pride third is its own argument: the Unequalled
-- put back on at a quarter health, certain to the last she has your measure.
local GENERALS = { "character_general_wrath", "character_general_sloth", "character_general_pride" }

-- The unit on the board wearing `charId`, or nil. Walks combat.units rather than asking the player's
-- roster, because what matters here is who was DEPLOYED -- a caved companion left on the bench is a
-- body the Crown has to bring through the Gate itself.
local function fieldedAs(ctx, charId)
    for _, u in ipairs((ctx.combat and ctx.combat.units) or {}) do
        if u.alive and u.char and u.char.id == charId then return u end
    end
    return nil
end

return {
    name = "The Hollow Crown",
    description = "As it fails, it wears the dead.",
    -- Fractions of max health. Each one crossed calls up the next name.
    thresholds = { 0.75, 0.50, 0.25 },
    shades = GENERALS,
    onDamaged = function(ctx)
        local hp = ctx.unit.char.stats.health
        local fraction = hp.current / hp.max

        -- Read off the blueprint rather than cached on the trait, so this file stays the only place the
        -- Crown's casting is decided and an arena that authors its own `shades` is honoured.
        local names = ctx.def.shades or GENERALS

        -- A single enormous blow can cross two thresholds at once, and should call up both.
        while ctx.trait.stacks < #ctx.def.thresholds
            and fraction <= ctx.def.thresholds[ctx.trait.stacks + 1] do
            ctx.trait.stacks = ctx.trait.stacks + 1

            local shade = names[ctx.trait.stacks]
            if shade then
                -- Is the body this name belongs to standing right there? Turn it where it stands.
                --
                -- It used to match a `_caved` suffix, because the only name that could be on the board
                -- already was a companion the player had spoiled (models/temptation.lua, cut). The id is
                -- compared directly now, which is the same rule with the special case taken out: a shade
                -- already deployed defects, whoever authored it onto the list.
                local standing = fieldedAs(ctx, shade)
                if standing and ctx.defect(standing, shade) then
                    ctx.log("system", "The Crown remembers another name.")
                else
                    local x, y = ctx.openTileNear(ctx.unit.x, ctx.unit.y)
                    if x then
                        ctx.log("system", "The Crown remembers another name.")
                        ctx.summon(shade, x, y)
                    end
                end
            end
        end
    end,
}
