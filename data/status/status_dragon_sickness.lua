-- DRAGON-SICKNESS: what gold does to a dwarf. Thorin's sickness under the Mountain, reviewed 2026-09-24
-- (round 3, "The Dwarves of Greed"), on Keno's round-2 note on the heaps: "have heaps collected give them
-- a buff that stacks".
--
-- Each coin heap a dwarf pockets (data/hazards/hazard_coin_heap.lua) is one stack: +2 Damage and -1
-- Defense, with no cap, for the rest of the fight -- a sick dwarf hits harder and stops watching its
-- guard, so greed blinds even before Gold Fever does. The stacks pass to the heir with Inheritance, the
-- way the gold does (data/traits/trait_inheritance.lua), so a heap left on the floor is a threat whoever
-- reaches it, and it stays one after they fall.
--
-- AND AT THREE IT MAKES A DRAGON (reviewed 2026-09-25, "Dragon-Sickness", after Fafnir). A dwarf that
-- reaches TURN_AT stacks -- pocketed or inherited, both arrive through Status.apply and so through
-- onApply below -- becomes a Gilt Wyrm (data/characters/character_gilt_wyrm.lua) for the rest of the
-- fight. It was pitched as one elite encounter and moved onto the race: every dwarf fight in the deeps
-- can grow one now, and KILL ORDER is what decides who -- Inheritance piles a fallen dwarf's stacks onto
-- its nearest kin, so the last one standing is the likeliest dragon.
--
--   * The same unit (models/transform.lua): its wounds, its statuses -- these stacks included, still
--     +2/-1 each -- its coffer and its Share all carry over. No heal on turning ("no heal": a new kit is
--     reward enough in an ordinary fight). Minted at the dwarf's own level, never the blueprint's.
--   * Permanent for the fight, and no limit on how many: the rule is the race's, not the encounter's.
--   * ENEMIES ONLY. A company body that steps on a heap banks it and never sickens (hazard_coin_heap),
--     and the check below says so outright rather than trusting that to stay true.
--   * Two things the dwarf WAS survive the swap on purpose: `boss` (the Hoard-Thane is an objective off
--     the execute table, and turning must not put him back on it) and heir-of-all (the Thane's Seal is
--     in the grid the wyrm does not wear, and his line's Shares still come to him).
local TURN_AT = 3
local SHAPE = "character_gilt_wyrm"

return {
    name = "Dragon-Sickness",
    abbr = "Sick",
    description = "Each heap of gold pocketed: increase damage, reduce defense. At 3, a dwarf becomes a Gilt Wyrm.",
    color = { 0.760, 0.560, 0.220 }, -- badge tint (tarnished gold)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 99, -- a count, not a cap
    statBonus = { damage = 2, defense = -1 },
    statBonusScales = true,
    turnAt = TURN_AT, -- read by the badge copy and by tests/dwarf_line_spec.lua
    onApply = function(ctx)
        local combat, unit, status = ctx.combat, ctx.unit, ctx.status
        if not (combat and unit and unit.alive and status) then return end
        if unit.side == "party" then return end
        if (status.magnitude or 0) < TURN_AT then return end
        local Transform = require("models.transform")
        if Transform.isTransformed(unit) then return end -- a wyrm stays a wyrm; nothing nests
        local Trait = require("models.trait")
        local heir = unit.heirOfAll or Trait.flag(unit, "heirOfAll") ~= nil
        local boss = unit.char and unit.char.boss
        local shape = Transform.apply(combat, unit, SHAPE, { level = unit.char and unit.char.level })
        if not shape then return end
        if boss then shape.boss = true end
        if heir then unit.heirOfAll = true end
        require("models.combat").logEvent(combat, "action", string.format("The gold has made a dragon of %s.",
            (Transform.originalChar(unit) or {}).name or "a dwarf"), unit)
    end,
}
