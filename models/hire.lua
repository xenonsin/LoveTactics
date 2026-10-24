-- THE HIRING BOARD: strangers who walk into the Hunter's Lodge looking for a company, three at a time
-- ("The Hiring Board", approved 2026-10-12, all sixteen lines; round 1 of its review page).
--
-- WHY BODIES CAN BE BOUGHT AGAIN. Generic recruits were argued down twice -- on 2026-08-24 (bc60a0d)
-- and again in 002d1f38 -- on one ground: seven authored companions ARE the reserve, so a supply of
-- generic bodies is stacked on a roster that is already sufficient. Four things have moved since:
--   * injuries STACK and outlive the trip (models/injury.lua), so a bench has a job every homecoming;
--   * every companion and the avatar is human, so fourteen of the sixteen race items -- the game's one
--     equip gate (Character.canCarry) -- were finds nobody on the roster could ever wear;
--   * the races themselves were authored as people "a company may hire" (data/races/dwarf.lua);
--   * a body per class already exists (character_adv_<class>, models/adventurers.lua).
-- What did NOT move is the identity argument, and it is kept: a hire never speaks, carries no signature
-- and is never a companion. Two tracks that never feel alike (Variants Daphne's split).
--
-- WHAT THE FIVE GAMES EACH LENT. The board is Darkest Dungeon's stagecoach (a handful each visit, the
-- rest move on). The stat roll is Wizardry's bonus points, made zero-sum. The kit is Darkest's (fixed
-- per class). The arrival level is FFT's soldier office (the party's own level). The aptitude is Fire
-- Emblem's growth rate, which this game already spells `personalGrowth` (models/growth.lua).
--
-- A HIRE IS A FUNCTION OF ITS ID, and that is the load-bearing decision. `character_hire@knight.dwarf.
-- 482913` names the class, the people and the roll, and everything rolled -- the name, the stat spread,
-- the aptitude, the tint, the token -- is re-derived from those three by Hire.variant. So a save holds
-- nothing a hire is made of that it does not already hold for Rowan: the id, the grid, the growth, the
-- xp. Character.defs resolves the id lazily the way it resolves `character_adv_<class>@<race>`, so the
-- arena, the save, the Ward and every ledger keyed by id take a hire with no new case.
--
-- THE BOARD IS STAMPED, NOT RE-DERIVED. Which classes a slate can roll depends on what the company has
-- unlocked, and what a gifted stranger carries depends on the company's rung -- both live state the seed
-- cannot know. So a board is dealt once per homecoming and kept on the player (`player.hireBoard`), the
-- same call models/descent.lua made for the companion roll (`run.companion`). Reloading never re-deals.
--
-- Pure logic, no love.graphics. Headless.

local Seed = require("models.seed")

local Hire = {}

-- How many strangers stand on the board each homecoming (round 1, "board-three").
Hire.SLATE = 3

