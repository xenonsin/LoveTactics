-- Tests for the debug editor's blueprint writer (tools/write_character.lua): the round trip out of a
-- live character and back into a data/characters/*.lua table.
--
-- Only the pure half is exercised -- M.serialize plus a loadstring -- because M.write touches the
-- source tree. That is the half where the bugs live: every case below is one of the lossy fields
-- Character.instantiate leaves behind.

local Character = require("models.character")
local Writer = require("tools.write_character")

-- Serialize, load, and hand back the blueprint table -- i.e. exactly what the registry would see after
-- the file was written and the game relaunched.
local function roundTrip(char)
    local text = Writer.serialize(char)
    local loader = loadstring or load
    local chunk, err = loader(text)
    assert(chunk, "serializer produced invalid Lua: " .. tostring(err))
    local def = chunk()
    assert(type(def) == "table", "a blueprint must load as a table")
    return def, text
end

return {
    {
        name = "a shipped character round-trips to its own blueprint",
        fn = function()
            local source = Character.defs.character_archer
            local def = roundTrip(Character.instantiate("character_archer"))

            assert(def.name == source.name, "name should survive")
            assert(def.sprite == source.sprite, "sprite path should survive")
            assert(def.portrait == source.portrait, "portrait path should survive")
            assert(def.class == source.class, "class should survive")
            assert(def.archetype == source.archetype, "archetype should survive")
            assert(def.defaultAction == source.defaultAction, "the pinned default action should survive")
        end,
    },
    {
        name = "resource stats are written flat, not as { max, current }",
        fn = function()
            local source = Character.defs.character_archer
            local def = roundTrip(Character.instantiate("character_archer"))

            for _, key in ipairs(Character.RESOURCE_STATS) do
                assert(type(def.stats[key]) == "number",
                    key .. " must be written as a flat number, not the runtime pool table")
                assert(def.stats[key] == source.stats[key], key .. " should match the source blueprint")
            end
            assert(def.stats.damage == source.stats.damage, "flat stats should survive unchanged")
            assert(def.stats.movement == source.stats.movement, "movement should survive unchanged")
        end,
    },
    {
        name = "accumulated level-up growth is not baked into the blueprint",
        fn = function()
            local base = Character.defs.character_archer.stats
            -- What a levelled character looks like: growth re-baked onto the stats AND recorded, which
            -- is the shape Character.instantiate produces from a save (models/save.lua).
            local char = Character.instantiate("character_archer", {
                level = 5,
                growth = { health = 10, damage = 4 },
            })

            assert(char.stats.health.max == base.health + 10, "the live character should be levelled")

            local def = roundTrip(char)
            assert(def.stats.health == base.health,
                "a resource stat must be written at its base, with growth subtracted")
            assert(def.stats.damage == base.damage,
                "a flat stat must be written at its base, with growth subtracted")
        end,
    },
    {
        name = "startingItems keeps its positional 3x3 grid, gaps included",
        fn = function()
            local source = Character.defs.character_knight
            local def = roundTrip(Character.instantiate("character_knight"))

            assert(#def.startingItems == Character.MAX_INVENTORY,
                "every cell is written, so the grid reads as a grid")
            for cell = 1, Character.MAX_INVENTORY do
                local want = source.startingItems[cell] or false
                local got = def.startingItems[cell]
                if type(want) == "table" then
                    assert(type(got) == "table" and got[1] == want[1] and got[2] == want[2],
                        "a stack should survive as { id, count } in cell " .. cell)
                else
                    assert(got == want, "cell " .. cell .. " should hold the same thing")
                end
            end
        end,
    },
    {
        name = "a blank character survives instantiate -> serialize -> load",
        fn = function()
            -- The shape the editor's "new character" flow registers. Written as a def, instantiated,
            -- and written back: if this drifts, a character minted in the editor cannot be saved.
            local id = "character_writer_spec_blank"
            Character.defs[id] = {
                name = "Blank",
                sprite = "assets/chars/knight.png",
                stats = {
                    health = 50, mana = 20, stamina = 50, staminaRegen = 2,
                    damage = 10, magicDamage = 10, defense = 5, magicDefense = 5,
                    movement = 4, speed = 5,
                },
                startingItems = {},
            }

            local ok, err = pcall(function()
                local def = roundTrip(Character.instantiate(id))
                assert(def.name == "Blank", "the name should survive")
                assert(def.stats.health == 50, "stats should survive")
                assert(#def.startingItems == Character.MAX_INVENTORY, "an empty grid is still a grid")
                for cell = 1, Character.MAX_INVENTORY do
                    assert(def.startingItems[cell] == false, "every cell of a blank grid is empty")
                end
                assert(def.ai == nil, "a character with no rules writes no ai block")
            end)

            Character.defs[id] = nil -- leave the registry as we found it
            assert(ok, err)
        end,
    },
    {
        name = "editor-authored ai rules are promoted into the blueprint's ai block",
        fn = function()
            local char = Character.instantiate("character_archer")
            -- What the Tactics tab writes (ui/tactics_editor.lua edits char.aiRules).
            char.aiRules = {
                { enabled = true, priority = "high", act = "attack",
                  when = { subject = "any_foe", test = "count_at_least", value = 2 } },
            }

            local def = roundTrip(char)
            assert(def.ai and #def.ai == 1, "the authored rule should reach the blueprint's ai list")
            assert(def.ai[1].priority == "high", "priority should survive")
            assert(def.ai[1].act == "attack", "action should survive")
            assert(def.ai[1].when.subject == "any_foe", "the condition subject should survive")
            assert(def.ai[1].when.value == 2, "the condition value should survive")
        end,
    },
    {
        name = "a rule carrying a whenFn closure is refused rather than silently changed",
        fn = function()
            local char = Character.instantiate("character_archer")
            char.aiRules = { { act = "attack", whenFn = function() return true end } }
            assert(not pcall(Writer.serialize, char),
                "a closure cannot survive a text file, so serializing must fail loudly")
        end,
    },
    {
        name = "a body with no natural weapon writes unarmed = false",
        fn = function()
            local char = Character.instantiate("character_archer")
            char.unarmed = nil -- what `unarmed = false` in a blueprint produces
            local def = roundTrip(char)
            assert(def.unarmed == false, "an absent natural weapon must be written explicitly")
        end,
    },
}
