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
            assert(DraftRun.cellOf(run, keep), "the kept unit is still fielded")
            assert(DraftRun.removeUnit(run, fodder) == false, "the fodder is gone from formation and bench")
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
        name = "a merge cascades into the grid: the fodder's matching gear upgrades the kept unit's, in place",
        fn = function()
            local run = DraftRun.new(1)
            local keep = Character.instantiate("character_knight")
            local fodder = Character.instantiate("character_knight")
            keep.inventory, fodder.inventory = {}, {}
            -- Cell 3, not cell 1: the upgrade must not relocate the piece. The grid is an adjacency
            -- surface, so a merge that repacked it would rearrange a build the player laid out.
            keep.inventory[3] = Item.instantiate("weapon_iron_sword", 1, 0)
            fodder.inventory[1] = Item.instantiate("weapon_iron_sword", 1, 0)
            DraftRun.addUnit(run, keep)
            DraftRun.addUnit(run, fodder)

            local result = DraftRun.mergeUnit(run, fodder, keep)
            assert(result, "the merge succeeds")
            assert(#(run.stash or {}) == 0, "nothing went to the stash -- the duplicate was absorbed")
            assert(keep.inventory[3] and keep.inventory[3].level == 1,
                "the kept unit's sword is one level higher, in the cell it already occupied")
            assert(keep.inventory[1] == nil, "and the upgrade did not claim a second cell")
            assert(#result.upgraded == 1 and result.upgraded[1].id == "weapon_iron_sword",
                "the result reports what it upgraded, so the screen can say so")
            assert(result.stashed == 0, "and that nothing was stashed")
        end,
    },
    {
        name = "gear the kept unit cannot absorb still goes to the stash, and never auto-equips",
        fn = function()
            local run = DraftRun.new(1)
            local keep = Character.instantiate("character_knight")
            local fodder = Character.instantiate("character_knight")
            keep.inventory, fodder.inventory = {}, {}
            keep.inventory[1] = Item.instantiate("weapon_iron_sword", 1, 0)
            fodder.inventory[1] = Item.instantiate("weapon_iron_spear", 1, 0)  -- a different piece
            DraftRun.addUnit(run, keep)
            DraftRun.addUnit(run, fodder)

            local result = DraftRun.mergeUnit(run, fodder, keep)
            assert(result and result.stashed == 1 and #result.upgraded == 0, "the spear could not combine")
            assert(#run.stash == 1, "it landed in the stash for the player to re-slot deliberately")
            assert(keep.inventory[1].level == 0, "and the sword it could not touch is untouched")
            assert(Character.itemCount(keep) == 1,
                "nothing was auto-equipped into a free cell -- grid slots stay the player's decision")
        end,
    },
    {
        name = "every duplicate keeps paying -- merging the same unit twice upgrades its gear twice",
        fn = function()
            -- The bug this guards: a second merge used to leave the signature at +1 and drop a junk copy
            -- of it in the stash, because the fodder's fresh +0 could not see the +1 the first merge made.
            local run = DraftRun.new(1)
            local keep = Character.instantiate("character_knight")
            keep.inventory = {}
            keep.inventory[3] = Item.instantiate("weapon_iron_sword", 1, 0)
            DraftRun.addUnit(run, keep)

            for pass = 1, 2 do
                local fodder = Character.instantiate("character_knight")
                fodder.inventory = {}
                fodder.inventory[1] = Item.instantiate("weapon_iron_sword", 1, 0)
                DraftRun.addUnit(run, fodder)

                local result = DraftRun.mergeUnit(run, fodder, keep)
                assert(result, "the merge succeeds")
                assert(keep.inventory[3].level == pass, "the sword climbed on pass " .. pass)
                assert(result.stashed == 0, "and no junk copy was littered into the stash")
            end
            assert(keep.level == 3, "and the body itself is three copies deep")
        end,
    },
    {
        name = "a merge cascade delivers every copy the fodder carried, in one cell",
        fn = function()
            local run = DraftRun.new(1)
            local keep = Character.instantiate("character_knight")
            local fodder = Character.instantiate("character_knight")
            keep.inventory, fodder.inventory = {}, {}
            keep.inventory[1] = Item.instantiate("weapon_iron_sword", 1, 0)
            fodder.inventory[1] = Item.instantiate("weapon_iron_sword", 1, 0)
            fodder.inventory[2] = Item.instantiate("weapon_iron_sword", 1, 0)
            DraftRun.addUnit(run, fodder)
            DraftRun.addUnit(run, keep)

            local result = DraftRun.mergeUnit(run, fodder, keep)
            assert(keep.inventory[1].level == 2, "three copies of the sword make a +2, in the one cell")
            assert(result.stashed == 0, "nothing fell through -- the same total as slotting them by hand")
            assert(Character.itemCount(keep) == 1, "and the upgrade never claimed a second cell")
        end,
    },
    {
        name = "the highest eligible cell absorbs the copy, and fodder is never downgraded",
        fn = function()
            local char = Character.instantiate("character_knight")
            char.inventory = {}
            char.inventory[1] = Item.instantiate("weapon_iron_sword", 1, 0)
            char.inventory[2] = Item.instantiate("weapon_iron_sword", 1, 3)

            local merged, cell = DraftRun.mergeItemInto(char, Item.instantiate("weapon_iron_sword", 1, 0))
            assert(cell == 2, "the +3 took the copy, not the +0 sitting in an earlier cell")
            assert(merged.level == 4, "leaving a +4 -- feeding the best piece is worth the most")
            assert(char.inventory[1].level == 0, "and the other copy is untouched")

            -- The other direction: a forged piece poured into a plain one keeps its own value.
            local plain = Character.instantiate("character_knight")
            plain.inventory = {}
            plain.inventory[1] = Item.instantiate("weapon_iron_sword", 1, 0)
            assert(DraftRun.mergeItemInto(plain, Item.instantiate("weapon_iron_sword", 1, 3)).level == 4,
                "a +3 spent as fodder is never quietly downgraded to a +1")
        end,
    },
    {
        name = "mergeItemInto answers nil when the grid holds no match",
        fn = function()
            local char = Character.instantiate("character_knight")
            char.inventory = {}
            char.inventory[2] = Item.instantiate("weapon_iron_sword", 1, 0)

            assert(DraftRun.mergeSlotFor(char, Item.instantiate("weapon_iron_sword", 1, 0)) == 2,
                "it finds the cell holding the match")
            assert(DraftRun.mergeSlotFor(char, Item.instantiate("weapon_iron_spear", 1, 0)) == nil,
                "a different item has no home")
            assert(DraftRun.mergeItemInto(char, Item.instantiate("weapon_iron_spear", 1, 0)) == nil,
                "and it is refused rather than forced into a free cell")
            assert(char.inventory[2].level == 0, "a refused merge leaves the grid untouched")

            local maxed = Character.instantiate("character_knight")
            maxed.inventory = { [1] = Item.instantiate("weapon_iron_sword", 1, Item.MAX_LEVEL) }
            assert(DraftRun.mergeItemInto(maxed, Item.instantiate("weapon_iron_sword", 1, 0)) == nil,
                "a piece at the ceiling cannot absorb another copy")

            -- The store asks this question before it has an instance to offer: an entry is just an id
            -- and a level, which is all mergeSlotFor reads.
            assert(DraftRun.mergeSlotFor(char, { id = "weapon_iron_sword", level = 0 }) == 2,
                "a store entry answers it as well as a live item")
        end,
    },
    {
        name = "two identical items combine into one a level higher, keeping the stack count",
        fn = function()
            local a = Item.instantiate("weapon_iron_sword", 1, 0)
            local b = Item.instantiate("weapon_iron_sword", 1, 0)
            assert(DraftRun.canMergeItems(a, b), "same item, below the ceiling")

            local merged = DraftRun.mergeItems(a, b)
            assert(merged.level == 1, "the result is one level higher")
            assert(merged.id == "weapon_iron_sword", "and the same item")

            -- Mismatched levels combine too -- a level counts COPIES, so every duplicate keeps paying.
            local hi = Item.instantiate("weapon_iron_sword", 1, 1)
            assert(DraftRun.canMergeItems(a, hi), "levels need not match")
            assert(DraftRun.mergeItems(a, hi).level == 2, "the result is one above the better of the two")

            local maxed1 = Item.instantiate("weapon_iron_sword", 1, Item.MAX_LEVEL)
            local maxed2 = Item.instantiate("weapon_iron_sword", 1, Item.MAX_LEVEL)
            assert(not DraftRun.canMergeItems(maxed1, maxed2), "two maxed items have nowhere to go")
        end,
    },
}
