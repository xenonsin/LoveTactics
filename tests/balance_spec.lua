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
local Discipline = require("models.discipline")
local Forge = require("models.forge")

-- id -> why this body is exempt from EVERY rule below.
local WAIVERS = {
    -- scaling = false, and its claw arithmetic IS the prologue's parry lesson: the tutorial text in
    -- data/tutorials/village.lua quotes these exact numbers, so tuning it to a band would silently
    -- unteach the one fight that explains the combat system.
    character_demon_grunt = "prologue: scaling = false, its arithmetic is the parry lesson",
}

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
local HARMLESS_BY_DESIGN = {
    character_crucible_golem = "a wall, not a fist -- 'not meant to win an exchange, meant to be in the way of one'",
    character_homunculus = "'worth is not the hit but the Poison its fists leave behind'",
    character_ordnance_sentry = "a conjured emplacement; its item is its immobility, not its damage",
    character_blightstake = "area denial -- 'I want that corridor to cost something to walk down'",
}

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
        name = "every body can hurt the player back",
        fn = function()
            -- Objects, walls and support units are exempt: Balance.isNonCombatant reads the two ways a
            -- blueprint declares "this does not attack", and HARMLESS_BY_DESIGN names the constructs
            -- whose prose says the same thing in a way no rule can see.
            local bad = {}
            for _, row in ipairs(sweep()) do
                if row.ex.back.floored
                    and not Balance.isNonCombatant(row.id)
                    and not HARMLESS_BY_DESIGN[row.id] then
                    bad[#bad + 1] = string.format("%s -- swings %d, deals %d/hit, %s hits to fell the avatar",
                        where(row), row.ex.back.budget, row.ex.back.perHit, tostring(row.ex.back.hits))
                end
            end
            assert(#bad == 0, "these bodies floor against the reference loadout and are no threat at all -- the\n"
                .. "mirror of the rule above, and the failure a one-sided rescale creates:\n  "
                .. table.concat(bad, "\n  "))
        end,
    },
    {
        name = "time-to-kill lands inside the band for the body's role",
        fn = function()
            local bad = {}
            for _, row in ipairs(sweep()) do
                local v = row.verdict
                if v == "too slow" or v == "too fast" then
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
        name = "the forge ceiling rises with every quest and reaches the top of the ladder",
        fn = function()
            local bad = {}
            for _, vendorId in ipairs(houses()) do
                local lineLength = 0
                for _, def in pairs(Quest.defs) do
                    if def.sponsor == vendorId then lineLength = lineLength + 1 end
                end
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
        name = "every quest at a house opens at least one shelf row it can actually sell",
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
            for _, vendorId in ipairs(houses()) do
                local lineLength = 0
                for _, def in pairs(Quest.defs) do
                    if def.sponsor == vendorId then lineLength = lineLength + 1 end
                end

                -- The whole curve first, so "is there more to come" is answerable at each gate.
                local counts = {}
                for done = 0, lineLength do
                    local player = Balance.playerAt(math.max(1, done), vendorId, done)
                    local unlocked = Discipline.unlockedSet(player)
                    local levels = Discipline.levelSet(player)
                    local plain = 0
                    for _, entry in ipairs(Vendor.stock(vendorId, done, nil, unlocked, levels)) do
                        if not entry.locked then
                            local def = entry.item or Item.defs[entry.id]
                            if not (def and def.discipline) then plain = plain + 1 end
                        end
                    end
                    counts[done] = plain
                end

                local final = counts[lineLength]
                for done = 1, lineLength do
                    if counts[done] == counts[done - 1] and counts[done] < final then
                        bad[#bad + 1] = string.format("%s: quest %d opened no plain row (still %d, and %d more arrive later)",
                            vendorId, done, counts[done], final - counts[done])
                    end
                end
            end
            assert(#bad == 0, "finishing a house's quest must move that house's shelf, or the reward for running it\n"
                .. "is invisible:\n  " .. table.concat(bad, "\n  "))
        end,
    },
}
