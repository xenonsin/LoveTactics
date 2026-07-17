-- Tests for the character progression system (models/growth.lua): class growth tables, dominant-class
-- resolution, deterministic level-up gains, and the Combat.useItem usage tally that feeds it. The
-- save round trip and the Quest.complete advancement hand-off are covered in progression_spec.lua.

local Growth = require("models.growth")
local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end
local function openTurn(c, u) c.turn = { unit = u, moved = false, moveCost = 0 } end

local function weaponOf(char, id)
    for _, it in ipairs(Character.eachItem(char)) do
        if it.id == id then return it end
    end
end

return {
    -- --------------------------------------------------------------- growth tables
    {
        name = "every class has a growth table, and it only names real stats",
        fn = function()
            local knownStat = {
                health = true, mana = true, stamina = true, staminaRegen = true,
                damage = true, magicDamage = true, defense = true, magicDefense = true,
                movement = true, speed = true,
            }
            for class in pairs(Item.CLASSES) do
                local def = Growth.defs[class]
                assert(def, "class '" .. class .. "' has no data/growth file")
                assert(next(def), class .. " growth table is empty")
                for stat in pairs(def) do
                    assert(knownStat[stat], class .. " grows unknown stat '" .. stat .. "'")
                end
            end
            -- movement is deliberately never grown (grid balance).
            for class, def in pairs(Growth.defs) do
                assert(def.movement == nil, class .. " must not grow movement")
            end
        end,
    },

    -- ------------------------------------------------------------ dominant class
    {
        name = "dominantClass takes the most-cast class, breaks ties with the innate class",
        fn = function()
            local knight = Character.instantiate("character_knight") -- innate class = knight

            -- No casts yet: fall back to the innate class.
            assert(Growth.dominantClass(knight) == "knight", "empty tally uses the innate class")

            -- A clear leader wins outright, even over the innate class.
            knight.classUse = { mage = 5, fighter = 2 }
            assert(Growth.dominantClass(knight) == "mage", "argmax should win")

            -- A tie that includes the innate class resolves to it.
            knight.classUse = { mage = 3, knight = 3 }
            assert(Growth.dominantClass(knight) == "knight", "the innate class breaks a tie it is in")
        end,
    },
    {
        name = "a class-less character falls back to the neutral default when it has no casts",
        fn = function()
            local zombie = Character.instantiate("character_zombie") -- no innate class
            assert(zombie.class == nil, "the zombie declares no class")
            assert(Growth.dominantClass(zombie) == Growth.NEUTRAL_CLASS,
                "no innate + no casts falls back to the neutral default")
        end,
    },

    -- --------------------------------------------------------------- resolve
    {
        name = "resolve grows a character deterministically along its most-used class",
        fn = function()
            local knight = Character.instantiate("character_knight")
            local baseMagic = knight.stats.magicDamage
            local baseManaMax = knight.stats.mana.max
            local baseHealthMax = knight.stats.health.max

            -- Cast nothing but mage spells: the whole 1->5 climb grows as a mage.
            knight.classUse = { mage = 20 }
            local mage = Growth.defs.mage

            local summary = Growth.resolve(knight, 5)
            assert(summary, "leveling up should return a summary")
            assert(knight.level == 5, "level should track the target")
            assert(summary.fromLevel == 1 and summary.toLevel == 5, "summary spans the climb")
            assert(summary.class == "mage", "it grew as a mage")

            -- 4 level-ups (1->5) of mage growth, baked onto the base stats.
            assert(knight.stats.magicDamage == baseMagic + 4 * mage.magicDamage, "magic grew 4x")
            assert(knight.stats.mana.max == baseManaMax + 4 * mage.mana, "mana pool grew 4x")
            assert(knight.stats.health.max == baseHealthMax + 4 * mage.health, "health pool grew 4x")
            assert(summary.gains.magicDamage == 4 * mage.magicDamage, "the summary totals the gains")
        end,
    },
    {
        name = "resolve is idempotent and never runs backward",
        fn = function()
            local knight = Character.instantiate("character_knight")
            knight.classUse = { fighter = 5 }
            Growth.resolve(knight, 4)
            local magic = knight.stats.magicDamage
            local healthMax = knight.stats.health.max

            assert(Growth.resolve(knight, 4) == nil, "resolving to the same level is a no-op")
            assert(Growth.resolve(knight, 2) == nil, "resolving to a lower level is a no-op")
            assert(knight.stats.magicDamage == magic and knight.stats.health.max == healthMax,
                "a no-op resolve must not touch stats")
        end,
    },
    {
        name = "a multi-level jump re-reads the tally between levels",
        fn = function()
            -- The gains are additive per stat regardless of ordering, but the summary's `class` is the
            -- last level's dominant class -- proving each level resolves independently.
            local knight = Character.instantiate("character_knight")
            knight.classUse = { fighter = 3, mage = 1 }
            local summary = Growth.resolve(knight, 3)
            assert(summary.class == "fighter", "fighter leads, so the last level grew as fighter")
        end,
    },

    -- ---------------------------------------------------- usage tally (recordUse)
    {
        name = "recordUse tallies class casts, ignoring a nil class",
        fn = function()
            local knight = Character.instantiate("character_knight")
            Character.recordUse(knight, "fighter")
            Character.recordUse(knight, "fighter")
            Character.recordUse(knight, "mage")
            Character.recordUse(knight, nil) -- the unarmed fallback has no class
            assert(knight.classUse.fighter == 2, "fighter counted twice")
            assert(knight.classUse.mage == 1, "mage counted once")
        end,
    },
    {
        name = "a party member's weapon strike feeds its class tally; an enemy's does not",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_knight", 2, 2) }, { unit("character_bandit", 3, 2) })
            local knight, bandit = c.units[1], c.units[2]

            -- Deliberately an OFF-CLASS weapon: a knight swinging a Colosseum hammer. The tally must
            -- follow the ITEM's class, not the character's own -- with a knight-class weapon in a
            -- knight's hands, a tally that wrongly read char.class would pass this by coincidence.
            local hammer = Item.instantiate("weapon_iron_hammer")
            Character.addItem(knight.char, hammer)
            assert(hammer.class == "fighter", "the hammer is a fighter weapon")
            assert(knight.char.class == "knight", "carried by a knight -- the two must differ")

            openTurn(c, knight)
            local ok = Combat.useItem(c, knight, hammer, bandit.x, bandit.y)
            assert(ok, "the strike should resolve")
            assert(knight.char.classUse and knight.char.classUse.fighter == 1,
                "a player strike bumps the tally of the WEAPON's class")
            assert(not knight.char.classUse.knight, "and never the wielder's own class")

            -- The bandit striking back (AI-controlled) must not accrue a tally on its transient char.
            local bWeapon = Combat.defaultWeapon(bandit.char)
            if bWeapon and bWeapon.activeAbility then
                openTurn(c, bandit)
                Combat.useItem(c, bandit, bWeapon, knight.x, knight.y)
            end
            assert(not (bandit.char.classUse and next(bandit.char.classUse)),
                "an enemy's cast is not tallied")
        end,
    },
}
