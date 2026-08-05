-- The post-quest "Company Advancement" panel (ui/panels/advancement.lua), specifically its two boxed
-- sections between the prestige bar and the level-up list. They differ on purpose: what the quest
-- HANDED OVER is named (it is in the stash, and this panel is its only announcement), while what the
-- quest put on a sponsor's SHELF is only counted (the shop is where those are read). Sizing is what is
-- tested here -- the box wraps its content, so a quest with neither section must not reserve room for
-- one, and the shelf section must not grow with the size of the haul. Advancement.sections is the
-- font-free half of the panel, which is why it can be asked any of this without a window.

local Advancement = require("ui.panels.advancement")

local function stock(n)
    local items = {}
    for i = 1, n do items[i] = { id = "i" .. i, name = "Ware " .. i, price = 100 + i } end
    return { vendorId = "vendor_lodge", vendor = "Hunter's Lodge", items = items }
end

local function received(n)
    local items = {}
    for i = 1, n do items[i] = { id = "i" .. i, name = "Trophy " .. i, type = "armor" } end
    return items
end

return {
    {
        name = "a quest that gave nothing and opened nothing reserves no section height",
        fn = function()
            local s = Advancement.sections({ gold = 100 })
            assert(s.gainH == 0, "no items gained, no section")
            assert(s.stockH == 0, "no shelf opened, no section")
            assert(s.sectionsH == 0, "and the list sits straight under the bar")
        end,
    },
    {
        name = "the shelf section is one heading whatever the size of the haul",
        fn = function()
            local one = Advancement.sections({ unlockedStock = stock(1) })
            local many = Advancement.sections({ unlockedStock = stock(9) })
            assert(one.stockH > 0, "an opened shelf is announced")
            assert(one.stockH == many.stockH,
                "nine wares take the same room as one: the section counts, it does not list")
        end,
    },
    {
        name = "gained items are listed by name, and a long haul truncates to a +N line",
        fn = function()
            local few = Advancement.sections({ received = received(2) })
            assert(few.gainRows == 2 and few.gainMore == 0, "a short haul is shown whole")
            assert(few.gained[1].name == "Trophy 1", "and the panel has the instances to name")

            local lots = Advancement.sections({ received = received(7) })
            assert(lots.gainRows == 4, "the list is capped at four rows, got " .. lots.gainRows)
            assert(lots.gainMore == 3, "and the rest is a +N line, got " .. lots.gainMore)
            assert(lots.gainH > few.gainH, "which is still taller than the two-row case")
        end,
    },
    {
        name = "the two sections stack, and the panel grows by both",
        fn = function()
            local both = Advancement.sections({ received = received(1), unlockedStock = stock(3) })
            assert(both.sectionsH == both.gainH + both.stockH, "gained above shelf, both counted")
            assert(both.gainH > 0 and both.stockH > 0, "a quest can do both in one run")
        end,
    },
}