-- The sign-on fee, flat (round 1, "cost-fee": start near the Ward's 40g). It prices a WANT: the avatar
-- and the seven can always walk down, so the stair never depends on a hire (docs/the-count.md).
Hire.FEE = 40

-- THE ROSTER CAP (2026-10-23). The board opens on the third trip home now (Offer.SCHEDULE) rather than
-- after the Crown, and what keeps strangers from crowding out the written companions is a ceiling: no
-- hire -- off the board or a saved delver -- while the roster already holds this many. Lifted for good
-- once the Demon Lord has fallen (Player.hasFinishedCampaign).
Hire.ROSTER_CAP = 6

-- Is the roster full for hiring? False once the Crown has fallen.
function Hire.rosterFull(player)
    if not player then return false end
    if require("models.player").hasFinishedCampaign(player) then return false end
    return #(player.roster or {}) >= Hire.ROSTER_CAP
end

Hire.FULL_REASON = "the company is full at " .. Hire.ROSTER_CAP .. " until the Demon Lord falls"

-- The id prefix every hire wears. Character.defs' __index dispatches on it.
Hire.PREFIX = "character_hire@"

-- THE ZERO-SUM SPREAD (round 1, "stats-zero-sum"). SPREAD_MOVES times, one stat gains a unit and another
-- loses one. A unit is 5 on a pool and 1 on a flat stat, so a move trades like for like: +5 health for -1
-- damage would be a gift dressed as a trade. Movement and regen are never touched -- a hire that walks
-- three tiles is a different game, not a different stranger.
Hire.SPREAD_MOVES = 3
Hire.UNIT = { health = 5, mana = 5, stamina = 5 }
Hire.SPREAD_STATS = {
    "health", "mana", "stamina", "damage", "magicDamage", "defense", "magicDefense", "speed", "skill", "luck",
}

-- ONE IN TEN ARRIVES GIFTED (round 1, "stats-gifted"): a net GIFT_UNITS on top of the spread, and one
-- find off its own class shelf ("Should also come with item" -- the author's note, settled as a find at
-- or below the company's rung in that class).
Hire.GIFTED_ONE_IN = 10
Hire.GIFT_UNITS = 2

-- THE APTITUDE (round 1, "stats-aptitude"): one stat that grows faster, written as the `personalGrowth`
-- table every companion already carries (Growth.personal). The same amount the companions' own tables
-- spend, inside Growth.PERSONAL_BUDGET -- an identity, not a second class.
Hire.APTITUDE = 2
Hire.APTITUDE_STATS = { "health", "mana", "stamina", "damage", "magicDamage", "defense", "magicDefense" }

-- THE STAT LINE A ROOT STARTS FROM: its generic class template, the relic-free body every companion of
-- that house was specialized from (data/characters/character_<root>.lua). On the companions' scale --
-- the generic knight carries 68 health against Rowan's 70 -- where the adventurer bodies are tuned as
-- ENEMIES (30). A crossing has no generic; it averages its parents' (Hire.template).
Hire.ROOT_TEMPLATE = {
    knight = "character_knight", fighter = "character_fighter", priest = "character_priest",
    mage = "character_mage", alchemist = "character_alchemist", hunter = "character_archer",
    rogue = "character_rogue",
}

-- THE STANDARD KIT (round 1, "kit-standard"): every hire of a class walks in with the same pieces, all
-- of them rung 0 -- so hiring can never put a piece in a hand that the shelf would not sell this
-- morning. tests/hire_spec.lua holds every cell to unlockLevel 0.
--
-- WHAT RUNG 0 COSTS, measured rather than assumed: no root's shelf carries ARMOUR at rung 0 (leather is
-- the rogue's rung 1, chainmail the knight's 4), and the priest's carries no heal (Heal is rung 3). So a
-- hired priest swings a censer and drinks a draught until the class grows. That is the rule doing its
-- job, and it is reported on the review page rather than papered over with a rung-3 gift.
--
-- The healing draught is the alchemist's rung 0, and rides in every kit as one of the standing draughts
-- that a gate would only ever price as a need.
Hire.ROOT_KITS = {
    knight    = { "weapon_iron_sword", "utility_second_wind", "consumable_healing_potion" },
    fighter   = { "weapon_iron_axe", "ability_penetrating_strike", "consumable_throwing_stone",
                  "consumable_healing_potion" },
    priest    = { "weapon_censer", "consumable_healing_potion", "consumable_healing_potion" },
    mage      = { "weapon_wand", "ability_fire_bolt", "ability_minor_shock", "consumable_mana_potion",
                  "consumable_healing_potion" },
    alchemist = { "weapon_apothecarys_lancet", "consumable_panacea", "consumable_stamina_potion",
                  "consumable_healing_potion" },
    hunter    = { "weapon_iron_bow", "consumable_net", "consumable_healing_potion" },
    rogue     = { "weapon_iron_dagger", "consumable_ball_bearings", "consumable_healing_potion" },
}

-- A TINT ON THE CLASS TOKEN (round 1, "look-tint"). Multiplied over the whole token at draw time
-- (Character.tintOf), so the palette stays light: a stranger reads as a different body of the same
-- class, never as a status colour. A part-by-part recolour (skin, hair, cloth) wants masked art that
-- does not exist yet; this is the half that costs nothing.
Hire.TINTS = {
    { 1.00, 1.00, 1.00 }, { 1.00, 0.92, 0.84 }, { 0.88, 0.94, 1.00 }, { 0.92, 1.00, 0.90 },
    { 1.00, 0.88, 0.92 }, { 0.95, 0.90, 1.00 }, { 1.00, 0.97, 0.82 }, { 0.86, 0.98, 0.98 },
}

-- NAMES, by people. Plain and short; a player may rename any hire (Party's rename, round 1's note).
Hire.NAMES = {
    human  = { "Aldric", "Brenna", "Cass", "Doran", "Elsie", "Fenn", "Garrick", "Hollis", "Isolde", "Jory",
               "Kestrel", "Lisbet" },
    dwarf  = { "Bramm", "Dagna", "Durgan", "Helka", "Korrin", "Marda", "Orsik", "Rurik", "Sigrun", "Thorva",
               "Ulfgar", "Vistra" },
    elf    = { "Aelis", "Caelir", "Elowen", "Faelar", "Ilyra", "Lirael", "Naeris", "Sylvar", "Thalia",
               "Vaelin", "Yseult", "Zaelen" },
    goblin = { "Grib", "Knack", "Mizzle", "Nubb", "Pikk", "Rattle", "Skeet", "Snivvet", "Tansy", "Wix",
               "Yark", "Zogg" },
    kobold = { "Dekk", "Ixil", "Kizz", "Meepo", "Rhask", "Sizzik", "Tarrik", "Vex", "Yipp", "Zekk",
               "Krill", "Spurt" },
    naga   = { "Asha", "Ishvar", "Kaddru", "Manasa", "Nagini", "Sesha", "Takshaka", "Ulupi", "Vasuki",
               "Padma", "Sarpa", "Vritra" },
    oni    = { "Akaru", "Benkei", "Daku", "Goro", "Ibara", "Kaede", "Raiden", "Shuten", "Tamaki", "Ura",
               "Yasha", "Zenki" },
    orc    = { "Brakka", "Durza", "Ghorn", "Grusha", "Karg", "Mokra", "Nazgra", "Rukka", "Shagra", "Thokk",
               "Ugra", "Zurga" },
}

-- ---------------------------------------------------------------------------
-- The roll
-- ---------------------------------------------------------------------------

-- The i-th draw off a roll, in 1..n. Each draw is its own Seed.mix rather than a chained state, so
-- adding a draw at the end can never shift the ones before it -- the look of a hire saved last week
-- must not change because this file learned to roll something new.
local function draw(roll, i, n)
    if n <= 0 then return nil end
    return Seed.mix(roll, i, 7919) % n + 1
end

local function playableRaces()
    return require("models.adventurers").RACES
end

-- `character_hire@knight.dwarf.482913` -> "knight", "dwarf", 482913. nil for anything else.
function Hire.split(id)
    if type(id) ~= "string" then return nil end
    local class, race, roll = id:match("^character_hire@([%w_]+)%.(%a+)%.(%d+)$")
    if not class then return nil end
    return class, race, tonumber(roll)
end

function Hire.idOf(class, race, roll)
    return Hire.PREFIX .. class .. "." .. race .. "." .. tostring(roll)
end

-- Is this a hire (an id or a character)?
function Hire.isHire(idOrChar)
    local id = type(idOrChar) == "table" and idOrChar.id or idOrChar
    return Hire.split(id) ~= nil
end

local function isResource(stat) return Hire.UNIT[stat] ~= nil end
local function unitOf(stat) return Hire.UNIT[stat] or 1 end

-- THE CLASS STANDARD a hire is read against: the root's generic template, or for a crossing the mean
-- of its parents' -- rounded, so a crossing of a 68-health knight and a 55-health rogue stands at 62.
-- Returns a fresh table of plain numbers (pools as their max), or nil for a class with no root.
function Hire.template(class)
    local Class = require("models.class")
    local Character = require("models.character")
    local roots = Class.rootsOf(class)
    if #roots == 0 then return nil end
    local sum, n = {}, 0
    for _, root in ipairs(roots) do
        local def = Hire.ROOT_TEMPLATE[root] and rawget(Character.defs, Hire.ROOT_TEMPLATE[root])
        if def then
            n = n + 1
            for stat, v in pairs(def.stats or {}) do
                if type(v) == "number" then sum[stat] = (sum[stat] or 0) + v end
            end
        end
    end
    if n == 0 then return nil end
    local out = {}
    for stat, v in pairs(sum) do out[stat] = math.floor(v / n + 0.5) end
    return out
end

-- The opening piece a CROSSING's own shelf holds at rung 0 -- one utility, armour or weapon apiece
-- (measured over all thirty-eight, tests/hire_spec.lua). Sorted by id so the answer is stable. nil for
-- a root, whose kit is authored above.
function Hire.crossingPiece(class)
    local Item = require("models.item")
    local hits = {}
    for id, d in pairs(Item.defs) do
        if d.class == class and (d.unlockLevel or 0) == 0 and not d.unstocked and not d.race
            and not d.bound and d.type ~= "consumable" then
            hits[#hits + 1] = id
        end
    end
    table.sort(hits)
    return hits[1]
end

-- THE STANDARD KIT for `class`, as a list of item ids. A root's is authored (Hire.ROOT_KITS); a
-- crossing wears its first root's kit with its own rung-0 piece in place of the last cell's draught --
-- which keeps a crossing hire's grid the same size as its parent's and puts the one thing that says
-- what it is where a player looks for it.
function Hire.kitOf(class)
    local Class = require("models.class")
    if Hire.ROOT_KITS[class] then
        local out = {}
        for i, id in ipairs(Hire.ROOT_KITS[class]) do out[i] = id end
        return out
    end
    local root = Class.rootsOf(class)[1]
    local base = root and Hire.ROOT_KITS[root]
    if not base then return {} end
    local out = {}
    for i, id in ipairs(base) do out[i] = id end
    local piece = Hire.crossingPiece(class)
    if piece then table.insert(out, 2, piece) end
    return out
end

-- WHAT THE ROLL DID TO THE STAT LINE: { stat = delta } in raw points, plus the aptitude stat and
-- whether the roll came up gifted. Pure function of the roll and the class's template, which is what
-- lets the card print "Speed 5 (+2)" against the standard (round 1, "stats-delta").
--
-- Draw indices are fixed and spaced, so each question about a roll has its own and none can shift
-- another: 1..2 class/race (Hire.deal), 10 name, 11 tint, 12 aptitude, 13 gifted, 14 gifted stat,
-- 20.. the spread moves.
function Hire.rollOf(class, roll)
    local base = Hire.template(class) or {}
    local delta = {}
    local function live(stat) return (base[stat] or 0) + (delta[stat] or 0) end
    local stats = Hire.SPREAD_STATS
    for m = 1, Hire.SPREAD_MOVES do
        local up = stats[draw(roll, 20 + 2 * m, #stats)]
        local down = stats[draw(roll, 21 + 2 * m, #stats)]
        -- A move that would take a stat to zero or below is skipped rather than redrawn: a redraw would
        -- spend a draw index the next move owns. A pair that names one stat twice is a no-op.
        if up ~= down and live(down) - unitOf(down) >= 1 then
            delta[up] = (delta[up] or 0) + unitOf(up)
            delta[down] = (delta[down] or 0) - unitOf(down)
        end
    end
    local gifted = draw(roll, 13, Hire.GIFTED_ONE_IN) == 1
    if gifted then
        local stat = stats[draw(roll, 14, #stats)]
        delta[stat] = (delta[stat] or 0) + Hire.GIFT_UNITS * unitOf(stat)
    end
    local aptitude = Hire.APTITUDE_STATS[draw(roll, 12, #Hire.APTITUDE_STATS)]
    return { delta = delta, gifted = gifted, aptitude = aptitude }
end

-- How many UNITS a roll moved the line by, net -- zero for an ordinary stranger, GIFT_UNITS for a
-- gifted one. What tests/hire_spec.lua holds the spread to.
function Hire.netUnits(delta)
    local total = 0
    for stat, d in pairs(delta or {}) do total = total + d / unitOf(stat) end
    return total
end

-- ---------------------------------------------------------------------------
-- The blueprint a hire IS
-- ---------------------------------------------------------------------------

-- `character_hire@knight.dwarf.482913` as a blueprint. Built once per id and memoized by the caller
-- (Character.defs' __index), exactly as Adventurers.variant is. nil for anything that is not a valid
-- hire, so a typo is the same loud "unknown character id" as any other.
function Hire.variant(defs, id)
    local class, race, roll = Hire.split(id)
    if not class then return nil end
    local Class = require("models.class")
    local Race = require("models.race")
    if not (Class.defs[class] and Class.isPlayable(class)) then return nil end
    local playable = false
    for _, r in ipairs(playableRaces()) do if r == race then playable = true break end end
    if not (playable and Race.get(race)) then return nil end

    local base = Hire.template(class)
    if not base then return nil end
    local rolled = Hire.rollOf(class, roll)
    local stats = {}
    for stat, v in pairs(base) do stats[stat] = v + (rolled.delta[stat] or 0) end

    local names = Hire.NAMES[race] or Hire.NAMES.human
    local adv = rawget(defs, "character_adv_" .. class)
    local root = Hire.ROOT_TEMPLATE[class] and rawget(defs, Hire.ROOT_TEMPLATE[class])
    local kit = Hire.kitOf(class)

    return {
        name = names[draw(roll, 10, #names)],
        race = race,
        kind = Race.kindOf(race),
        class = class,
        tier = 2,
        hire = true,
        -- A root wears its generic's token rather than the adventurer body's, because the adventurer
        -- knight borrows ROWAN's art -- a hired knight would otherwise be her double.
        sprite = (root and root.sprite) or (adv and adv.sprite),
        tint = Hire.TINTS[draw(roll, 11, #Hire.TINTS)],
        archetype = (adv and adv.archetype) or (root and root.archetype),
        stats = stats,
        personalGrowth = { [rolled.aptitude] = Hire.APTITUDE },
        gifted = rolled.gifted or nil,
        rolled = rolled.delta,
        startingItems = kit,
        defaultAction = kit[1],
    }
end

-- ---------------------------------------------------------------------------
-- The board
-- ---------------------------------------------------------------------------

-- Which classes a stranger may walk in as (round 1, "board-classes"): the seven roots, and any earned
-- class the company has already opened -- never one it has not, because hiring a body born to a class
-- opens its house (Class.markTaken), and a board that dealt a Ninja on the second trip would open a
-- discipline nobody earned. Sorted, so a seed deals the same list the same way.
function Hire.classPool(player)
    local Class = require("models.class")
    local out = {}
    for id in pairs(Class.defs) do
        if Class.isPlayable(id) and (Class.isRoot(id) or Class.isUnlocked(player, id)) then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

-- The people a stranger of `class` belongs to (round 1, "board-peoples"): half the time one that leans
-- to the class, the same LEAN_SHARE the rift's parties use, otherwise any of the eight.
local function raceFor(class, roll)
    local Adventurers = require("models.adventurers")
    local leaning = Adventurers.leaningRaces(class)
    if #leaning > 0 and draw(roll, 2, Adventurers.LEAN_SCALE) <= Adventurers.LEAN_SHARE then
        return leaning[draw(roll, 3, #leaning)]
    end
    local all = playableRaces()
    return all[draw(roll, 4, #all)]
end

-- A FIND OFF ITS OWN CLASS SHELF, for a gifted stranger: a rift find (no price), not an organ, not a
-- race item, not born hexed, not a draught, at or below the rung the company has reached in that class
-- -- so a gift is a head start on a shelf the player is already climbing, never a piece from past it.
-- nil when the shelf has nothing that low.
function Hire.giftFor(player, class, roll)
    local Item = require("models.item")
    local Class = require("models.class")
    local Curse = require("models.curse")
    local rung = Class.rosterLevel(player, class)
    local pool = {}
    for id, d in pairs(Item.defs) do
        if d.class == class and d.price == nil and not d.unstocked and not d.race and not d.bound
            and not Curse.isCursed(d) and d.type ~= "consumable" and (d.unlockLevel or 0) <= rung then
            pool[#pool + 1] = id
        end
    end
    table.sort(pool)
    return pool[draw(roll, 15, #pool)]
end

-- THIS HOMECOMING'S BOARD, dealt on first ask and kept (see the header). A new homecoming -- the trip
-- count has moved -- deals a fresh one, and whoever was not hired off the last has moved on.
function Hire.board(player)
    if not player then return nil end
    local trip = require("models.player").tripsHome(player)
    local board = player.hireBoard
    if board and board.trip == trip then return board end

    local pool = Hire.classPool(player)
    local offers = {}
    for slot = 1, Hire.SLATE do
        local roll = Seed.mix(Seed.lap(player), trip, slot, Seed.text("hire"))
        local class = pool[draw(roll, 1, #pool)]
        local race = raceFor(class, roll)
        local id = Hire.idOf(class, race, roll)
        local def = require("models.character").defs[id]
        offers[slot] = {
            id = id,
            gift = (def and def.gifted) and Hire.giftFor(player, class, roll) or nil,
        }
    end
    board = { trip = trip, offers = offers }
    player.hireBoard = board
    return board
end

-- Why `slot` cannot be hired right now, as a lower-case fragment, or nil when it can.
function Hire.blockReason(player, slot)
    local board = Hire.board(player)
    local offer = board and board.offers[slot]
    if not offer then return "nobody is standing there" end
    if offer.hired then return "already in the company" end
    if Hire.rosterFull(player) then return Hire.FULL_REASON end
    if (player.gold or 0) < Hire.FEE then return "you cannot cover the fee" end
    return nil
end

-- What a hire of `class` arrives knowing. See the note on Hire.hire below.
local function techniqueFor(player, class)
    local Class = require("models.class")
    local technique = {}
    if Class.isRoot(class) then
        local held = math.min(1, Class.rosterLevel(player, class))
        if held > 0 then technique[class] = Class.classLevelCost(held) end
    else
        for key, need in pairs(Class.defs[class].requires or {}) do
            technique[key] = Class.classLevelCost(math.min(need, Class.rosterLevel(player, key)))
        end
    end
    return technique
end

-- Put a hire's body on the roster: recruit, seed its technique, mark its class taken. Nil when the id
-- is already on the roster.
local function signOn(player, id, class, technique)
    local char = require("models.player").recruit(player, id)
    if not char then return nil end
    for key, amount in pairs(technique) do
        if amount > 0 then char.technique[key] = amount end
    end
    require("models.class").markTaken(player, class)
    return char
end

-- A SAVED STRAY DELVER JOINS (2026-10-23). The delver is already a hire's body rolled per fight
-- (models/delver.lua) -- `character_stray_delver@<class>.<race>.<roll>` -- so joining is the same id
-- under the hire prefix: same name, same spread, same rung-0 kit. No fee: she was saved, not bought.
-- Respects the roster cap. Returns the character, or nil and a reason.
function Hire.delverId(delverId)
    local Delver = require("models.delver")
    if type(delverId) ~= "string" or delverId:sub(1, #Delver.PREFIX) ~= Delver.PREFIX then return nil end
    return Hire.PREFIX .. delverId:sub(#Delver.PREFIX + 1)
end

function Hire.joinDelver(player, delverId)
    if not player then return nil, "nobody to join" end
    local id = Hire.delverId(delverId)
    if not id or not require("models.character").defs[id] then return nil, "nobody to join" end
    if Hire.rosterFull(player) then return nil, Hire.FULL_REASON end
    local class = Hire.split(id)
    local char = signOn(player, id, class, techniqueFor(player, class))
    if not char then return nil, "already in the company" end
    return char
end

-- HIRE THE STRANGER IN `slot`. Charges the fee, puts the body on the roster through Player.recruit
-- (which hands it the company's median experience -- FFT's soldier office, round 1's "level-median"),
-- seeds its class technique, hands over the gift, and marks the offer taken. Returns the character, or
-- nil and a reason.
--
-- THE TECHNIQUE A HIRE ARRIVES WITH NEVER RAISES A SHELF. Quest.shelfRung reads the roster's BEST holder
-- in a class, so a hire that walked in at knight 6 would open the knight's rack to rung 6 for a fee.
-- So a root hire takes one rung of its own class at most, and only when somebody already holds it; a
-- crossing hire takes exactly what its `requires` names, which some body on the roster already holds
-- (that is what Class.isUnlocked on the player asked when the board was dealt). Measured before the
-- body joins, so it cannot be counted in the company it is being measured against.
function Hire.hire(player, slot)
    local why = Hire.blockReason(player, slot)
    if why then return nil, why end
    local Player = require("models.player")
    local Item = require("models.item")
    local Character = require("models.character")
    local offer = Hire.board(player).offers[slot]
    local class = Hire.split(offer.id)

    local technique = techniqueFor(player, class)

    if not Player.spendGold(player, Hire.FEE) then return nil, "you cannot cover the fee" end
    local char = signOn(player, offer.id, class, technique)
    if not char then
        Player.addGold(player, Hire.FEE)
        return nil, "already in the company"
    end
    if offer.gift and Item.defs[offer.gift] then
        Character.addItem(char, Item.instantiate(offer.gift))
    end
    offer.hired = true
    return char
end

-- LET A HIRE GO (round 1, "dismiss"). The company's gear goes back to the stash and the race's own
-- organs leave on the body (Player.release's rule). Refused for anybody who is not a hire: the avatar
-- and the seven are never dismissed.
function Hire.dismiss(player, charId)
    if not Hire.isHire(charId) then return false end
    return require("models.player").release(player, charId)
end

-- WHAT A CARD PRINTS against the class standard: { { stat, value, delta } } in SPREAD_STATS order, for
-- every stat the roll moved. Read by ui/panels/hire.lua.
function Hire.deltaRows(id)
    local def = require("models.character").defs[id]
    if not def then return {} end
    local rows = {}
    for _, stat in ipairs(Hire.SPREAD_STATS) do
        local d = (def.rolled or {})[stat]
        if d and d ~= 0 then rows[#rows + 1] = { stat = stat, value = def.stats[stat], delta = d } end
    end
    return rows
end

return Hire
