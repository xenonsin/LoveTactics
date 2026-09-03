-- Tests for the character progression system (models/growth.lua): class growth tables, dominant-class
-- resolution, deterministic level-up gains, and the Combat.useItem usage tally that feeds it. The
-- save round trip and the Quest.complete advancement hand-off are covered in progression_spec.lua.

local Growth = require("models.growth")
local Character = require("models.character")
local Item = require("models.item")
local Class = require("models.class") -- roots(): the seven, since the fold (docs/class-fold.md)
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
                movement = true, speed = true, skill = true, luck = true,
            }
            for class in pairs(Class.roots()) do
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
            -- Nor are skill and luck, for the same KIND of reason movement isn't, though the mechanism
            -- differs. Movement is held still because the grid is a fixed size. Accuracy is held still
            -- because it is read as a DIFFERENCE: hit% is Hit minus Avoid, and enemies scale with the
            -- player (Growth.ENEMY_DAMAGE_GROWTH). A skill table and a luck table climbing on both
            -- sides of that subtraction cancel exactly -- the numbers would move every level and the
            -- hit chance would not, which is a stat that costs a save field and buys no decision.
            -- Worse, they would not cancel forever: on a 0-10 band, even a tenth of a point per level
            -- leaves the band inside one career, and the clamp would quietly eat the overflow.
            --
            -- So skill and luck are what a body IS, not what it becomes -- authored per blueprint and
            -- moved only by gear and statuses, which is where an accuracy DECISION belongs. See
            -- docs/accuracy.md and Character.ACCURACY_STATS.
            for class, def in pairs(Growth.defs) do
                assert(def.skill == nil, class .. " must not grow skill")
                assert(def.luck == nil, class .. " must not grow luck")
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
    {
        -- The offensive mirror of the case above, and it went unwritten for most of this project's
        -- life. Mitigation subtracts, so the argument runs identically in both directions: a class
        -- whose ATTACK grows slower than the enemy's ARMOUR gets relatively weaker every level and its
        -- damage converges on the floor of 1. `knight` was losing ~0.8 a level against knight-stock
        -- armour -- and the knight shelf is the sword, spear and mace the starting company carries --
        -- while `bulwark` and `sentinel` gained nothing offensively at all, forever.
        --
        -- The bar is LETHALITY_FLOOR (get better at all), not ENEMY_ARMOR_GROWTH (keep pace). A wall
        -- is allowed to lose ground on the stat sheet because its WEAPON does not: docs/balance.md
        -- holds an item's magnitude to its archetype's level at the gate that opens it. What is
        -- forbidden is a table that can never improve, whatever the player does with it.
        --
        -- One channel, not both: a class needs one way to hurt things. A mage's `damage` is 0 and that
        -- is correct, not a gap.
        name = "every growth table gets better at hurting things, on at least one channel",
        fn = function()
            for class, def in pairs(Growth.defs) do
                assert(Growth.meetsLethalityFloor(def), string.format(
                    "%s gains %d attack per level (damage +%d, magicDamage +%d) -- it never hits harder,"
                    .. " so against armour climbing ~%d a level its damage converges on the floor."
                    .. " Raise damage or magicDamage to at least %d.",
                    class, Growth.lethality(def), def.damage or 0, def.magicDamage or 0,
                    Growth.ENEMY_ARMOR_GROWTH, Growth.LETHALITY_FLOOR))
            end
        end,
    },

    -- ------------------------------------------------------------ the declared job
    {
        name = "jobOf takes the declaration, then the innate class, then the neutral default",
        fn = function()
            local knight = Character.instantiate("character_rowan") -- innate class = knight

            -- Undeclared: the blueprint's own class, which is what this body has been growing as all
            -- along. A fresh recruit is never left standing still waiting to be told what it is.
            assert(Growth.jobOf(knight) == "knight", "an undeclared body grows as its innate class")

            -- A declaration wins outright, and nothing else is consulted. This is the whole of the
            -- change: growth used to be a reading of what the body had swung, so the ledger below could
            -- move it. It cannot now, and that is the point -- a body's growth is a decision.
            knight.job = "mage"
            knight.technique = { fighter = 400 }
            assert(Growth.jobOf(knight) == "mage", "the declaration beats both the ledger and the innate class")

            -- A declaration naming no real growth table falls through rather than crashing a level-up:
            -- an id can go stale under a rename, and a body that cannot level is worse than one that
            -- levels as the default.
            knight.job = "no_such_job"
            assert(Growth.jobOf(knight) == "knight", "an unknown job falls back to the innate class")
        end,
    },
    {
        name = "a class-less character falls back to the neutral default",
        fn = function()
            local zombie = Character.instantiate("character_zombie") -- no innate class
            assert(zombie.class == nil, "the zombie declares no class")
            assert(Growth.jobOf(zombie) == Growth.NEUTRAL_CLASS,
                "no declaration and no innate class falls back to the neutral default")
        end,
    },

    -- --------------------------------------------------------------- resolve
    {
        name = "resolve grows a character along the job it is declared in, whatever it has been swinging",
        fn = function()
            local knight = Character.instantiate("character_rowan")
            local baseMagic = knight.stats.magicDamage
            local baseManaMax = knight.stats.mana.max
            local baseHealthMax = knight.stats.health.max

            -- Declared a mage and swinging knight gear the whole way. The climb is a mage's, and the
            -- ledger is deliberately loaded the other way to prove it: growth reads the badge, and the
            -- hands are a different question entirely (they set the class LEVEL -- see
            -- Class.classLevel -- which scales what the gear does rather than how the body grows).
            knight.job = "mage"
            knight.technique = { knight = 400 }
            local mage = Growth.defs.mage

            local summary = Growth.resolve(knight, 5)
            assert(summary, "leveling up should return a summary")
            assert(knight.level == 5, "level should track the target")
            assert(summary.fromLevel == 1 and summary.toLevel == 5, "summary spans the climb")
            assert(summary.class == "mage", "it grew as a mage, because that is what it was declared as")
            assert(summary.levels == 4, "the summary counts the levels it credited")

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
        name = "a multi-level jump applies the job's table once per level, and checkpoints once",
        fn = function()
            local knight = Character.instantiate("character_rowan")
            knight.job = "fighter"
            knight.technique = { fighter = 3, mage = 1 }
            local fighter = Growth.defs.fighter
            local baseHealth = knight.stats.health.max

            local summary = Growth.resolve(knight, 3)
            assert(summary.class == "fighter", "the declared job heads the summary")
            assert(summary.levels == 2, "the summary counts the levels it credited")
            assert(knight.stats.health.max == baseHealth + 2 * fighter.health,
                "two levels are two whole applications of one table, not one batched application")

            -- The checkpoint is caught up ONCE rather than per level, and it is expressed as a snapshot
            -- rather than a wipe: the ledger is also the wallet and the class level, so clearing it
            -- would pay for a level by deleting money and progression.
            assert(knight.technique.fighter == 3, "the ledger itself is untouched")
            assert(knight.techniqueAtLevel.fighter == 3 and knight.techniqueAtLevel.mage == 1,
                "the checkpoint caught up to it, so the next level reads from zero again")
            assert(Character.techniqueSinceLevel(knight, "fighter") == 0,
                "nothing is outstanding right after a level")
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
        -- The ladder the class level is read off (Class.classLevel), asserted from the growth
        -- side because this is where the two systems meet: the badge decides how a body GROWS, the
        -- ladder decides what its gear DOES, and they are read off different fields on purpose.
        name = "the class level climbs the technique ladder and never runs backward",
        fn = function()
            local Class = require("models.class")
            local char = Character.instantiate("character_rowan")

            assert(Class.classLevel(char, "knight") == 0, "a body with no technique holds no level")

            -- One short of the first rung is still nought: the rungs are the whole of the ladder, and a
            -- level that arrived early would make the anchor below meaningless.
            char.technique = { knight = Class.classLevelCost(1) - 1 }
            assert(Class.classLevel(char, "knight") == 0, "one short of a rung has not reached it")
            char.technique.knight = Class.classLevelCost(1)
            assert(Class.classLevel(char, "knight") == 1, "the rung is reached exactly at its cost")

            -- The cap holds against any amount, so a body that kept swinging past mastery does not
            -- climb off the end of a ladder Combat.classScaled multiplies against.
            char.technique.knight = 10 ^ 6
            assert(Class.classLevel(char, "knight") == Class.CLASS_LEVEL_CAP,
                "the ladder stops at its cap")

            -- Forging must never cost progression. The Forge bills `techniqueSpent`, which is a
            -- separate table for exactly this reason -- billing the career figure would make paying for
            -- gear un-grow the body that paid.
            char.techniqueSpent = { knight = 10 ^ 6 }
            assert(Class.classLevel(char, "knight") == Class.CLASS_LEVEL_CAP,
                "spending the whole bank leaves the class level where it was")
        end,
    },
    {
        -- THE ANCHOR, and the one number in the ladder that is not arbitrary: mastering one class is
        -- one committed descent. Technique is TECHNIQUE_PER_ACTION an action capped at
        -- TECHNIQUE_PER_BATTLE a fight, and a full descent is about seventy fights -- so a body that
        -- commits to one house for a whole run banks in the neighbourhood of what the top rung costs.
        -- Re-tune either constant without re-reading this and the ladder silently stops meaning
        -- anything.
        name = "mastering one class costs about one committed descent",
        fn = function()
            local Class = require("models.class")
            local FIGHTS = 70
            local banked = Class.TECHNIQUE_PER_BATTLE * FIGHTS
            local mastery = Class.classLevelCost(Class.CLASS_LEVEL_CAP)

            assert(mastery <= banked,
                "a committed run must be able to reach mastery: " .. mastery .. " > " .. banked)
            assert(mastery >= banked * 0.35,
                "and must not be reachable in a third of one: " .. mastery .. " vs " .. banked)

            -- Triangular, not flat: the eighth rung must cost more than the first, or committing stops
            -- being a decision after the second one.
            local first = Class.classLevelCost(1)
            local last = mastery - Class.classLevelCost(Class.CLASS_LEVEL_CAP - 1)
            assert(last > first * 2, "the top rung must cost meaningfully more than the bottom one")
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
            local Class = require("models.class")
            local c = Combat.new(arena(6, 6), { unit("character_rowan", 2, 2) }, { unit("character_bandit", 3, 2) })
            local knight, bandit = c.units[1], c.units[2]

            -- A hand-rolled probe rather than a shelf item: this test is about the BANKING rule, and
            -- picking a real ninja blade would couple it to whatever the shelf happens to stock. Any
            -- real class id will do -- the probe carries it in `class`, which is the only taxonomy
            -- field an item has since the fold (docs/class-fold.md).
            local classId = next(Class.defs)
            assert(classId, "there is at least one class")
            local probe = { class = classId }

            local first = Combat.awardTechnique(c, knight, probe)
            assert(first == Class.TECHNIQUE_PER_ACTION, "one action banks one action's worth")
            assert(knight.char.technique[classId] == first, "onto the caster's own ledger")
            assert(c.techniqueEarned[classId] == first, "and onto the fight's ledger")
            assert(c.techniqueAward and c.techniqueAward.unit == knight, "the floater one-shot is armed")

            -- PLAIN CLASS STOCK banks too -- the opening-campaign case that used to bank and float
            -- nothing at all, since only 233 of 638 item files declare a discipline and disciplines are
            -- locked content. A discipline item still banks its discipline rather than its class.
            assert(Combat.awardTechnique(c, knight, { class = "fighter" })
                == Class.TECHNIQUE_PER_ACTION, "a plain class cast banks its class")
            assert(knight.char.technique.fighter == Class.TECHNIQUE_PER_ACTION, "onto the same ledger")
            assert(c.techniqueAward.discipline == "fighter", "and arms the same one floater")

            -- Run one key's battle ledger to the cap: banking stops while play carries on. The cap now
            -- bounds the level-up reading too, since they are one number.
            local guard = 0
            while (c.techniqueEarned[classId] or 0) < Class.TECHNIQUE_PER_BATTLE and guard < 1000 do
                Combat.awardTechnique(c, knight, probe)
                guard = guard + 1
            end
            assert(c.techniqueEarned[classId] == Class.TECHNIQUE_PER_BATTLE, "the ledger stops at the cap")
            assert(Combat.awardTechnique(c, knight, probe) == 0, "and further casts bank nothing")
            assert(c.techniqueAward == nil, "a capped-out cast floats nothing rather than a zero")
            assert(knight.char.technique[classId] == Class.TECHNIQUE_PER_BATTLE,
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
        name = "forging spends the wallet without touching the job or the class level",
        fn = function()
            local Class = require("models.class")
            local char = Character.instantiate("character_rowan")
            char.job = "mage"
            Character.recordTechnique(char, "mage", Class.classLevelCost(3))
            Character.recordTechnique(char, "knight", 20)
            local player = { roster = { char } }

            local beforeLevel = Class.classLevel(char, "mage")
            assert(beforeLevel == 3, "the ladder put this body at mage 3")

            local billed = Class.spendTechnique(player, "mage", Class.classLevelCost(3))
            assert(billed == char, "the bill came off the only holder")
            assert(Class.technique(player, "mage") == 0, "the wallet fell by what was billed")

            -- The two things a forge must never charge: what a body IS, and how far it has got.
            assert(Growth.jobOf(char) == "mage", "the declared job did not move")
            assert(Class.classLevel(char, "mage") == beforeLevel,
                "spending the whole bank left the class level exactly where it was")
        end,
    },
    {
        name = "a boss is authored at its reference level and scales DOWN toward the shallows",
        fn = function()
            -- The descent deals its seven circles in a fresh order every run, so the same general has
            -- to be a fair fight on floor 1 and on floor 7. The per-level blend cannot express that:
            -- measured, the seven moved 240 -> 288 health across twelve levels while a party member
            -- moved 70 -> 142. On floor 1 that is not a hard fight, it is an impossible one, because
            -- mitigation is subtractive and a level-1 company cannot put damage through the armour.
            local Growth = require("models.growth")
            local Character = require("models.character")

            -- Opted into by blueprint, through `referenceLevel`. NOT off `boss`, which means "immune
            -- to execute and to Charm" and sits on thirty-nine bodies including every companion --
            -- keying the curve to it rescaled half the bestiary and broke balance_spec's threat and
            -- time-to-kill bands on bodies that were never set-pieces.
            local id
            for defId, def in pairs(Character.defs) do
                if def.referenceLevel then id = id or defId end
            end
            assert(id, "at least one body declares the level it was authored at")
            assert(Character.defs[id].referenceLevel == Growth.BOSS_REFERENCE_LEVEL,
                "and it is the level the curve is written against")

            local top = Growth.spawn(id, Growth.BOSS_REFERENCE_LEVEL, Growth.BOSS_REFERENCE_LEVEL)
            local shallow = Growth.spawn(id, 1, 1)

            -- THE AUTHORED NUMBERS ARE THE NUMBERS AT THE REFERENCE LEVEL. This is what keeps the
            -- campaign's own capstone fights -- and the deepest floor of a descent -- untouched.
            local plain = Character.instantiate(id)
            local grown = Character.instantiate(id)
            Growth.resolve(grown, Growth.BOSS_REFERENCE_LEVEL)
            assert(top.stats.health.max == grown.stats.health.max,
                "a boss at its reference level must be exactly what the blend made it")
            assert(plain, "and the blueprint still instantiates unscaled")

            assert(shallow.stats.health.max < top.stats.health.max,
                "a shallow boss is smaller than the same boss at depth")

            -- TWO SHARES, and this is the half that took a measurement to find. Cutting a 20-damage
            -- blow by the same 60% as the health does not remove 60% of it -- the coat subtracts
            -- first, so what is left is a scratch. Measured at one share, every boss needed SEVENTY
            -- hits to drop a party member on floor 1. Durability scales; the blow barely can.
            assert(Growth.bossHitShare(1) > Growth.bossShare(1),
                "a shallow boss keeps more of its swing than of its health")
            assert(Growth.bossShare(Growth.BOSS_REFERENCE_LEVEL) == 1
                and Growth.bossHitShare(Growth.BOSS_REFERENCE_LEVEL) == 1,
                "and neither share touches the level the numbers were written for")

            -- Nothing that is not a boss is touched at all.
            local ordinary = Character.instantiate("character_bandit")
            Growth.resolve(ordinary, 1)
            local spawned = Growth.spawn("character_bandit", 1, 1)
            assert(spawned.stats.health.max == ordinary.stats.health.max,
                "an ordinary body is spawned exactly as the blend leaves it")
        end,
    },
}
