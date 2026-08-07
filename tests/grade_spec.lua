-- models/grade.lua: the item power grade, and the thing that keeps it honest.
--
-- The ANCHOR PAIRS below are the point of this file. A grader assembled out of weights can be made to
-- return any ranking at all, so the weights are not the contract -- these pairs are. Each one is a
-- judgement a designer will defend without looking at a number ("the capstone greataxe beats the iron
-- axe"), and the grader has to reproduce every one of them. When a weight is retuned and a pair
-- breaks, the weight was wrong; when a pair looks wrong, the pair is the thing to argue about.
--
-- This is the same discipline Balance.slotAnchors' header arrives at from the other side: a target
-- read off the data being audited cannot converge. An anchor set is authored, so it can.

local Grade = require("models.grade")
local Item = require("models.item")
local Status = require("models.status")

-- stronger, weaker -- and why, so a failure reads as an argument rather than a number mismatch.
local ANCHORS = {
    { "weapon_crimson_greataxe", "weapon_iron_axe", "the capstone axe beats the opening one" },
    { "weapon_avalanche", "weapon_iron_hammer", "a held avalanche beats a plain hammer" },
    { "ability_meteor_storm", "ability_fire_bolt", "the storm beats the bolt" },
    { "ability_summon_golem", "ability_minor_shock", "a body on the board beats a small shock" },
    { "utility_zephyr_striders", "utility_torch", "flight beats a torch" },
    { "ability_revive", "ability_heal", "raising the dead beats a heal" },
    { "ability_fireball", "ability_ice_bolt", "an area spell beats a single-target bolt" },
    { "weapon_iron_longbow", "weapon_iron_bow", "the longbow outranges and outhits the bow" },
    { "ability_cleave", "ability_rend", "hitting three beats debuffing one" },
    { "ability_holy_light", "ability_magical_barrier", "an area strike beats a single barrier" },

    -- ACROSS TYPES, which is where the units can tilt without anyone noticing. An active is graded on
    -- the turn it is spent, a passive on every turn it is worn, and the first cut of this file valued
    -- passives over a whole FIGHT -- an eightfold thumb that put plain armour above capstone weapons
    -- and reported the late shelf's charms as the strongest things in the game. These pin both
    -- directions: a real piece of armour must beat a trinket, and a capstone weapon must beat plain mail.
    { "armor_oathkeeper_shield", "armor_chainmail", "the capstone shield beats opening mail" },
    { "armor_iron_plate", "utility_torch", "plate beats a torch" },
    { "weapon_crimson_greataxe", "armor_chainmail", "a capstone weapon beats opening mail" },
    { "armor_chainmail", "utility_endurance", "mail beats a bare stat trinket" },
}

return {
    {
        name = "grade: one turn is worth something",
        fn = function()
            local turn = Grade.turnValue()
            assert(turn > 0, "a turn must be worth more than nothing, got " .. tostring(turn))
        end,
    },
    {
        name = "grade: every item grades, priced or not",
        fn = function()
            local ungraded = {}
            for id, def in pairs(Item.defs) do
                local value = Grade.of(id)
                if value == nil then ungraded[#ungraded + 1] = id end
            end
            assert(#ungraded == 0,
                #ungraded .. " items returned no grade at all: " .. table.concat(ungraded, ", ", 1,
                    math.min(8, #ungraded)))
        end,
    },
    {
        name = "grade: a quest reward grades without a price or a slot",
        fn = function()
            -- The reason the grade refuses to read either field: 166 items carry neither, and a grader
            -- that leaned on them could not rank a single one.
            -- A grade may legitimately come out NEGATIVE, and that is a result rather than a failure:
            -- the margin rule nets off the turn an active costs, so an ability that spends a whole turn
            -- to do less than a swing scores below zero and says so. ability_pull -- one body hauled one
            -- tile, no damage -- is the standing example. What is asserted here is that every one of
            -- them GRADES; what the number says is the report's business.
            local rewards = 0
            for id, def in pairs(Item.defs) do
                if not def.price and not def.unlockQuests then
                    local value = Grade.of(id)
                    assert(type(value) == "number",
                        id .. " is a quest reward and graded " .. tostring(value))
                    rewards = rewards + 1
                end
            end
            assert(rewards > 100, "expected the quest-reward shelf, found " .. rewards)
        end,
    },
    {
        name = "grade: the slot cannot move a grade",
        fn = function()
            -- The tautology guard, asserted rather than promised. Move an item's gate and its grade
            -- must not budge -- the day it does, the grade is reading the field it grades.
            local id = "weapon_iron_sword"
            local def = Item.defs[id]
            local was = def.unlockQuests
            local before = Grade.of(id)
            def.unlockQuests = 11
            Grade.reset()
            local after = Grade.of(id)
            def.unlockQuests = was
            Grade.reset()
            assert(math.abs(before - after) < 0.001,
                "grade moved with the slot: " .. before .. " -> " .. after)
        end,
    },
    {
        name = "grade: price cannot move a grade",
        fn = function()
            local id = "weapon_iron_sword"
            local def = Item.defs[id]
            local was = def.price
            local before = Grade.of(id)
            def.price = 9999
            Grade.reset()
            local after = Grade.of(id)
            def.price = was
            Grade.reset()
            assert(math.abs(before - after) < 0.001,
                "grade moved with the price: " .. before .. " -> " .. after)
        end,
    },
    {
        -- THE LOOP GUARD, and the one that took two attempts to get right. The slot grants an item its
        -- magnitude (Balance.slotTarget), so a grade that read the item's own damage was reading the
        -- slot it had just assigned -- grade -> slot -> magnitude -> grade. It converged only because
        -- it was damped, and a ranking that feeds its own input is the tautology this whole file exists
        -- to break, arriving one step further out than the two guards above look.
        --
        -- The blow is normalized to the family base before the effect is replayed, so this holds: move
        -- an item's authored damage as far as you like and its grade must not budge. What CAN move it
        -- is how many bodies the blow reaches and what rides along with it, which is the item.
        name = "grade: an item's own damage cannot move its grade",
        fn = function()
            -- Deliberately not a family BASE: those twelve weapons and ability_fire_bolt ARE the ruler
            -- (Balance.slotAnchors reads the normalization off them), so moving one legitimately moves
            -- every grade on its ladder. That is the anchors doing their job, not the loop reopening.
            for _, id in ipairs({ "weapon_crimson_greataxe", "ability_fireball", "weapon_sleepers_maul" }) do
                local def = Item.defs[id]
                local ab = def.activeAbility
                local was = ab.damage
                local before = Grade.of(id)
                -- A curve resolves per level, so replace it with a flat number well off its own scale.
                ab.damage = 999
                Grade.reset()
                local after = Grade.of(id)
                ab.damage = was
                Grade.reset()
                assert(math.abs(before - after) < 0.001,
                    id .. "'s grade moved with its own damage: " .. before .. " -> " .. after
                        .. " -- the slot is feeding the grade again")
            end
        end,
    },
    {
        name = "grade: a stun is worth about a turn",
        fn = function()
            local turn = Grade.turnValue()
            local stun = Grade.statusValue("status_stun")
            -- status_stun shoves initiative by its magnitude of 5, which is exactly one turn's ticks.
            assert(stun >= turn * 0.6 and stun <= turn * 2.5,
                "a stun graded " .. stun .. " against a turn worth " .. turn)
        end,
    },
    {
        name = "grade: a status that does nothing measurable is worth nothing",
        fn = function()
            -- Every status must at least not go NEGATIVE, whatever it carries.
            for id in pairs(Status.defs) do
                local v = Grade.statusValue(id)
                assert(v >= 0, id .. " graded negative: " .. tostring(v))
            end
        end,
    },
    {
        name = "grade: the anchor pairs hold",
        fn = function()
            local broken = {}
            for _, pair in ipairs(ANCHORS) do
                local strong, weak, why = pair[1], pair[2], pair[3]
                assert(Item.defs[strong], "anchor names a missing item: " .. strong)
                assert(Item.defs[weak], "anchor names a missing item: " .. weak)
                local a, b = Grade.of(strong), Grade.of(weak)
                if not (a > b) then
                    broken[#broken + 1] = string.format("%s (%.1f) should beat %s (%.1f) -- %s",
                        strong, a, weak, b, why)
                end
            end
            assert(#broken == 0, "\n         " .. table.concat(broken, "\n         "))
        end,
    },
    {
        -- An authored weight is only worth what it is attached to. A key that names no trait -- a typo,
        -- or an id retired by a merge the way trait_bulwark and trait_perfect_recall were -- would sit
        -- in the table looking like a decision while the trait it meant to weigh quietly went on
        -- riding a shape estimate. Nothing else would ever say so.
        name = "grade: every authored trait weight names a real trait",
        fn = function()
            local Trait = require("models.trait")
            local orphans = {}
            for id in pairs(Grade.TRAIT_GRADE) do
                if not Trait.defs[id] then orphans[#orphans + 1] = id end
            end
            table.sort(orphans)
            assert(#orphans == 0, #orphans .. " authored weight(s) name no trait: "
                .. table.concat(orphans, ", "))
        end,
    },
    {
        -- The shape estimate is now a BACKSTOP, not a supply. Every trait in the game carries a weight,
        -- so a new one arriving without one should be noticed here rather than quietly grading itself.
        name = "grade: every trait carries a weight, and none is left to the estimator",
        fn = function()
            local Trait = require("models.trait")
            local unweighed = {}
            for id in pairs(Trait.defs) do
                local _, authored = Grade.traitValue(id)
                if not authored then unweighed[#unweighed + 1] = id end
            end
            table.sort(unweighed)
            assert(#unweighed == 0, #unweighed .. " trait(s) still ride the shape estimate -- weigh them"
                .. " on the bench and add them to Grade.TRAIT_GRADE:\n         "
                .. table.concat(unweighed, "\n         "))
        end,
    },
    {
        -- Provenance is only useful while it is true. An id that leaves TRAIT_GRADE, or one marked
        -- adopted that was later actually judged, would leave the report pointing at the wrong rows.
        name = "grade: the adopted set names only traits that carry an authored weight",
        fn = function()
            local stray = {}
            for id in pairs(Grade.TRAIT_ADOPTED) do
                if Grade.TRAIT_GRADE[id] == nil then stray[#stray + 1] = id end
            end
            table.sort(stray)
            assert(#stray == 0, "adopted set names " .. #stray .. " trait(s) with no weight: "
                .. table.concat(stray, ", "))
        end,
    },
    {
        name = "grade: an authored weight beats the shape estimate",
        fn = function()
            -- Rising Wrath is judged at 6.0 turns; the estimator, reading a big `magnitude` off an
            -- onDamaged hook, wants 6.4. Close enough to pass unnoticed if the table were never read,
            -- so this asserts the PROVENANCE rather than the number: it must report as authored.
            local value, authored = Grade.traitValue("trait_wrath_rising")
            assert(authored, "an entry in Grade.TRAIT_GRADE must report as authored, not estimated")
            assert(math.abs(value - 6.0 * Grade.turnValue()) < 0.001,
                "authored 6.0 turns, got " .. (value / Grade.turnValue()))
        end,
    },
    {
        name = "grade: ranking a class returns it richest first",
        fn = function()
            local rows = Grade.rank("mage", { priced = true })
            assert(#rows > 20, "expected the mage shelf, got " .. #rows)
            for i = 2, #rows do
                assert(rows[i - 1].value >= rows[i].value,
                    "rank is not descending at " .. i .. ": " .. rows[i - 1].id .. " then " .. rows[i].id)
            end
        end,
    },
}
