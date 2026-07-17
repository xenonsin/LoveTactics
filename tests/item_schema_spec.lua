-- Tests for the item text contract (docs/item-text.md).
--
-- Every item blueprint carries two strings with different jobs: `description` says what the item
-- DOES, in one mechanical sentence, and `flavor` says what it MEANS, in a story line the tooltip
-- renders italic at its foot. This sweep is what makes the doc enforced rather than aspirational --
-- a new item that ships prose in the description slot, or no flavor at all, fails the build.
--
-- The sweep runs over Item.defs (blueprints), not instances, because the blueprint is where an
-- author writes; tests/data_spec.lua covers that Item.instantiate carries the fields through.
--
-- Pure logic, headless. Sweep style mirrors tests/weapon_spec.lua's eachWeapon().

local Item = require("models.item")

-- The description is a single mechanical sentence, so a long one is a reliable smell that prose
-- crept back in. Generous on purpose: the ceiling catches paragraphs, not tight two-clause lines.
local DESC_MAX = 120

-- Every item blueprint, as { id, def } pairs, sorted so a failure names the same item every run.
local function eachItem()
    local out = {}
    for id, def in pairs(Item.defs) do out[#out + 1] = { id = id, def = def } end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

return {
    {
        name = "every item declares a mechanical description and a story flavor (docs/item-text.md)",
        fn = function()
            local items = eachItem()
            assert(#items > 0, "the registry found some items at all")
            for _, it in ipairs(items) do
                local def = it.def
                assert(type(def.description) == "string" and def.description ~= "",
                    it.id .. " declares no description -- say what it DOES (docs/item-text.md)")
                assert(type(def.flavor) == "string" and def.flavor ~= "",
                    it.id .. " declares no flavor -- say what it MEANS (docs/item-text.md)")
            end
        end,
    },
    {
        name = "an item's flavor never just restates its description",
        fn = function()
            for _, it in ipairs(eachItem()) do
                assert(it.def.flavor ~= it.def.description,
                    it.id .. " uses the same line for both -- flavor must reveal something about the"
                        .. " world, not repeat the mechanic")
            end
        end,
    },
    {
        name = "a description stays a single mechanical sentence, not a paragraph",
        fn = function()
            for _, it in ipairs(eachItem()) do
                local n = #it.def.description
                assert(n <= DESC_MAX,
                    it.id .. "'s description is " .. n .. " chars (max " .. DESC_MAX .. ") -- lead"
                        .. " with the verb and move the prose to flavor (docs/item-text.md)")
            end
        end,
    },
}
