-- The Demon Lord's rule. It has no sin of its own -- the seven were its appetites -- and so it has no
-- fight of its own either. As it is worn down it reaches for a name and puts it on.
--
-- Mechanically this is the same `onDamaged` hook Wrath's general uses (data/traits/wrath_rising.lua),
-- pointed at health thresholds instead of a damage counter. One engine feature, two bosses. Because
-- onDamaged fires only on a SURVIVOR (see Combat.dealFlatDamage), a blow that kills the Crown outright
-- never summons the shade it was owed -- which is the correct reading: burst it down and it never gets
-- to wear anything.
--
-- WHOSE NAME IT REACHES FOR IS NOT FIXED ANY MORE, and that is the point of the whole campaign now.
-- `shades` below is the FALLBACK -- the Crown's own dead, the generals the player already put down --
-- and models/temptation.lua puts anyone the player spoiled in front of them. Every class line asks the
-- player ten times whether they will take the Crown's offer; a line whose companion CAVED ends with
-- her wearing the dead general's relic and still fighting at the player's shoulder, and this is where
-- that bill comes due. The Crown reaches past its own corpses for the woman standing on your side of
-- the board.
--
-- Which is also why there are two ways a name arrives:
--
--   * she is DEPLOYED -- `ctx.defect` re-bodies her where she stands and moves her onto the Crown's
--     side (models/trait.lua). No second copy: summoning a duplicate of a woman who is right there
--     would read as a bug rather than a betrayal.
--   * she was left at home -- there is nothing on the board to turn, so she comes through the Gate as
--     an ordinary summon, exactly as a general does.
--
-- A defector is NOT a summon, so it does not vanish with the Crown. Harmless: the objective is
-- `assassinate`, so the fight ends on the Crown whoever else is still standing. The generals it
-- summons still go with it, which is what keeps that objective honest.
-- models/temptation.lua and models/player.lua are required INSIDE the hook, never at the top of this
-- file. data/traits/ is swept by the registry from models/trait.lua's own require, so a blueprint that
-- reaches for a model at load time can close a cycle through whatever that model pulls in -- and the
-- failure lands as a nil index in an unrelated file. Every other model-touching data file in the tree
-- takes the same lazy shape for the same reason.

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

        -- Resolved once per firing rather than cached on the trait: the list is a function of the save,
        -- and reading it here keeps this file the only place the Crown's casting is decided. A battle
        -- with no live player behind it (a spec fixture, the duel debug screen) falls back to the
        -- generals, which is the behaviour this trait had before the ledger existed.
        local Temptation = require("models.temptation")
        local names = Temptation.shades(require("models.player").active,
            ctx.def.shades or GENERALS, #ctx.def.thresholds)

        -- A single enormous blow can cross two thresholds at once, and should call up both.
        while ctx.trait.stacks < #ctx.def.thresholds
            and fraction <= ctx.def.thresholds[ctx.trait.stacks + 1] do
            ctx.trait.stacks = ctx.trait.stacks + 1

            local shade = names[ctx.trait.stacks]
            if shade then
                -- Was this name earned off a companion who is standing right there? Turn her where she
                -- stands. Temptation.cavedId is the convention both ends of this agree on.
                local companion = shade:match("^(.*)_caved$")
                local standing = companion and fieldedAs(ctx, companion)
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
