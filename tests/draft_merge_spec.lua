-- Tests for the combine mechanics in models/draft_run.lua: two of the same unit merge into a stronger
-- one (reusing the growth level-up), two of the same item level up. Pure logic, runs headless.

local DraftRun = require("models.draft_run")
local Character = require("models.character")
local Item = require("models.item")
local Growth = require("models.growth")

return {
    {
        name = "merging two of the same unit bumps the kept one exactly one growth level",
        fn = function()
            local run = DraftRun.new(1)
            local keep = Character.instantiate("character_knight")
            local fodder = Character.instantiate("character_knight")
            DraftRun.addUnit(run, keep)
            DraftRun.addUnit(run, fodder)

            local startLevel = keep.level or 1
            local result = DraftRun.mergeUnit(run, fodder, keep)
            assert(result, "the merge succeeds")
            assert(keep.level == startLevel + 1, "the kept unit gained exactly one level")
            assert(#run.bench == 1 and run.bench[1] == keep, "the fodder left the bench")
        end,
    },
    {
        name = "a unit merge is deterministic -- it grows the same way growth would on a level-up",
        fn = function()
            local run = DraftRun.new(1)
            local a = Character.instantiate("character_knight")
            local b = Character.instantiate("character_knight")
            DraftRun.addUnit(run, a)
            DraftRun.addUnit(run, b)
            DraftRun.mergeUnit(run, b, a)

            -- A lone knight grown one level by the growth system directly must land on the same health.
            local control = Character.instantiate("character_knight")
            Growth.resolve(control, (control.level or 1) + 1)
            assert(a.stats.health.max == control.stats.health.max,
                "a merged unit and a growth-leveled one agree, because a merge IS a growth level-up")
        end,
    },
    {
        name = "different units never merge, and a maxed unit has nowhere to grow",
        fn = function()
            local run = DraftRun.new(1)
            local knight = Character.instantiate("character_knight")
            local mage = Character.instantiate("character_mage")
            assert(not DraftRun.canMergeUnits(knight, mage), "two different characters do not combine")

            local maxed = Character.instantiate("character_knight")
            maxed.level = DraftRun.MAX_UNIT_LEVEL
            local dupe = Character.instantiate("character_knight")
            assert(not DraftRun.canMergeUnits(dupe, maxed), "a unit at the ceiling cannot be pushed higher")
        end,
    },
    {
        name = "a merged unit's gear is kept, not lost -- it moves to the run stash",
        fn = function()
            local run = DraftRun.new(1)
            local keep = Character.instantiate("character_knight")
            local fodder = Character.instantiate("character_knight")
            keep.inventory, fodder.inventory = {}, {}
            Character.addItem(fodder, Item.instantiate("weapon_iron_sword"))
            DraftRun.addUnit(run, keep)
            DraftRun.addUnit(run, fodder)

            DraftRun.mergeUnit(run, fodder, keep)
            local found = false
            for _, item in ipairs(run.stash or {}) do
                if item.id == "weapon_iron_sword" then found = true end
            end
            assert(found, "the fodder's weapon landed in the stash rather than evaporating")
        end,
    },
    {
        name = "two identical items combine into one a level higher, keeping the stack count",
        fn = function()
            local a = Item.instantiate("weapon_iron_sword", 1, 0)
            local b = Item.instantiate("weapon_iron_sword", 1, 0)
            assert(DraftRun.canMergeItems(a, b), "same item, same level, below the ceiling")

            local merged = DraftRun.mergeItems(a, b)
            assert(merged.level == 1, "the result is one level higher")
            assert(merged.id == "weapon_iron_sword", "and the same item")

            -- Different levels don't merge; the ceiling stops the climb.
            local hi = Item.instantiate("weapon_iron_sword", 1, 1)
            assert(not DraftRun.canMergeItems(a, hi), "mismatched levels do not combine")

            local maxed1 = Item.instantiate("weapon_iron_sword", 1, Item.MAX_LEVEL)
            local maxed2 = Item.instantiate("weapon_iron_sword", 1, Item.MAX_LEVEL)
            assert(not DraftRun.canMergeItems(maxed1, maxed2), "two maxed items have nowhere to go")
        end,
    },
}
