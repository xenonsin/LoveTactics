-- THE UNDEAD TAG (models/character.lua's `undead`): a body that died keeps its CLASS and its RACE and is
-- tagged undead on top. Settled on review 2026-09-25 ("The Dead Hand"): "Skeletons do have classes and
-- keep the original race's bonus on top of being tagged undead."
--
-- What this file holds, in the order it matters:
--   * the tag is a second answer beside the race, and both kinds of dead answer it;
--   * the tag does work -- it seeds Grave-Cold, once, and never over an author's own cell;
--   * the Crown's skeletons moved onto the rule without any body's lattice moving, because the lattice
--     rides on the bone item now (a humanoid may not also have a hide);
--   * the Bestiary files a dead dwarf with the dead.
--
-- Pure model logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Fixture = require("tests.support.fixture")

local function count(char, id)
    local n = 0
    for _, it in ipairs(Character.eachItem(char)) do
        if it.id == id then n = n + 1 end
    end
    return n
end

local function unitOf(id)
    local c = Combat.new(Fixture.new(6, 6),
        { Fixture.unit("character_knight", 1, 1) },
        { Fixture.unit(id, 5, 5) })
    return c.units[2], c
end

return {
    {
        name = "both kinds of dead answer the tag: a race that never lived, and a living race that died",
        fn = function()
            assert(Character.isUndead(Character.instantiate("character_zombie")),
                "a zombie's race is undead")
            local knight = Character.instantiate("character_skeleton_knight")
            assert(Character.isUndead(knight), "the Skeleton Knight is tagged undead")
            assert(knight.race == "human", "...and is still human: " .. tostring(knight.race))
            assert(knight.kind == "humanoid", "...so its kind is still the humanoid one")
            assert(not Character.isUndead(Character.instantiate("character_knight")),
                "the living knight is not")
            assert(Character.isUndead(Character.defs.character_skeleton_knight),
                "a blueprint answers the same question the runtime character does")
        end,
    },
    {
        name = "a skeleton keeps its class: the dead knight grows on the knight's table",
        fn = function()
            for _, pair in ipairs({
                { "character_skeleton_knight", "character_knight" },
                { "character_barrow_lord", "character_knight" },
                { "character_skeleton_archer", "character_archer" },
            }) do
                local dead, living = Character.instantiate(pair[1]), Character.instantiate(pair[2])
                assert(dead.class and dead.class == living.class, pair[1] .. " keeps "
                    .. tostring(living.class) .. ", got " .. tostring(dead.class))
            end
        end,
    },
    {
        name = "the tag seeds Grave-Cold once, and leaves an author's own copy where it was",
        fn = function()
            local knight = Character.instantiate("character_skeleton_knight")
            assert(count(knight, "utility_grave_cold") == 1, "seeded exactly once: "
                .. count(knight, "utility_grave_cold"))
            -- The zombie lists it by hand. The grant must not add a second.
            local zombie = Character.instantiate("character_zombie")
            assert(count(zombie, "utility_grave_cold") == 1, "an authored copy is not doubled: "
                .. count(zombie, "utility_grave_cold"))
            assert(count(Character.instantiate("character_knight"), "utility_grave_cold") == 0,
                "and the living are seeded nothing")
        end,
    },
    {
        name = "a heal still wounds a skeleton that kept its class",
        fn = function()
            local u, c = unitOf("character_skeleton_knight")
            local hp = u.char.stats.health
            hp.current = hp.current - 10
            local before = hp.current
            Combat.applyHeal(c, u, 4)
            assert(hp.current == before - 4, "Grave-Cold turned the heal: " .. tostring(before)
                .. " -> " .. tostring(hp.current))
        end,
    },
    {
        name = "the retrofit moved no lattice: every skeleton's total is the line it used to declare",
        fn = function()
            local want = {
                character_skeleton_knight = { slash = 3, pierce = 3, impact = -6, holy = -6 },
                character_skeleton_archer = { slash = 3, pierce = 3, impact = -6, holy = -6 },
                character_barrow_lord = { slash = 4, pierce = 4, impact = -8, holy = -8 },
                character_the_skeleton_king = { slash = 5, pierce = 5, impact = -10, holy = -10 },
            }
            for id, line in pairs(want) do
                local u = unitOf(id)
                for tag, amount in pairs(line) do
                    assert((u.resist[tag] or 0) == amount, string.format("%s %s: %s, want %d",
                        id, tag, tostring(u.resist[tag]), amount))
                end
            end
        end,
    },
    {
        name = "the Bestiary files a dead dwarf with the dead",
        fn = function()
            -- Asked of the same predicate tools/wiki_gen.lua's catalogue asks, over every blueprint: no
            -- body tagged undead may be filed anywhere but the Undead page.
            for id, def in pairs(Character.defs) do
                if def.undead then
                    assert(Character.isUndead(def), id .. " is tagged and must answer the tag")
                end
            end
        end,
    },
}
