-- The balance contract, swept over every blueprint. docs/balance.md states these rules in prose;
-- this is the copy that fails the build.
--
-- Written in the shape of tests/weapon_spec.lua and tests/class_spec.lua: the contract lives HERE, in
-- the spec, and is checked against the whole catalogue rather than against a handful of chosen
-- examples. A rule that only holds for the items someone remembered to list is not a rule.
--
-- WHY THIS EXISTS. Combat has one damage formula and it is purely subtractive, so weapon power and
-- body armour are quantities in the same unit -- and for most of this project's life nothing measured
-- them against each other. They drifted about 2x apart: a level-1 avatar swung 18 into 27 points of
-- mitigation and dealt the floor of 1, and the campaign's second line opened with an Easy quest
-- fielding a body that strictly dominated the protagonist. Every case below is one sentence of the
-- reason that was possible.
--
-- WAIVERS ARE AUTHORED HERE, WITH THE REASON, and never as a field on a blueprint. A per-blueprint
-- opt-out is a flag an author sets to make a failure go away; a line in this table is a line someone
-- has to write a sentence next to, in a file reviewers read.

local Balance = require("models.balance")
local Character = require("models.character")
local Quest = require("models.quest")
local Item = require("models.item")
local Vendor = require("models.vendor")
local Class = require("models.class")
local Forge = require("models.forge")
local Errand = require("models.errand") -- the rungs a house really asks for; see the forge-ceiling case

-- id -> why this body is exempt from EVERY rule below.
--
-- Bodies in Balance.FROZEN are waived automatically: a body no automated pass may TOUCH cannot
-- sensibly be held to a band it is not allowed to be moved into. That set lives in models/balance.lua
-- rather than here because the rescale tool needs it too and cannot require a spec.
local WAIVERS = {}
for id, reason in pairs(Balance.FROZEN) do WAIVERS[id] = reason end

-- id -> why this body is allowed to be harmless, exempt from the mirror rule ONLY.
--
-- Every entry is a conjured construct whose blueprint states in prose that its low damage is the
-- design, and each reason below is that blueprint's own words. They are named here rather than caught
-- by a rule because Balance.isNonCombatant covers only bodies that declare themselves -- no offensive
-- statline, or a support posture -- and these carry real weapons and a real `guard` posture. "This one
-- is deliberately feeble" is a claim that should cost somebody a sentence.
--
-- They are NOT exempt from the other rules: a wall still has to be killable inside its band, and still
-- may not outclass the protagonist.
-- id -> why this body is allowed outside its time-to-kill band, exempt from that rule ONLY.
--
-- Still checked for everything else: it may not wall every melee weapon, may not outclass the
-- protagonist, and must be able to hurt back.
local TTK_WAIVED = {
    -- Nine swings against an elite band of 4-8, on a Hard capstone that costs a crossing of two
    -- lines to reach. Her mitigation is two armours -- the tower shield she deserted with and the
    -- Warden's Oath that is her signature -- each individually inside Balance.ARMOR_SHARE and each
    -- load-bearing for what the character IS. `balance-rescale` flagged her over-armoured and
    -- correctly refused to fix it by cutting a tier-3 body through the health floor of its own rung.
    -- One hit over, on the deepest fight in the line, is the right place to spend that.
    character_forsworn_captain = "over-armoured by design: two signature coats, one hit over, on a cross-line capstone",
}

-- Moved to models/balance.lua so tools/balance_rescale.lua reads the same list: while it lived here,
-- the rescale's mirror pass could not see it and proposed arming every body on it.
local HARMLESS_BY_DESIGN = Balance.HARMLESS_BY_DESIGN

