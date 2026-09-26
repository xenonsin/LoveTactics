-- COURT OF BONE: the King's mana IS its court.
--
-- THE THIRD TIME THIS GAME ASKS "WHAT DOES IT TAKE TO PUT THIS DOWN", and each rung answers differently
-- with the same machinery:
--
--   * the common dead (character_skeleton_knight.lua) do not rise at all. The question is WHICH WEAPON.
--   * the Barrow Lord (character_barrow_lord.lua) rises on its own mana, twice. The question is WHICH
--     BAR -- it is the fight that teaches a player to stop watching the red one.
--   * the King rises on its SUBJECTS. The question is WHICH BODY, and the answer is all of them.
--
-- WHAT IT DOES, mechanically, and the reason it is this and not a bespoke revival rule: it keeps the
-- bearer's mana pinned at `per` for every living allied undead on the board, and then gets out of the
-- way. data/traits/trait_bone_knit.lua is unchanged and does the actual rising -- same trait, same
-- engine seam (Trait.trySurvive), same toll paid in mana -- so nothing here has to know what a refusal
-- to fall is. The King's pool simply stops being a resource and becomes a HEADCOUNT.
--
-- WHY THAT IS THE WHOLE DESIGN. The blue bar is already on screen, and the Barrow Lord already taught
-- the player to read it. So a court of three is ninety mana sitting in plain sight, and every subject
-- the party clears takes thirty out of it, visibly, with no badge, no tutorial and no new readout. The
-- fight explains itself in the one place the player is already looking:
--
--     EMPTY THE ROOM, THEN KILL THE KING.
--
-- RECOMPUTED ON DEATHS AND AT THE BELL, which is as tight as the hook list gets -- there is no
-- turn-start trait hook (see models/trait.lua's header), and onAnyDeath is the beat that actually
-- matters, since a court only shrinks by somebody dying. The honest consequence, stated rather than
-- hidden: between two deaths the King's pool does not refill, so a party that ignores the court
-- entirely CAN grind the King down through three whole bars instead. That is not a hole, it is the
-- expensive door -- five hundred and seventy damage against clearing three chaff bodies -- and a player
-- who finds it has still understood the fight.
--
-- Deliberately counts UNDEAD allies and not every ally. The court is its own dead; a living thing
-- fighting beside the King is an accident of composition, and a boss whose rule quietly read "any ally"
-- would be a boss that a summoner's wolf could prop up.
-- How many of the King's own dead are still standing, never counting the King itself.
local function courtSize(ctx)
    local combat = ctx.combat
    if not combat then return 0 end
    local n = 0
    for _, u in ipairs(combat.units or {}) do
        if u ~= ctx.unit and u.alive and u.side == ctx.unit.side
            -- The undead TAG, not the race: his knights kept their class and their human race when
            -- a skeleton stopped being a creature (2026-09-25), and a subject is anybody dead.
            and u.char and require("models.character").isUndead(u.char) then
            n = n + 1
        end
    end
    return n
end

-- Pin the pool to the headcount, through the sanctioned helpers rather than by writing `current`
-- directly: ctx.restore respects the bearer's effective ceiling (reservations included) and ctx.drain
-- floors at zero, so neither direction can put the pool somewhere Combat would not have.
local function settle(ctx)
    local want = courtSize(ctx) * ctx.param("per", 30)
    local pool = ctx.unit.char and ctx.unit.char.stats and ctx.unit.char.stats.mana
    local have = (pool and pool.current) or 0
    if want > have then
        ctx.restore(ctx.unit, "mana", want - have)
    elseif want < have then
        ctx.drain(ctx.unit, "mana", have - want)
    end
end

return {
    name = "Court of Bone",
    description = "This body's mana is its court: 30 for every standing subject, and nothing else.",
    -- 30 is the Barrow Crown's toll, and the two numbers are the same number on purpose -- one subject
    -- is exactly one death refused. A granter may name its own through `traitParams.per`, but it had
    -- better move the toll with it or the headcount stops being countable.
    per = 30,
    onCombatStart = function(ctx) settle(ctx) end,
    -- Any death on the board, either side: the court shrinks when the party clears one, which is the
    -- beat the whole fight is played against.
    onAnyDeath = function(ctx) settle(ctx) end,
    -- ...and the bearer's own cast, which is the other direction. The court GROWS when the King calls it
    -- (data/items/ability/ability_call_the_court.lua), and a summon arriving is not a death -- so
    -- without this the King could spend his turn refilling the room and still be killed by the next blow,
    -- because the pool would not have noticed until something else fell over. It made the boss's one
    -- important move do nothing for a turn, at exactly the moment the player is meant to be learning what
    -- that move is for.
    onCast = function(ctx) settle(ctx) end,
}
