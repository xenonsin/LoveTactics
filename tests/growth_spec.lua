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

    {
        -- The invariant that lets enemies scale 1:1 with the player at any LEVEL_CAP. Mitigation is
        -- subtractive with a floor of 1, so a class gaining less survivability per level than a scaled
        -- enemy gains attack gets relatively frailer forever and is eventually one-shot. See the long
        -- note on Growth.ENEMY_DAMAGE_GROWTH.
        --
        -- A failure here is not "retune this number" -- it means that class has an expiry level.
        name = "every growth table outpaces a scaled enemy's attack, on both damage channels",
        fn = function()
            local floor = Growth.ENEMY_DAMAGE_GROWTH
            for class, def in pairs(Growth.defs) do
                for _, channel in ipairs({ { false, "physical", "defense" }, { true, "magical", "magicDefense" } }) do
                    local magical, name, stat = channel[1], channel[2], channel[3]
                    assert(Growth.meetsSurvivabilityFloor(def, magical),
                        string.format(
                            "%s buys only %d %s survivability per level (health +%d, %s +%d) but a scaled "
                            .. "enemy gains +%d attack -- it is one-shot eventually. Raise health or %s.",
                            class, Growth.survivability(def, magical), name,
                            def.health or 0, stat, def[stat] or 0, floor, stat))
                end
            end
        end,
    },

    -- ------------------------------------------------------------ dominant class
    {
        name = "dominantClass takes the most-cast class, breaks ties with the innate class",
        fn = function()
            local knight = Character.instantiate("character_rowan") -- innate class = knight

            -- No casts yet: fall back to the innate class.
            assert(Growth.dominantClass(knight) == "knight", "empty tally uses the innate class")

            -- A clear leader wins outright, even over the innate class.
            knight.classUse = { mage = 5, fighter = 2 }
            assert(Growth.dominantClass(knight) == "mage", "argmax should win")

            -- A tie that includes the innate class resolves to it.
            knight.classUse = { mage = 3, knight = 3 }
            assert(Growth.dominantClass(knight) == "knight", "the innate class breaks a tie it is in")

            -- A tie between two classes the character was NOT born into leaves that rule unfired,
            -- and the tally is a keyed table -- so without a stated tie-break the winner is whichever
            -- key the hash happened to yield. That decides which growth table the level-up applies,
            -- so the same character could come out of the same level with different stats. Settled
            -- by name: not because alphabetical order means anything, but because it is an answer.
            knight.classUse = { mage = 4, fighter = 4 }
            assert(Growth.dominantClass(knight) == "fighter",
                "a tie outside the innate class settles by name")

            -- Stated the other way round, so the assertion cannot pass by luck of insertion order.
            local other = Character.instantiate("character_rowan")
            other.classUse = { fighter = 4, mage = 4 }
            assert(Growth.dominantClass(other) == "fighter",
                "the same tie settles the same way whichever was tallied first")
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
            local knight = Character.instantiate("character_rowan")
            local baseMagic = knight.stats.magicDamage
            local baseManaMax = knight.stats.mana.max
            local baseHealthMax = knight.stats.health.max

            -- Cast nothing but mage spells: the whole 1->5 climb grows as a mage. What a level-up
            -- applies is read off `classUseSinceLevel` -- the casts banked since the last level -- not
            -- off the career-long `classUse` the displayed title uses.
            knight.classUseSinceLevel = { mage = 20 }
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
            local knight = Character.instantiate("character_rowan")
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
        name = "a multi-level jump is credited as one batch to the class that led it",
        fn = function()
            local knight = Character.instantiate("character_rowan")
            knight.classUseSinceLevel = { fighter = 3, mage = 1 }
            local summary = Growth.resolve(knight, 3)
            assert(summary.class == "fighter", "fighter led the stretch, so the batch grew as fighter")
            assert(summary.levels == 2, "the summary counts the levels it credited")
            assert(knight.growthBy.fighter == 2, "and the ledger records both against fighter")
            assert(next(knight.classUseSinceLevel) == nil, "the reading is consumed once, not per level")
        end,
    },
    {
        -- The property the reset exists for: the price of changing direction is one level's worth of
        -- casting, and it does NOT rise with the character's history. Crediting against the cumulative
        -- tally instead would make a veteran pay for its whole past before a new class took a level.
        name = "turning to a new class costs the same at level 40 as at level 3",
        fn = function()
            local function turnsAt(level)
                local char = Character.instantiate("character_rowan")
                -- A long career spent as something else entirely.
                char.classUse = { knight = 200, mage = 200 }
                char.growthBy = { knight = level - 1 }
                char.level = level
                -- One level's worth of rogue casting, and nothing more.
                char.classUseSinceLevel = { rogue = 4 }
                return Growth.resolve(char, level + 1)
            end

            assert(turnsAt(3).class == "rogue", "a young character turns on one level's casting")
            assert(turnsAt(40).class == "rogue",
                "and so does a veteran -- history must not price the turn")
        end,
    },
    {
        name = "the per-class ledger accumulates across a mixed career and never runs backward",
        fn = function()
            local char = Character.instantiate("character_rowan")

            char.classUseSinceLevel = { knight = 5 }
            Growth.resolve(char, 2)
            char.classUseSinceLevel = { knight = 5 }
            Growth.resolve(char, 3)
            char.classUseSinceLevel = { mage = 5 }
            local health = char.stats.health.max
            Growth.resolve(char, 4)

            assert(char.growthBy.knight == 2 and char.growthBy.mage == 1,
                "the ledger splits the career by what was actually cast")
            assert(char.stats.health.max >= health,
                "a level-up may never cost a character health it had already earned")

            -- Idempotent: re-resolving at the same level credits nothing.
            assert(Growth.resolve(char, 4) == nil, "no advance, no summary")
            assert(char.growthBy.mage == 1, "and no second credit")
        end,
    },

    -- ---------------------------------------------------- usage tally (recordUse)
    {
        name = "recordUse tallies class casts, ignoring a nil class",
        fn = function()
            local knight = Character.instantiate("character_rowan")
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
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2) }, { unit("character_bandit", 3, 2) })
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