-- Vendors whose shelf cadence is checked. Derived, so a new house is covered the day it lands.
local function houses()
    local list = {}
    for _, v in ipairs(Vendor.list()) do list[#list + 1] = v.id end
    table.sort(list)
    return list
end

-- ---------------------------------------------------------------------------
-- The sweep, built once and shared. Measuring 100-odd bodies against four probes apiece is not free,
-- and every case below asks a different question of the same measurements.
-- ---------------------------------------------------------------------------

-- ONE ROW PER BODY, at the EARLIEST standing it is met at.
--
-- A body reused across the campaign is one authoring decision, and the binding case is its
-- introduction: that is where the player has the least to answer it with, and fixing it there fixes
-- every later appearance. Measuring each reappearance separately reports the same blueprint a dozen
-- times and, worse, reports it as "too fast" at high prestige -- which is not a defect but the
-- documented purpose of Growth.ENEMY_LEVEL_LAG. The company is meant to pull ahead of common stock;
-- an old enemy becoming a victory lap is the system working, and a band that fought it would be
-- arguing with models/growth.lua.
local sweepCache
local function sweep()
    if sweepCache then return sweepCache end
    local byId = {}
    for _, questId in ipairs(Balance.questOrder()) do
        local def = Quest.defs[questId]
        local prestige = Balance.prestigeFor(questId)
        local sponsorDone = Balance.sponsorDoneFor(questId)
        for _, body in ipairs(Balance.bodiesFor(questId)) do
            local cur = byId[body.id]
            -- Companions are excluded: several are fought once before they join, but their statlines
            -- are the PLAYER's and are judged by whether they are fun to field, not by how they read
            -- as an opponent. Placeholders (transform shapes) have no real statline to judge.
            if not WAIVERS[body.id]
                and not Balance.isPlaceholder(body.id)
                and not Balance.isCompanion(body.id)
                and (not cur or prestige < cur.prestige) then
                local row = Balance.measure(prestige, body.id, body.role, { sponsorDone = sponsorDone })
                row.quest = questId
                row.difficulty = def.difficulty
                byId[body.id] = row
            end
        end
    end

    local rows = {}
    for _, row in pairs(byId) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b)
        if a.prestige ~= b.prestige then return a.prestige < b.prestige end
        return a.id < b.id
    end)
    sweepCache = rows
    return rows
end

-- "p2 character_grey_knight (quest_bastion_slot_01, Easy)" -- every failure message names the body,
-- where it is met and at what standing, because the fix is always in one of those two files.
local function where(row)
    return string.format("p%d %s (%s, %s)",
        row.prestige, row.id, row.quest, tostring(row.difficulty))
end

