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
            knight.technique = { mage = 5, fighter = 2 }
            assert(Growth.dominantClass(knight) == "mage", "argmax should win")

            -- A tie that includes the innate class resolves to it.
            knight.technique = { mage = 3, knight = 3 }
            assert(Growth.dominantClass(knight) == "knight", "the innate class breaks a tie it is in")

            -- A tie between two classes the character was NOT born into leaves that rule unfired,
            -- and the ledger is a keyed table -- so without a stated tie-break the winner is whichever
            -- key the hash happened to yield. The title is what a player reads off the sheet, so the
            -- same character could be described differently on two machines. Settled by name: not
            -- because alphabetical order means anything, but because it is an answer.
            knight.technique = { mage = 4, fighter = 4 }
            assert(Growth.dominantClass(knight) == "fighter",
                "a tie outside the innate class settles by name")

            -- Stated the other way round, so the assertion cannot pass by luck of insertion order.
            local other = Character.instantiate("character_rowan")
            other.technique = { fighter = 4, mage = 4 }
            assert(Growth.dominantClass(other) == "fighter",
                "the same tie settles the same way whichever was banked first")
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
            -- apportions is the ledger's delta SINCE THE LAST LEVEL, not the career total the title
            -- reads -- and with a single key the blend is that key at 100%, which is the old behaviour
            -- exactly.
            knight.technique = { mage = 20 }
            local mage = Growth.defs.mage

            local summary = Growth.resolve(knight, 5)
            assert(summary, "leveling up should return a summary")
            assert(knight.level == 5, "level should track the target")
            assert(summary.fromLevel == 1 and summary.toLevel == 5, "summary spans the climb")
            assert(summary.class == "mage", "it grew as a mage")
            assert(summary.shares.mage == 1, "one house cast means one house credited, whole")

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
            knight.technique = { fighter = 5 }
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
        name = "a multi-level jump apportions every level by the same shares, and checkpoints once",
        fn = function()
            local knight = Character.instantiate("character_rowan")
            knight.technique = { fighter = 3, mage = 1 }
            local summary = Growth.resolve(knight, 3)
            assert(summary.class == "fighter", "fighter led the stretch, so it heads the summary")
            assert(summary.levels == 2, "the summary counts the levels it credited")
            assert(math.abs(summary.shares.fighter - 0.75) < 1e-9
                and math.abs(summary.shares.mage - 0.25) < 1e-9,
                "three fighter casts to one mage is a 75/25 split, not a clean sweep")

            -- The ledger books SHARES, so two levels at 75/25 are 1.5 and 0.5 -- not two whole levels
            -- to the winner. The mage casts are credited rather than discarded, which is the point.
            assert(math.abs(knight.growthBy.fighter - 1.5) < 1e-9
                and math.abs(knight.growthBy.mage - 0.5) < 1e-9,
                "the ledger splits the jump the way the stats were split")

            -- Consumed once, not per level -- and expressed as a checkpoint, because the ledger is also
            -- the wallet and the career title and must not be wiped to pay for a level.
            assert(knight.technique.fighter == 3, "the ledger itself is untouched")
            assert(knight.techniqueAtLevel.fighter == 3 and knight.techniqueAtLevel.mage == 1,
                "the checkpoint caught up to it, so the next level reads from zero again")
            assert(next(Growth.sinceLevel(knight)) == nil, "nothing is outstanding right after a level")
        end,
    },
    {
        -- The character sheet forecasts the coming level on every frame it is open, so this is the one
        -- reading in the module that must be BOTH exact and free. Exact because a forecast that missed
        -- would look like a bug in the level-up rather than in the forecast; free because a preview that
        -- banked its remainder would advance a character by being looked at.
        name = "previewLevel is exactly the level that lands, and costs nothing to ask",
        fn = function()
            local char = Character.instantiate("character_rowan")
            char.technique = { fighter = 3, mage = 1 }

            local forecast = Growth.previewLevel(char)
            assert(next(forecast), "a 75/25 split must forecast something")

            -- Asking must not answer differently the second time, and must not move the character.
            local before = { level = char.level, health = char.stats.health.max,
                damage = char.stats.damage, carry = char.growthCarry }
            for _ = 1, 5 do Growth.previewLevel(char) end
            assert(char.level == before.level and char.stats.health.max == before.health
                and char.stats.damage == before.damage and char.growthCarry == before.carry,
                "six forecasts left the character exactly where it was")
            for stat, amount in pairs(Growth.previewLevel(char)) do
                assert(forecast[stat] == amount, "and the forecast itself is stable: " .. stat)
            end

            -- Now let it land. Every point promised arrives, and nothing arrives that was not promised.
            local summary = Growth.resolve(char, char.level + 1)
            for stat, amount in pairs(summary.gains) do
                assert(forecast[stat] == amount, string.format(
                    "%s landed %s, forecast said %s", stat, amount, tostring(forecast[stat])))
            end
            for stat, amount in pairs(forecast) do
                assert(summary.gains[stat] == amount, stat .. " was promised and did not land")
            end

            -- The CARRY is what makes this worth pinning: a stat earning half a point a level arrives
            -- every OTHER level, so the very next forecast is allowed to differ from the one just spent.
            -- What it may never do is disagree with the level that follows it.
            local next2 = Growth.previewLevel(char)
            local landed = Growth.resolve(char, char.level + 1)
            for stat, amount in pairs(landed.gains) do
                assert(next2[stat] == amount, "the second level was forecast too: " .. stat)
            end

            -- Cast nothing, and a level still arrives on prestige -- Growth.shares falls back to the
            -- innate class, so the forecast is of that table rather than of nothing at all.
            local idle = Character.instantiate("character_rowan")
            assert(next(Growth.previewLevel(idle)) ~= nil,
                "an untouched character still forecasts the level prestige will hand it")
        end,
    },
    {
        -- The headline property of proportional crediting: a level split between two houses is
        -- genuinely half of each, and the halves that do not divide evenly are CARRIED rather than
        -- rounded away. Two levels at 50/50 must land exactly where one level of each would.
        name = "a blended level credits both houses, and the carry pays out in full",
        fn = function()
            local blended = Character.instantiate("character_rowan")
            blended.technique = { knight = 10, mage = 10 }
            Growth.resolve(blended, 3) -- two levels, each split 50/50

            local split = Character.instantiate("character_rowan")
            split.technique = { knight = 10 }
            Growth.resolve(split, 2)                -- one whole knight level
            split.technique.mage = 10
            Growth.resolve(split, 3)                -- one whole mage level

            for _, stat in ipairs({ "damage", "magicDamage", "defense", "magicDefense" }) do
                assert(blended.stats[stat] == split.stats[stat],
                    "two 50/50 levels must equal one of each for " .. stat
                        .. " (" .. tostring(blended.stats[stat]) .. " vs " .. tostring(split.stats[stat]) .. ")")
            end
            for _, stat in ipairs({ "health", "mana", "stamina" }) do
                assert(blended.stats[stat].max == split.stats[stat].max,
                    "and for the " .. stat .. " pool")
            end
        end,
    },
    {
        -- Float addition is not associative, so summing shares over `pairs()` would make the same
        -- history grow differently depending on hash order. models/build.lua promises (id, ledger,
        -- level) rebuilds the identical character anywhere and state_hash compares peers mid-duel, so
        -- this is the property both of those rest on.
        name = "the same ledger grows the same stats however its keys were inserted",
        fn = function()
            local function grownFrom(pairsInOrder)
                local char = Character.instantiate("character_rowan")
                char.technique = {}
                for _, entry in ipairs(pairsInOrder) do char.technique[entry[1]] = entry[2] end
                Growth.resolve(char, 9)
                return char
            end

            local forward = grownFrom({ { "knight", 7 }, { "mage", 5 }, { "rogue", 3 }, { "priest", 2 } })
            local backward = grownFrom({ { "priest", 2 }, { "rogue", 3 }, { "mage", 5 }, { "knight", 7 } })

            for stat, amount in pairs(forward.growth) do
                assert(backward.growth[stat] == amount,
                    "insertion order changed " .. stat .. ": "
                        .. tostring(amount) .. " vs " .. tostring(backward.growth[stat]))
            end
            assert(forward.stats.health.max == backward.stats.health.max, "and the health pool")
        end,
    },
    {
        -- Survivability is linear in a growth table, so a convex combination of tables that each clear
        -- the floor clears it too. That is why blending cannot reopen the hole the floor exists to
        -- close -- asserted here over the real tables rather than argued only in a comment.
        name = "a blend of floor-clearing tables clears the floor itself",
        fn = function()
            local ids = {}
            for id in pairs(Growth.defs) do ids[#ids + 1] = id end
            table.sort(ids)

            for _, magical in ipairs({ false, true }) do
                for i = 1, #ids do
                    local a, b = Growth.defs[ids[i]], Growth.defs[ids[(i % #ids) + 1]]
                    -- The worst case for a blend is the lower of the two tables, so an even split can
                    -- never fall under it -- and neither table is under the floor to begin with.
                    local blended = 0.5 * Growth.survivability(a, magical)
                        + 0.5 * Growth.survivability(b, magical)
                    assert(blended >= Growth.ENEMY_DAMAGE_GROWTH,
                        "a 50/50 blend of " .. ids[i] .. " and " .. ids[(i % #ids) + 1]
                            .. " falls under the survivability floor")
                end
            end
        end,
    },
    {
        -- The property the checkpoint exists for: the price of changing direction is one level's worth
        -- of casting, and it does NOT rise with the character's history. Apportioning against the
        -- career total instead would make a veteran pay for its whole past before a new house took a
        -- level.
        name = "turning to a new class costs the same at level 40 as at level 3",
        fn = function()
            local function turnsAt(level)
                local char = Character.instantiate("character_rowan")
                -- A long career spent as something else entirely -- and already accounted for, which
                -- is what the checkpoint records.
                char.technique = { knight = 200, mage = 200 }
                char.techniqueAtLevel = { knight = 200, mage = 200 }
                char.growthBy = { knight = level - 1 }
                char.level = level
                -- One level's worth of rogue casting, and nothing more.
                char.technique.rogue = 4
                return Growth.resolve(char, level + 1)
            end

            assert(turnsAt(3).shares.rogue == 1, "a young character turns on one level's casting")
            assert(turnsAt(40).shares.rogue == 1,
                "and so does a veteran -- history must not price the turn")
        end,
    },
    {
        name = "the per-class ledger accumulates across a mixed career and never runs backward",
        fn = function()
            local char = Character.instantiate("character_rowan")

            char.technique = { knight = 5 }
            Growth.resolve(char, 2)
            char.technique.knight = 10
            Growth.resolve(char, 3)
            char.technique.mage = 5
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

    -- ---------------------------------------------------- the ledger (recordTechnique)
    {
        name = "recordTechnique banks under a key, ignoring a nil key and a non-positive amount",
        fn = function()
            local knight = Character.instantiate("character_rowan")
            Character.recordTechnique(knight, "fighter", 2)
            Character.recordTechnique(knight, "fighter", 2)
            Character.recordTechnique(knight, "mage", 2)
            Character.recordTechnique(knight, nil, 2) -- the unarmed fallback has no class
            Character.recordTechnique(knight, "rogue", 0)
            assert(knight.technique.fighter == 4, "fighter banked twice")
            assert(knight.technique.mage == 2, "mage banked once")
            assert(knight.technique.rogue == nil, "a zero award writes no key")
        end,
    },
    {
        name = "earned, spendable and since-level are three readings of the one ledger",
        fn = function()
            local char = Character.instantiate("character_rowan")
            Character.recordTechnique(char, "knight", 40)

            assert(Character.techniqueAvailable(char, "knight") == 40, "all of it is spendable at first")
            assert(Character.techniqueSinceLevel(char, "knight") == 40, "and all of it is unspent growth")

            -- Spending is what the merge had to make safe: it must move the wallet and NOTHING else.
            char.techniqueSpent = { knight = 30 }
            assert(char.technique.knight == 40, "earned is untouched by spending")
            assert(Character.techniqueAvailable(char, "knight") == 10, "the wallet fell")
            assert(Character.techniqueSinceLevel(char, "knight") == 40,
                "and the growth reading did not -- forging must never cost a level")

            -- The checkpoint moves the growth reading and nothing else.
            char.techniqueAtLevel = { knight = 25 }
            assert(Character.techniqueSinceLevel(char, "knight") == 15, "measured above the checkpoint")
            assert(Character.techniqueAvailable(char, "knight") == 10, "the wallet is unaffected by it")
        end,
    },
    {
        name = "a party member's weapon strike banks its item's house; an enemy's does not",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2) }, { unit("character_bandit", 3, 2) })
            local knight, bandit = c.units[1], c.units[2]

            -- Deliberately an OFF-CLASS weapon: a knight swinging a Colosseum hammer. The ledger must
            -- follow the ITEM's class, not the character's own -- with a knight-class weapon in a
            -- knight's hands, a ledger that wrongly read char.class would pass this by coincidence.
            local hammer = Item.instantiate("weapon_iron_hammer")
            Character.addItem(knight.char, hammer)
            assert(hammer.class == "fighter", "the hammer is a fighter weapon")
            assert(knight.char.class == "knight", "carried by a knight -- the two must differ")

            openTurn(c, knight)
            local ok = Combat.useItem(c, knight, hammer, bandit.x, bandit.y)
            assert(ok, "the strike should resolve")
            assert(knight.char.technique and knight.char.technique.fighter > 0,
                "a player strike banks under the WEAPON's house")
            assert(not knight.char.technique.knight, "and never the wielder's own class")

            -- The bandit striking back (AI-controlled) must not accrue anything on its transient char.
            local bWeapon = Combat.defaultWeapon(bandit.char)
            if bWeapon and bWeapon.activeAbility then
                openTurn(c, bandit)
                Combat.useItem(c, bandit, bWeapon, knight.x, knight.y)
            end
            assert(not (bandit.char.technique and next(bandit.char.technique)),
                "an enemy's cast banks nothing")
        end,
    },

    -- --------------------------------------------------- banking in battle (one award, one floater)
    {
        name = "every house banks technique, capped per battle, and one action arms one floater",
        fn = function()
            local Discipline = require("models.discipline")
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2) }, { unit("character_bandit", 3, 2) })
            local knight, bandit = c.units[1], c.units[2]

            -- A hand-rolled discipline probe rather than a shelf item: this test is about the BANKING
            -- rule, and picking a real ninja blade would couple it to whatever the shelf happens to
            -- stock. Any real discipline id will do.
            local disciplineId = next(Discipline.defs)
            assert(disciplineId, "there is at least one discipline")
            local probe = { discipline = disciplineId }

            local first = Combat.awardTechnique(c, knight, probe)
            assert(first == Discipline.TECHNIQUE_PER_ACTION, "one action banks one action's worth")
            assert(knight.char.technique[disciplineId] == first, "onto the caster's own ledger")
            assert(c.techniqueEarned[disciplineId] == first, "and onto the fight's ledger")
            assert(c.techniqueAward and c.techniqueAward.unit == knight, "the floater one-shot is armed")

            -- PLAIN CLASS STOCK banks too -- the opening-campaign case that used to bank and float
            -- nothing at all, since only 233 of 638 item files declare a discipline and disciplines are
            -- locked content. A discipline item still banks its discipline rather than its class.
            assert(Combat.awardTechnique(c, knight, { class = "fighter" })
                == Discipline.TECHNIQUE_PER_ACTION, "a plain class cast banks its class")
            assert(knight.char.technique.fighter == Discipline.TECHNIQUE_PER_ACTION, "onto the same ledger")
            assert(c.techniqueAward.discipline == "fighter", "and arms the same one floater")

            -- Run one key's battle ledger to the cap: banking stops while play carries on. The cap now
            -- bounds the level-up reading too, since they are one number.
            local guard = 0
            while (c.techniqueEarned[disciplineId] or 0) < Discipline.TECHNIQUE_PER_BATTLE and guard < 1000 do
                Combat.awardTechnique(c, knight, probe)
                guard = guard + 1
            end
            assert(c.techniqueEarned[disciplineId] == Discipline.TECHNIQUE_PER_BATTLE, "the ledger stops at the cap")
            assert(Combat.awardTechnique(c, knight, probe) == 0, "and further casts bank nothing")
            assert(c.techniqueAward == nil, "a capped-out cast floats nothing rather than a zero")
            assert(knight.char.technique[disciplineId] == Discipline.TECHNIQUE_PER_BATTLE,
                "the ledger never exceeds what the fight was allowed to pay")

            -- The cap is PER KEY, so a capped discipline does not stop a different house banking.
            assert(Combat.awardTechnique(c, knight, { class = "priest" }) > 0,
                "another house still banks after the first has capped")

            -- A class-less, discipline-less item (a natural weapon) banks nothing and floats nothing.
            assert(Combat.awardTechnique(c, knight, { name = "claws" }) == 0, "an untagged item is not a house")
            assert(c.techniqueAward == nil, "and arms nothing")

            -- ...and an enemy is never on the ladder at all, through the real useItem path.
            local hammer = Item.instantiate("weapon_iron_hammer")
            Character.addItem(bandit.char, hammer)
            openTurn(c, bandit)
            Combat.useItem(c, bandit, hammer, knight.x, knight.y)
            assert(not (bandit.char.technique and next(bandit.char.technique)), "an enemy banks no technique")
        end,
    },
    {
        -- The same ledger, split by whose hand banked it: what the victory panel groups its rows under
        -- (ui/panels/battle_summary.lua). Technique accrues per BODY and the Forge bills one body for
        -- it, so a bare "+6 Rogue" on the summary named a number nobody owned.
        name = "the fight's technique ledger records which body banked each house",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 2, 2), unit("character_saber", 2, 4) },
                { unit("character_bandit", 5, 2) })
            local rowan, saber = c.units[1], c.units[2]

            Combat.awardTechnique(c, rowan, { class = "knight" })
            Combat.awardTechnique(c, saber, { class = "rogue" })
            Combat.awardTechnique(c, rowan, { class = "fighter" })
            Combat.awardTechnique(c, rowan, { class = "knight" })

            local ledger = c.techniqueByActor
            assert(#ledger == 2, "two party bodies banked, so two blocks")
            assert(ledger[1].char == rowan.char and ledger[1].name == rowan.char.name,
                "in the order they first banked, each carrying the name the panel prints")

            local knight, fighter
            for _, house in ipairs(ledger[1].houses) do
                if house.key == "knight" then knight = house end
                if house.key == "fighter" then fighter = house end
            end
            assert(#ledger[1].houses == 2, "a body's houses are one row each, not one per cast")
            assert(knight.amount == fighter.amount * 2, "and each row totals that body's casts in it")
            assert(#ledger[2].houses == 1 and ledger[2].houses[1].key == "rogue",
                "the second body carries only what it earned")

            -- The flat ledger the per-battle cap is measured against still totals across the field.
            assert(c.techniqueEarned.knight == knight.amount, "the two readings agree on a house")
        end,
    },
    {
        -- The property the earned/spent split exists for, end to end: paying a real Forge bill must not
        -- move the career title or what the next level-up will apply.
        name = "forging spends the wallet without touching the title or the pending growth",
        fn = function()
            local Discipline = require("models.discipline")
            local char = Character.instantiate("character_rowan")
            Character.recordTechnique(char, "mage", 60)
            Character.recordTechnique(char, "knight", 20)
            local player = { roster = { char } }

            assert(Growth.dominantClass(char) == "mage", "mage leads the career")
            local beforeShares = Growth.shares(char)

            local billed = Discipline.spendTechnique(player, "mage", 50)
            assert(billed == char, "the bill came off the only holder")
            assert(Discipline.technique(player, "mage") == 10, "the wallet fell by what was billed")
            assert(Growth.dominantClass(char) == "mage", "the title did not move")

            local afterShares = Growth.shares(char)
            for key, share in pairs(beforeShares) do
                assert(afterShares[key] == share, "the level-up reading did not move for " .. key)
            end
        end,
    },
}
