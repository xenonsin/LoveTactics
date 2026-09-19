-- Tests for what the boar and the boar lord HAND OVER -- the first `drops` lists on beasts in the game.
--
-- Nineteen beasts are placed by some encounter and not one carried a list, so every drop they have ever
-- paid came through the band (docs/drops.md's route for the TAIL of the catalogue). These two lists are
-- the first, which makes the rules worth pinning rather than assuming: the body's own kit must stay out
-- of the pool, and the depth ORDER is the whole of what "rarer" means in this system.

local Character = require("models.character")
local Item = require("models.item")
local Spoils = require("models.spoils")

local function drops(id)
    return Character.defs[id] and Character.defs[id].drops or {}
end

local function has(list, id)
    for _, v in ipairs(list) do if v == id then return true end end
    return false
end

return {
    {
        name = "the boar pays its hide and the spear somebody left in it, and no part of itself",
        fn = function()
            local list = drops("character_boar")
            assert(has(list, "armor_bristlehide"), "the hide")
            assert(has(list, "weapon_unclosing_spear"), "and the spear")
            -- docs/drops.md rule 1, and the one that would be easiest to break by accident: the tusks
            -- and the instinct are the animal, not its kit, and a list is not the place they belong.
            for _, id in ipairs({ "weapon_tusks", "ability_gore", "utility_feral_instinct" }) do
                assert(not has(list, id), id .. " is a body part and must never be on a drops list")
            end
        end,
    },
    {
        name = "the lord pays what he DOES, and never what he is",
        fn = function()
            local list = drops("character_the_unseeing")
            for _, id in ipairs({ "utility_the_wake", "utility_treeline_horn",
                                  "utility_the_last_sounder" }) do
                assert(has(list, id), id .. " is on his list")
            end
            -- His own fight -- the Call, the Iron, and the kit the Turning wears -- carries no axis at
            -- all, so the pool cannot mint any of it however the list is written (docs/bestiary.md).
            for _, id in ipairs({ "ability_the_call", "utility_the_iron_in_him",
                                  "ability_the_taking", "weapon_writhing_mass",
                                  "utility_the_turned_hide" }) do
                assert(not has(list, id), id .. " is his fight, not his loot")
                local def = Item.defs[id]
                assert(def.dropTier == nil and def.price == nil,
                    id .. " carries an axis, so the pool could reach it")
            end
        end,
    },
    {
        name = "every dropped piece can actually be found: an axis, a shelf, and no seal against it",
        fn = function()
            -- A drops entry with no `dropTier` is a row the rift can never pay, and `noSteal` or `bound`
            -- would have the pool refuse it outright -- both of which are silent failures: the list still
            -- reads correctly in the file and simply never fires.
            for _, body in ipairs({ "character_boar", "character_the_unseeing" }) do
                for _, id in ipairs(drops(body)) do
                    local def = Item.defs[id]
                    assert(def, body .. " names " .. id .. ", which does not exist")
                    assert(def.dropTier, id .. " has no dropTier, so no floor can pay it")
                    assert(not def.noSteal, id .. " is sealed to a body and can never drop")
                    assert(not def.bound, id .. " is bound to one grid and can never drop")
                    assert(def.class ~= "creature", id .. " is creature kit; the pool refuses it")
                end
            end
        end,
    },
    {
        name = "depth IS the rarity: the chase is the deepest thing on each list",
        fn = function()
            -- A floor picks a RANK before it looks at who died (Spoils.rankBand), so an item only drops
            -- on floors that reach its own tier. That makes the ORDER of these numbers the whole of the
            -- drop-rate design -- there is no per-entry weight to author, and nothing else to tune.
            local hide = Item.defs.armor_bristlehide.dropTier
            local spear = Item.defs.weapon_unclosing_spear.dropTier
            assert(spear > hide, "the boar's spear is its chase and the hide is the piece you meet")

            local wake = Item.defs.utility_the_wake.dropTier
            local horn = Item.defs.utility_treeline_horn.dropTier
            local sounder = Item.defs.utility_the_last_sounder.dropTier
            assert(sounder > horn, "the Last Sounder must be rarer than the horn -- it is the chase, "
                .. "and a shallower tier would make it the COMMON drop")
            assert(horn > wake, "and the horn is dearer than the ground he walks on")
        end,
    },
    {
        name = "the piece a body is known for is one it can be paid at",
        fn = function()
            -- Spoils.depthOf is the roll-time reading, and it is NOT the authored number: a class's own
            -- gate can push a find deeper than its worth says (tools/drop_tier.lua's "two axes, one
            -- field each"). What must hold is that the reading exists and is inside the ladder -- an
            -- entry that resolved past the deepest rank would be a row nobody ever sees.
            local Class = require("models.class")
            for _, body in ipairs({ "character_boar", "character_the_unseeing" }) do
                for _, id in ipairs(drops(body)) do
                    local depth = Spoils.depthOf(Item.defs[id])
                    assert(type(depth) == "number", id .. " has no readable depth")
                    assert(depth >= 1 and depth <= Class.CLASS_LEVEL_CAP,
                        id .. " resolves to depth " .. tostring(depth) .. ", off the ladder")
                end
            end
        end,
    },
    {
        name = "what the Last Sounder raises is CURSED -- it walks, and the floor stops mending",
        fn = function()
            -- The whole of what makes this the chase rather than three extra bodies. Asserted by
            -- raising a real corpse and then WALKING the thing: `trail` is read off the grid at
            -- Combat.enterTile, so a grant that landed in the wrong place, or an item the boar could
            -- not fit, would leave a perfectly healthy-looking risen boar and clean ground behind it.
            local Combat = require("models.combat")
            local Hazard = require("models.hazard")
            local tiles = {}
            for y = 1, 12 do
                tiles[y] = {}
                for x = 1, 12 do
                    tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
                end
            end
            local arena = { cols = 12, rows = 12, tiles = tiles, objective = { type = "killAll" } }
            local c = Combat.new(arena,
                { { char = Character.instantiate("character_rowan"), x = 3, y = 3 } },
                { { char = Character.instantiate("character_bandit"), x = 5, y = 3 } })
            Combat.openBattle(c)
            local caster, victim = c.units[1], c.units[2]

            -- A body, taken all the way cold: Combat.corpseAt refuses one still inside its window.
            Combat.dealFlatDamage(c, victim, 9999, { "physical" }, "a test")
            victim.incapacitated, victim.corpse, victim.statuses = false, true, {}

            caster.char.inventory[9] = Item.instantiate("utility_the_last_sounder")
            caster.char.stats.stamina.current = 99
            c.turn = { unit = caster, moved = false, moveCost = 0 }
            assert(Combat.useItem(c, caster, caster.char.inventory[9], 5, 3), "the sounder answers")

            local risen
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_boar" then risen = u end
            end
            assert(risen, "the corpse stands back up as a boar")
            assert(risen.side == caster.side, "on your side")
            assert(risen.summonRemaining, "and it rots away again rather than keeping")

            local carries = false
            for _, it in ipairs(Character.eachItem(risen.char)) do
                if it.id == "utility_the_wake" then carries = true end
            end
            assert(carries, "it carries the Wake -- which is the entire reason to raise it")

            -- Now WALK it. The trail is laid on the tile it steps OFF.
            local fromX, fromY = risen.x, risen.y
            c.turn = { unit = risen, moved = false, moveCost = 0 }
            Combat.moveUnit(c, risen, fromX + 1, fromY)
            assert(Hazard.at(c, fromX, fromY),
                "the ground it crossed is cursed -- a risen boar that left clean floor would be three "
                .. "extra bodies and nothing else")
        end,
    },
    {
        name = "the horn calls a boar that lapses, and cannot be sounded twice over",
        fn = function()
            -- The three conditions tools/drop_tier.lua cannot see, and between them the reason the horn
            -- is shelved two rungs under what it grades at: it is priced as a permanent extra body and
            -- is nothing of the kind. Asserted by CASTING it rather than by reading the file -- the
            -- first cut of this case scanned the source for "noClaim" and failed on the header sentence
            -- explaining why the flag is absent, which is a test measuring its own documentation.
            local Combat = require("models.combat")
            local tiles = {}
            for y = 1, 10 do
                tiles[y] = {}
                for x = 1, 10 do
                    tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
                end
            end
            local arena = { cols = 10, rows = 10, tiles = tiles, objective = { type = "killAll" } }
            local knight = { char = Character.instantiate("character_rowan"), x = 3, y = 3 }
            local c = Combat.new(arena, { knight },
                { { char = Character.instantiate("character_boar"), x = 9, y = 9 } })
            local u = c.units[1]
            u.char.inventory[9] = Item.instantiate("utility_treeline_horn")
            local horn = u.char.inventory[9]
            u.char.stats.stamina.current = 99
            c.turn = { unit = u, moved = false, moveCost = 0 }
            assert(Combat.useItem(c, u, horn, 4, 3), "the horn sounds")

            local called
            for _, other in ipairs(c.units) do
                if other.alive and other.side == u.side and other ~= u then called = other end
            end
            assert(called, "and a boar answers it")
            assert(called.summonRemaining, "the binding LAPSES -- a permanent body is a different item")
            assert(horn.activeSummon == called,
                "and the horn falls silent while that boar stands: `noClaim` is the LORD's flag, "
                .. "because calling is his whole turn and this is one item in a grid")
            assert(Combat.reservedAmount(u.char, "stamina") > 0,
                "a called boar locks away part of the bearer for as long as it stands")
        end,
    },
}