return {
    {
        name = "no body walls every melee weapon in the game",
        fn = function()
            local bad = {}
            for _, row in ipairs(sweep()) do
                if row.ex.out.floored then
                    bad[#bad + 1] = string.format("%s -- best of sword/spear/mace is %s at %d/hit (%s hits), mitigation %d vs budget %d",
                        where(row), row.physical, row.ex.out.perHit,
                        tostring(row.ex.out.hits), row.ex.out.mitigation, row.ex.out.budget)
                end
            end
            assert(#bad == 0, "these bodies floor the damage of every melee weapon the player can hold, so a\n"
                .. "melee company cannot hurt them at all:\n  " .. table.concat(bad, "\n  "))
        end,
    },
    {
        name = "no body dominates the reference loadout outright",
        fn = function()
            local bad = {}
            for _, row in ipairs(sweep()) do
                if row.dominates then
                    local ref = row.ex.reference
                    bad[#bad + 1] = string.format("%s -- %d atk / %d mit / %d hp beats the reference's %d / %d / %d on every axis",
                        where(row), row.ex.back.budget, row.ex.out.mitigation, row.ex.out.hp,
                        ref.budget, ref.mitigation, ref.hp)
                end
            end
            assert(#bad == 0, "a body that out-attacks AND out-armours AND out-lives the protagonist is not a hard\n"
                .. "fight, it is a better version of the player, and no damage-formula change repairs one:\n  "
                .. table.concat(bad, "\n  "))
        end,
    },
    {
        name = "every body fells the player inside the band for its rank",
        fn = function()
            -- Objects, walls and support units are exempt: Balance.isNonCombatant reads the two ways a
            -- blueprint declares "this does not attack", and HARMLESS_BY_DESIGN names the constructs
            -- whose prose says the same thing in a way no rule can see.
            --
            -- THIS USED TO ASK ONLY `back.floored` -- a boolean, "did it land exactly on the damage
            -- floor" -- while the outgoing direction next door was held to a hits-to-kill band. A wolf
            -- getting through for three points and needing twenty-one bites answered "no, not floored"
            -- and passed, so the suite was green over a bestiary half of which could not kill anybody.
            -- A band on one side and a yes/no on the other is one rule and one blind spot.
            local bad = {}
            for _, row in ipairs(sweep()) do
                local band = Balance.TTK_BACK[row.role or "line"] or Balance.TTK_BACK.line
                if (row.ex.back.floored or row.ex.back.hits > band.max)
                    and not Balance.isNonCombatant(row.id)
                    and not HARMLESS_BY_DESIGN[row.id] then
                    bad[#bad + 1] = string.format("%s -- swings %d, deals %d/hit, %s hits to fell the avatar (band is %d-%d)",
                        where(row), row.ex.back.budget, row.ex.back.perHit, tostring(row.ex.back.hits),
                        band.min, band.max)
                end
            end
            assert(#bad == 0, "these bodies cannot fell the reference loadout inside the band their rank is held\n"
                .. "to (Balance.TTK_BACK) -- the mirror of the rule above, and the failure a one-sided\n"
                .. "rescale creates:\n  "
                .. table.concat(bad, "\n  "))
        end,
    },
    {
        name = "time-to-kill lands inside the band for the body's role",
        fn = function()
            local bad = {}
            for _, row in ipairs(sweep()) do
                local v = row.verdict
                if (v == "too slow" or v == "too fast") and not TTK_WAIVED[row.id] then
                    local band = Balance.TTK[row.role]
                    bad[#bad + 1] = string.format("%s -- %s: %s hits as a %s body, band is %d-%d",
                        where(row), v, tostring(row.ex.out.hits), row.role, band.min, band.max)
                end
            end
            assert(#bad == 0, "these fall outside the hits-to-kill band their role is held to (Balance.TTK):\n  "
                .. table.concat(bad, "\n  "))
        end,
    },
    {
        name = "an Easy quest fields nothing the starting company cannot fight",
        fn = function()
            local bad = {}
            for _, row in ipairs(sweep()) do
                if row.difficulty == "Easy" and (row.ex.out.floored or row.dominates) then
                    bad[#bad + 1] = string.format("%s -- %s", where(row),
                        row.ex.out.floored and "walled to every melee weapon" or "dominates the reference loadout")
                end
            end
            assert(#bad == 0, "a quest labelled Easy promises a fight the player is equipped for; these field a body\n"
                .. "the starting company cannot answer:\n  " .. table.concat(bad, "\n  "))
        end,
    },
    {
        name = "no single armor walls a weapon by itself",
        fn = function()
            -- Combat.mitigatedDamage sums resists across EVERY tag on the blow, and essentially every
            -- physical weapon carries both a family tag and `physical` -- so an armour written as
            -- `slash 3, physical 2` really subtracts 5 from a sword and its author had no way to see
            -- it. Rather than change the summing (which would redefine what every existing resist
            -- number means), the rule is stated on the TOTAL, per probe. Layering is still allowed;
            -- adding up to a wall is not.
            --
            -- Judged at Balance.itemPrestige -- the earlier of "when the player may buy it" and "when
            -- it is first swung at them". An armour's shelf gate is not when it is first FACED:
            -- armor_oathkeeper_shield is endgame plate gated at quest 11, and a forsworn captain
            -- wears it into a prestige-2 fight. Checking only the gate declared that fine.
            local bad = {}
            for id, def in pairs(Item.defs) do
                if def.type == "armor" then
                    local prestige = Balance.itemPrestige(id, def)
                    for _, probeName in ipairs(Balance.PROBE_ORDER) do
                        local probe = Balance.PROBES[probeName]
                        local budget = (Balance.attackBudget(prestige, { probe = probe }))
                        local cap = budget * Balance.ARMOR_SHARE

                        local item = Item.instantiate(id, 1, 0)
                        local statName = probe.magical and "magicDefense" or "defense"
                        local total = (item.bonus and item.bonus[statName]) or 0
                        for _, t in ipairs(probe.tags) do
                            total = total + ((item.resist and item.resist[t]) or 0)
                        end

                        if total > cap then
                            bad[#bad + 1] = string.format("%s vs %s: takes %d off a %d budget (cap %.1f at %.0f%%)",
                                id, probeName, total, budget, cap, Balance.ARMOR_SHARE * 100)
                        end
                    end
                end
            end
            table.sort(bad)
            assert(#bad == 0, "one piece of armour may not take more than Balance.ARMOR_SHARE of the attack budget\n"
                .. "off a single weapon -- defense bonus PLUS every resist that weapon's tags match:\n  "
                .. table.concat(bad, "\n  "))
        end,
    },
    {
        -- THE RULE FORGING IS NOT ALLOWED TO PAPER OVER: a weapon the shelf opens after slot N must
        -- carry slot N+1 on its own, straight off the rack. Forging is headroom -- the thing that puts
        -- the player ahead of the curve -- not the toll that gets them level with it, and a band
        -- measured at the forge ceiling would quietly make the bench mandatory (see
        -- Balance.FORGE_BASELINE for the version of this that shipped first and was wrong).
        --
        -- Stated on the house's BEST plain weapon at that gate, because that is what the player would
        -- actually buy, and checked against the bodies the next gate fields.
        name = "a weapon bought at one gate carries the next gate's fights, unforged",
        fn = function()
            local bad = {}
            for _, vendorId in ipairs(houses()) do
                -- The bodies this house's line fields, by the standing they are met at.
                local byPrestige = {}
                for _, questId in ipairs(Balance.questOrder()) do
                    local def = Quest.defs[questId]
                    if def.sponsor == vendorId then
                        local p = Balance.prestigeFor(questId)
                        for _, body in ipairs(Balance.bodiesFor(questId)) do
                            if not Balance.isPlaceholder(body.id) and not Balance.isCompanion(body.id)
                                and not WAIVERS[body.id] and not TTK_WAIVED[body.id] then
                                byPrestige[#byPrestige + 1] = { id = body.id, prestige = p }
                            end
                        end
                    end
                end

                -- The best plain DAMAGING thing on the shelf at each gate, unforged -- weapons AND
                -- abilities, because for half the houses the ability IS the weapon. The Arcanum sells
                -- no blade better than a gate-0 wand until quest 10; what its player actually swings
                -- is Fire Bolt and then Fireball, and Combat.dealDamage reads the two item types
                -- through the same `activeAbility.damage`. Checking weapons alone reported the
                -- Arcanum unable to hurt a mage while its shelf was selling the answer.
                for gate = 0, 6 do
                    local best, bestPower = nil, -1
                    for id, def in pairs(Item.defs) do
                        if (def.type == "weapon" or def.type == "ability")
                            and def.price and not def.discipline
                            and def.class and Forge.houseVendorFor(def.class) == vendorId
                            and (def.unlockQuests or 0) <= gate then
                            local w = Item.instantiate(id, 1, Balance.FORGE_BASELINE)
                            local power = (w.activeAbility and w.activeAbility.damage) or 0
                            if power > bestPower then best, bestPower = id, power end
                        end
                    end

                    if best then
                        for _, body in ipairs(byPrestige) do
                            -- Bodies met at roughly the NEXT gate, which is what this weapon is for.
                            if body.prestige >= gate + 1 and body.prestige <= gate + 3 then
                                local w = Item.defs[best]
                                local probe = { weapon = best, tags = w.tags or {},
                                    magical = false }
                                for _, t in ipairs(w.tags or {}) do
                                    if t == "magical" then probe.magical = true end
                                end
                                local ex = Balance.exchange(body.prestige, body.id, probe)
                                if ex.out.floored then
                                    bad[#bad + 1] = string.format(
                                        "%s gate %d: %s (unforged) floors against %s at p%d",
                                        vendorId, gate, best, body.id, body.prestige)
                                end
                            end
                        end
                    end
                end
            end
            table.sort(bad)
            assert(#bad == 0, "gear must be balanced for the content it unlocks INTO, without a trip to\n"
                .. "the bench -- forging is headroom, not a toll:\n  " .. table.concat(bad, "\n  "))
        end,
    },
    {
        -- THE SLOT IS THE GRADE: an item's unforged magnitude is decided by the slot it unlocks from,
        -- and nothing else earns a discount (Balance.slotTarget). The ladder runs from a family's base
        -- weapon unforged to that same weapon fully forged, so the last slot unforged equals the first
        -- slot fully forged, and two items sharing a slot share a number -- what separates them is the
        -- effect, which is the whole point of a shelf.
        --
        -- WHAT THIS REPLACED, because both holes are worth remembering. The rule used to be a constant
        -- share of the wielder's stat, and it was enforced (a) only on priced items, so all 70 quest
        -- rewards went unmeasured in both directions, and (b) only on items with no rider -- which is
        -- FOUR items in the game, all at slot 0, because a base weapon is precisely the one that just
        -- deals damage. So the floor applied to four items and the roster drifted under it: 439 of 472
        -- same-family slot pairs had the earlier item, fully forged, beating the later one unforged.
        --
        -- Held PER FAMILY still. docs/weapons.md gives each archetype its own level, paid for in tempo
        -- and hands -- a greatsword "winds up a turn, then lands the heaviest hit in the game" and
        -- really does carry four times a dagger's power. One ladder across all weapons proposed cutting
        -- the iron greatsword to a dagger's weight and would have deleted the archetype system
        -- tests/weapon_spec.lua exists to defend.
        --
        -- The base table is the whole rule's foundation, so it is checked before the rule is: each
        -- entry must still exist, still be priced, and still belong to the family it is named for.
        -- It mirrors docs/weapons.md's S1 rows, and a mirror is a thing that drifts.
        name = "every weapon family names a base weapon that is real, priced, and of that family",
        fn = function()
            local bad = {}
            for fam, id in pairs(Balance.FAMILY_BASE) do
                local def = Item.defs[id]
                if not def then
                    bad[#bad + 1] = fam .. ": names " .. id .. ", which does not exist"
                elseif not def.price then
                    bad[#bad + 1] = fam .. ": " .. id .. " is not priced, so no shelf ever sells it"
                elseif Item.archetype(def) ~= fam then
                    bad[#bad + 1] = string.format("%s: %s is a %s, not a %s",
                        fam, id, tostring(Item.archetype(def)), fam)
                elseif not Balance.itemShare(id) then
                    bad[#bad + 1] = fam .. ": " .. id .. " has no damage magnitude to read a level from"
                end
            end
            -- And every family that has priced members must name one, or its members go unjudged.
            local seen = {}
            for id, def in pairs(Item.defs) do
                if def.price and def.type == "weapon" then
                    local fam = Item.archetype(def)
                    if fam and Balance.itemShare(id) then seen[fam] = true end
                end
            end
            for fam in pairs(seen) do
                if not Balance.FAMILY_BASE[fam] then
                    bad[#bad + 1] = fam .. ": has priced weapons but names no base (docs/weapons.md S1)"
                end
            end
            table.sort(bad)
            assert(#bad == 0, "Balance.FAMILY_BASE mirrors docs/weapons.md's S1 rows and has drifted from it:\n  "
                .. table.concat(bad, "\n  "))
        end,
    },
    {
        name = "an item's magnitude is the one its unlock slot names, within its family",
        fn = function()
            local bad = {}
            for id in pairs(Item.defs) do
                -- No price condition: a quest reward is gear the player is HANDED for finishing a
                -- line, and leaving it unjudged is how weapon_deadfall_bow shipped at a fifth of its
                -- slot's number. Items with nothing to grade (ally-targeted, no authored damage, a
                -- family with no readable anchors) return nil and are skipped by the verdict itself.
                local verdict, want, have = Balance.magnitudeVerdict(id)
                if verdict and verdict ~= "ok" then
                    local def = Item.defs[id]
                    bad[#bad + 1] = string.format(
                        "%s (slot %d, %s%s): %d power against slot target %d -- %s",
                        id, def.unlockQuests or 0, tostring(Balance.familyOf(id)),
                        def.price and "" or ", quest-only", have, want,
                        verdict == "low" and "raise it" or "it outreaches its own slot")
                end
            end
            table.sort(bad)
            assert(#bad == 0, "the slot an item unlocks from IS its power level: a later slot that opens a\n"
                .. "weaker item than an earlier one is a purchase that is a downgrade. Waive a\n"
                .. "deliberate outlier in Balance.MAGNITUDE_WAIVERS, with the reason:\n  "
                .. table.concat(bad, "\n  "))
        end,
    },
    {
        name = "the forge ceiling rises with every quest and reaches the top of the ladder",
        fn = function()
            local bad = {}
            for _, vendorId in ipairs(houses()) do
                -- THE LINE IS THE ERRANDS IT ASKS FOR, not everything it sponsors. This counted every
                -- quest naming the vendor -- twelve to fourteen apiece -- and a house asks for six
                -- (models/errand.lua). The rest are unasked, and the descent is the only mode there is,
                -- so a quest nobody is sent to is a quest nobody can finish. Walking a standing no
                -- player can reach is how this stayed green while every bench in the game stopped a
                -- rung short of the ladder.
                local lineLength = Class.CLASS_LEVEL_CAP
                -- A class item of this house, to ask the ceiling about something real.
                local sample
                for id, def in pairs(Item.defs) do
                    if def.class and Forge.houseVendorFor(def.class) == vendorId
                        and not def.discipline and def.price then
                        if not sample or id < sample.id then sample = { id = id, def = def } end
                    end
                end
                if sample then
                    local prev = -1
                    for done = 0, lineLength do
                        local player = Balance.playerAt(math.max(1, done), vendorId, done)
                        local ceiling = Forge.ceilingFor(player, sample.def)
                        if ceiling < prev then
                            bad[#bad + 1] = string.format("%s: ceiling fell from +%d to +%d after %d quests",
                                vendorId, prev, ceiling, done)
                        end
                        prev = ceiling
                    end
                    if prev < Item.MAX_LEVEL then
                        bad[#bad + 1] = string.format("%s: a finished line tops out at +%d, short of the +%d the ladder offers",
                            vendorId, prev, Item.MAX_LEVEL)
                    end
                end
            end
            assert(#bad == 0, "the bench must follow the shelf -- a house's ceiling rises as its quests are run and\n"
                .. "reaches the top of the curve by the time its line is done:\n  " .. table.concat(bad, "\n  "))
        end,
    },
    {
        name = "every quest at a house opens a fair share of shelf, not a trickle then a flood",
        fn = function()
            -- Counting PLAIN (non-discipline) rows on purpose. A gate whose only additions are
            -- discipline stock is a gate that opens nothing for a player who has not unlocked the
            -- discipline -- and the shop visibly does not move for a whole quest.
            --
            -- Only INTERIOR silence counts. A house whose shelf has nothing left to open has finished,
            -- and its last quests are capstones paying unique rewards rather than stock -- flagging
            -- that would be demanding an infinite catalogue. A gap with more shelf still to come is
            -- the real defect: the player runs a quest, opens the shop, and the shop is unchanged.
            local bad = {}
            local Errand = require("models.errand")
            for _, vendorId in ipairs(houses()) do
                -- THE LADDER, not the count of quests the house sponsors: a house asks only for the work
                -- that opens a rung (models/errand.lua), and the plain numbered fights it also sponsors
                -- are not gates at all. Walking those read every one of them as a quest that opened
                -- nothing -- which is true and meaningless, since nobody is ever asked to run them.
                local lineLength = Class.CLASS_LEVEL_CAP

                -- The whole curve first, so "is there more to come" is answerable at each gate.
                local counts = {}
                for done = 0, lineLength do
                    local player = Balance.playerAt(math.max(1, done), vendorId, done)
                    local unlocked = Class.unlockedSet(player)
                    local levels = Class.levelSet(player)
                    local plain = 0
                    for _, entry in ipairs(Vendor.stock(vendorId, done, nil, unlocked, levels)) do
                        if not entry.locked then
                            local def = entry.item or Item.defs[entry.id]
                            if not (def and def.discipline) then plain = plain + 1 end
                        end
                    end
                    counts[done] = plain
                end

                -- At least MIN_OPENED rows per quest while the shelf still has stock to come.
                --
                -- One was the original bar and it is too low: it catches a gate that opens NOTHING
                -- but passes a house that dribbles a single row for three quests running and then
                -- drops five at once, which reads to the player as the shop not moving. The Cathedral
                -- was doing exactly that at gates 2, 3 and 4, and the Arcanum at 3 and 4.
                --
                -- The FINAL opening gate is exempt: a house whose catalogue is finishing has nothing
                -- left to spread, and demanding two more rows there is demanding an infinite shelf.
                local MIN_OPENED = 2
                local final = counts[lineLength]
                for done = 1, lineLength do
                    local opened = counts[done] - counts[done - 1]
                    if counts[done] < final and opened < MIN_OPENED then
                        bad[#bad + 1] = string.format(
                            "%s: quest %d opened %d plain row%s (want %d; %d more arrive later)",
                            vendorId, done, opened, opened == 1 and "" or "s",
                            MIN_OPENED, final - counts[done])
                    end
                end
            end
            assert(#bad == 0, "finishing a house's quest must move that house's shelf, or the reward for running it\n"
                .. "is invisible:\n  " .. table.concat(bad, "\n  "))
        end,
    },
}
