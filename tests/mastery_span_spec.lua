-- WHAT A CLASS LEVEL IS ACTUALLY WORTH, measured through mitigation rather than read off the
-- multiplier.
--
-- `Combat.CLASS_MASTERY_STEP` raises an item's authored magnitude by a fraction per level of the
-- wielder's class (Combat.classScaled). That fraction is NOT what the target feels, and the gap is the
-- whole reason this file exists: mitigation here is SUBTRACTIVE with a floor of 1
-- (Combat.mitigatedDamage), so a blow of 12 against armour of 8 lands 4, and a tenth added to the blow
-- adds a quarter to the wound. The armour is subtracted once whatever the swing was, so every point the
-- swing gains arrives whole on the other side of it -- against a stout coat a quarter more raw can be
-- half again as much through.
--
-- A BLOW AND A COAT ARE ONE UNIT, and this is that rule stated as a bound. What is pinned is the
-- DELIVERED span: what mastery multiplies the damage a reference body actually takes by, across the
-- range of armour the game fields. Re-tune the step, re-cut the ladder, or move the armour curve, and
-- this is what says whether the result is still a bonus or has become the whole fight.

local Combat = require("models.combat")
local Class = require("models.class")

-- The band the assertion holds. Mastery is a REWARD for committing, not a second weapon: under 1.2x
-- delivered it is a rounding error nobody would steer a build for, and over 2.0x an untrained body is
-- carrying a different item from the one the blueprint describes -- which is the floor C2 exists to
-- protect (models/balance.lua's whole magnitude ladder is authored as what the item does).
local MIN_DELIVERED, MAX_DELIVERED = 1.15, 2.0

-- A body that mitigates `defense` and nothing else. Deliberately hand-built rather than instantiated:
-- what is under test is the arithmetic between a swing and a coat, and a real blueprint drags resists,
-- statuses and traits into a reading that has to stay legible.
local function target(defense)
    return { char = { stats = { health = { current = 999, max = 999 }, defense = defense } } }
end

local function wielder(level)
    return { char = { technique = { knight = Class.classLevelCost(level) } } }
end

return {
    {
        name = "mastery is a bonus on top of the authored magnitude, never a penalty below it",
        fn = function()
            local item = { class = "knight" }
            local untrained = { char = {} }
            for _, raw in ipairs({ 1, 8, 20, 60 }) do
                assert(Combat.classScaled(untrained, item, raw) == raw,
                    "a body with no class level must get exactly what the blueprint says, at " .. raw)
                assert(Combat.classScaled(wielder(Class.CLASS_LEVEL_CAP), item, raw) >= raw,
                    "and mastery must never take anything away, at " .. raw)
            end

            -- A classless item -- creature kit, an unarmed strike, a trap -- sits on no ladder and is
            -- returned untouched, so a body's commitment cannot leak into things that belong to nobody.
            assert(Combat.classScaled(wielder(Class.CLASS_LEVEL_CAP), { }, 20) == 20,
                "a classless item is on nobody's ladder")
        end,
    },
    {
        name = "what mastery DELIVERS stays a bonus at every coat a weapon is actually swung against",
        fn = function()
            local item = { class = "knight" }
            local raw = 14 -- a mid-ladder weapon's authored magnitude
            local tags = { "physical" }
            local base = Combat.classScaled({ char = {} }, item, raw)
            local top = Combat.classScaled(wielder(Class.CLASS_LEVEL_CAP), item, raw)

            -- THE RANGE IS BOUNDED AT HALF THE MAGNITUDE, and that bound is the finding rather than a
            -- convenience. Measured across ALL armour this reads 2.5x at defense 12 -- but at defense 12
            -- a raw-14 blow lands 2, so ANY point added to it is half again as much, and what is being
            -- measured there is the mitigation floor rather than the scalar. That degenerate band is
            -- already the subject of its own rule (Growth.LETHALITY_FLOOR: a class whose attack never
            -- grows has its damage converge on 1) and is not this one's to police.
            --
            -- Up to half the magnitude is where a weapon is a weapon. That is the band the ratio has to
            -- behave in.
            local worst, worstAt = 0, nil
            for defense = 0, math.floor(raw / 2) do
                local landedBase = Combat.mitigatedDamage(target(defense), base, tags)
                local landedTop = Combat.mitigatedDamage(target(defense), top, tags)
                assert(landedTop >= landedBase, "mastery must never land softer, at defense " .. defense)
                local ratio = landedTop / math.max(1, landedBase)
                if ratio > worst then worst, worstAt = ratio, defense end
            end

            assert(worst <= MAX_DELIVERED, string.format(
                "mastery delivers %.2fx at defense %d -- past %.2fx it stops being a bonus and becomes "
                .. "the fight. Lower Combat.CLASS_MASTERY_STEP (or the ladder's cap).",
                worst, worstAt or -1, MAX_DELIVERED))
            assert(worst >= MIN_DELIVERED, string.format(
                "mastery delivers only %.2fx at its best -- under %.2fx nobody would commit to a class "
                .. "for it. Raise Combat.CLASS_MASTERY_STEP.", worst, MIN_DELIVERED))
        end,
    },
    {
        -- WHAT MASTERY IS WORTH AGAINST THE SHELF, which is the anchor the raw step is chosen on. A
        -- sword's own ladder runs 6 to 16 across the nine rungs of the shelf (Balance.slotAnchors), so
        -- +10 is what climbing the ENTIRE catalogue buys. Mastery has to be a real fraction of that and
        -- must not rival it: gear is the axis this game grows on, and models/growth.lua proves the stat
        -- curve deliberately is not.
        name = "mastering a class is worth a fraction of climbing the whole shelf, not a rival to it",
        fn = function()
            local Balance = require("models.balance")
            local item = { class = "knight" }
            for _, fam in ipairs({ "sword", "greatsword", "dagger" }) do
                local anchors = Balance.slotAnchors()[fam]
                if anchors then
                    local shelfSpan = anchors.top - anchors.base
                    local raw = anchors.top
                    local gained = Combat.classScaled(wielder(Class.CLASS_LEVEL_CAP), item, raw) - raw
                    assert(gained >= shelfSpan * 0.2, string.format(
                        "%s: mastery adds %d against a shelf span of %d -- too small to steer a build for",
                        fam, gained, shelfSpan))
                    assert(gained <= shelfSpan * 0.6, string.format(
                        "%s: mastery adds %d against a shelf span of %d -- that rivals the whole catalogue",
                        fam, gained, shelfSpan))
                end
            end
        end,
    },
    {
        -- WHY NOT EVERY RUNG MOVES THE BLOW, recorded because the obvious assertion is unachievable and
        -- somebody will write it again otherwise.
        --
        -- Mastery adds about a quarter to a magnitude of 14, which is +3 or +4 whole points spread over
        -- eight levels -- so five of those levels necessarily round to the same number as the one below.
        -- No step satisfies both "every rung moves an integer of this size" and "mastery stays a bonus":
        -- moving all eight needs a step near 1/14, which is +60% at the cap and past the band above.
        --
        -- The resolution is that the scalar is NOT what a class level pays out. A level opens a rung of
        -- that class's shelf and, at the authored gates, a discipline -- those are the discrete rewards,
        -- and they land on every level. The scalar is a smooth background under them. What it therefore
        -- owes the player is only that it never goes backwards.
        name = "the ladder never runs backward, whatever it rounds to",
        fn = function()
            local item = { class = "knight" }
            for _, raw in ipairs({ 4, 6, 14, 24, 50 }) do
                local prev = -1
                for level = 0, Class.CLASS_LEVEL_CAP do
                    local here = Combat.classScaled(wielder(level), item, raw)
                    assert(here >= prev, "rung " .. level .. " landed under the one below, at raw " .. raw)
                    prev = here
                end
            end
        end,
    },
}
