-- Corroding: the acid is in your kit, and it is still working.
--
-- The one status in the game that spends something the fight does not own. Everything else here costs
-- health, a turn, or a stat for a while; this eats DURABILITY (models/item.lua's Item.wear), which is
-- the resource the forge answers and the battle cannot give back. So it is the slimes' real threat --
-- a body that cannot be cut and does not need to kill you to cost you something
-- (data/items/ability/ability_corrosive_touch.lua).
--
-- IT NEVER DESTROYS ANYTHING, and that is Item.wear's own law rather than a courtesy: "a broken piece
-- is not destroyed -- it is left in the grid, at zero, useless until the forge mends it or the player
-- scraps it. Deleting gear out from under a player at the end of a fight, with no screen and no line,
-- is the one thing this system must never do." A corroded sword is a sword you walk home with and pay
-- to mend. It is never a sword that is gone.
--
-- FOUR WAYS OUT, and they are the whole reason this is allowed to exist:
--   * it has to REACH you -- the cast is range 1 on a body that moves 3 and acts at speed 3;
--   * it is TELEGRAPHED -- a windup the player gets a turn to answer with a stun, a shove or a step;
--   * it is a DEBUFF, so Cure and Panacea strip it, and every turn it is stripped early is wear that
--     never happens. That is the active answer, and it is the one this status is tuned around;
--   * and the forge mends what it did -- IN TOWN, which is the half that makes the wear a real cost
--     rather than a chore. Forge.mend has exactly one caller (ui/panels/forge.lua, a room on the
--     Bastion's desk), so a corroded blade cannot be answered underground: you finish the trip with
--     it, or you go home. tests/durability_spec.lua pins that the call site stays the only one.
--
-- ONE PIECE PER TURN, THE HEALTHIEST ONE. Spreading the bite across the whole grid would eat more in
-- three turns than a weapon has in it, and eating the most-worn piece first would quietly be a
-- destroy-the-weakest rule. Taking the piece with the most left in it is the reading the fiction
-- wants -- acid works on whatever it can find -- it is deterministic (grid order, ties to the first),
-- and it is self-limiting: the damage is spread over the kit rather than concentrated until something
-- breaks.
--
-- A BODY PART CANNOT CORRODE. Item.durabilityMax is nil for anything `noSteal` or `bound`, so a wolf's
-- fangs and a boss's phase relic are untouched without this file naming either -- which also means a
-- slime cannot corrode another slime, and a party fighting bare-handed loses nothing at all.
return {
    name = "Corroding",
    abbr = "Cor",
    description = "Corroding: a piece of the bearer's kit wears each turn.",
    color = { 0.565, 0.689, 0.223 }, -- badge tint (acid's own caustic yellow-green, shared with Acid)
    fx = { field = true },   -- draws ground under the afflicted body (a debuff: the hostile look)
    duration = 15,           -- ~3 turns at Status.TICKS_PER_TURN
    debuff = true,           -- removable by Cure / Panacea, which is the answer it is tuned around
    magnitude = 4,           -- points of durability a turn: ~12 uncured, against a weapon's 30
    onTick = function(ctx)
        -- Whole points only, banked across the clock (ctx.accrue): a rebase can elapse a fraction of a
        -- tick, and spending `magnitude * elapsed` directly would round every sliver up to a whole
        -- point and eat the kit far faster than the number above claims.
        local bite = ctx.accrue(ctx.status.magnitude or 4)
        if bite <= 0 then return end

        local Character = require("models.character")
        local Item = require("models.item")
        local unit = ctx.unit
        if not (unit and unit.alive and unit.char) then return end

        -- The piece with the most left in it, in grid order so a tie always falls the same way and a
        -- seeded fight replays identically.
        local worst, left = nil, -1
        for _, item in ipairs(Character.eachItem(unit.char) or {}) do
            local max = Item.durabilityMax(item)
            if max and (item.durability or max) > 0 and (item.durability or max) > left then
                worst, left = item, item.durability or max
            end
        end
        if not worst then return end -- bare hands, or a kit already eaten through

        local broke = Item.wear(worst, bite)
        local who = (unit.char.name) or "Unit"
        if broke then
            -- Said loudly and by name. A piece going dead in the middle of a fight is the single most
            -- consequential thing this status does, and the player must never learn it from a greyed
            -- slot they notice two turns later.
            ctx.log("status", string.format("%s's %s gives way.", who, worst.name or "gear"), unit)
        else
            ctx.log("status", string.format("The acid eats into %s's %s.", who, worst.name or "gear"), unit)
        end
    end,
}
