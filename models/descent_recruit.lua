-- WHO IS DOWN HERE: the forty-five bodies a descent can put in a company, and how deep each one stands.
--
-- THE CENSUS, NOT THE DOOR. This module answers three questions and deliberately no others: who exists
-- (Recruit.roster), how deep they stand (Recruit.floorFor), and what one of them reads like when you
-- are looking at them (describe / preview / join). WHAT SPENDS IT is models/voucher.lua -- the vouchers
-- a floor hands up and the pull the Hiring Hall turns them into. Read that file for the loop; this one
-- is the shelf it draws off.
--
--   Recruit.pool(8)               -- ids standing at floor 8 or above, sorted, blueprint-checked
--   Recruit.preview(player, id)   -- the body that WOULD join, built at the company's level
--   Recruit.join(player, id)      -- and the join itself
--
-- THE SPLIT IS OLDER THAN THE PULL AND SURVIVED IT INTACT, which is the argument for the shape. A
-- descent used to grow its company by meeting people on the floors, one stop at a time; that stop is
-- gone (see the note further down, and models/descent.lua's guaranteeKinds for why). Every part of this
-- file that the stop was using turned out to be a description of the ROSTER rather than of the stop,
-- so none of it moved.
--
-- WHAT IT OFFERS IS BODIES, NOT BUILDS. Draft strips a bought unit to its chassis
-- (models/draft_chassis.lua) because there the gear row IS the draft; a descent's gear comes off its
-- FLOORS -- the caches, the salvage, the merchant stops -- and putting a second source in front of the
-- same question would make the floors' answer the less interesting one. So a body arrives wearing
-- exactly what its blueprint authors, and what happens to it after that is the run's business.
--
-- ...WITH ONE OBJECT EXCEPTED, and it is the exception the pull is built on: the single BOUND item
-- every one of the forty-five carries. That one is the body rather than its gear, it cannot be forged
-- (models/forge.lua), and the only thing that levels it is the body turning up again.
--
-- Pure model -- no love.graphics, love.filesystem untouched -- so it loads under the headless runner.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Discipline = require("models.discipline")

local Recruit = {}

-- How many bodies Recruit.offer deals when a caller does not say. ONE, and the reasoning behind that
-- number is worth keeping even though nothing in the descent calls it today.
--
-- It dealt three for a while, on the reasoning that a slate asks what the company is short of. What
-- three cards actually asked was narrower than that -- laid side by side at a card's width apiece, the
-- only thing they could carry was a stat line, so the question collapsed into "which of these numbers is
-- biggest" against two strangers rather than against the company standing behind you. One body is met
-- whole: the room for a portrait, the kit it is carrying laid out in the grid it fights from, and a
-- tooltip on every piece of it (ui/panels/recruit.lua) -- which is far more to read than three cards ever
-- fit, about the only decision that was ever really there.
--
-- THE PULL KEPT THAT LESSON AND DROPPED THE SLATE ENTIRELY. A pull deals exactly one body and there is
-- nothing to compare it against, which is the same argument taken one step further: the panel is a
-- REVEAL, not a shelf.
Recruit.OFFER = 1

-- ---------------------------------------------------------------------------
-- WHO IS DOWN HERE TO BE MET: the discipline heroes, and how deep each one stands.
-- ---------------------------------------------------------------------------

-- THE CANDIDATES ARE HEROES, ONE PER DISCIPLINE -- Brann the Barbarian, Pim the Thief, Zosia the
-- Poisoner -- and never the base class templates behind them.
--
-- Each discipline blueprint names its own (`hire`, data/disciplines/<id>.lua), beside the `exemplar` it
-- already named: the exemplar is the boss body you FIGHT in that discipline's quest, the hire is the
-- named body who will walk with you. One authored line per discipline, in the file that already owns
-- everything else about it, rather than a roster list somewhere else that would go stale the day a
-- discipline landed.
--
-- IT USED TO DEAL OFF THE DRAFT POOL (data/draft/pool.lua, through DraftRun.pool), which is a list of
-- generic class templates and discipline EXEMPLARS -- character_fighter, character_knight, the arena
-- berserker. That is the right slate for Draft, where a bought unit is stripped to a chassis and the
-- gear row is the draft (models/draft_chassis.lua); it is the wrong one here, because a body met on a
-- floor arrives whole, wearing the kit its blueprint authors, and joins a company you will keep. "A
-- Fighter joins" is a stat line. "Brann joins, and the Red Account reads the health he has already
-- spent" is somebody.
local function heroOf(disciplineId)
    local def = Discipline.defs[disciplineId]
    return def and def.hire or nil
end

-- AND THE SEVEN BASE CLASSES, WHO STAND ON THE FIRST FLOOR. A discipline is a specialization earned off
-- a house's line; the plain class under it is what a player has from the very beginning, so the seven
-- are the shallowest thing down here and there is no ladder above them to climb.
--
-- THEY ARE PEOPLE TOO, and that is the point of reading them off each house's authored `companion`
-- rather than off the class list. The generic templates (character_fighter, character_knight) are stat
-- lines with no portrait and no relic -- what the pool was full of before, and what it must never be
-- full of again. Each house's COMPANION is the named body built on that class: Saber for the fighter,
-- Rowan for the knight, Clem for the rogue. One per class, which is exactly the shape `hire` gives the
-- disciplines.
--
-- IT USED TO READ Temptation.COMPANIONS, and moved when that model was cut. The pairing was never a
-- temptation fact -- it is a vendor fact, sitting beside the `sin` and `class` those blueprints already
-- declare (data/vendors/bastion.lua carries the rationale), so the table went to the houses rather than
-- to whichever module happened to walk it.
--
-- Somebody already in the company is filtered at the slate (Recruit.offer), so a save that walked in
-- with Rowan simply never meets her down here.
local function rootHeroes()
    local Vendor = require("models.vendor")
    local ids = {}
    -- Walked in Descent.SINS order rather than by `pairs` over the vendor registry: a floor's slate must
    -- deal the same body from the same seed on any machine, and that list is already the one ordered
    -- statement of which house is which circle.
    for _, sin in ipairs(Descent.SINS) do
        local def = sin.vendor and Vendor.get(sin.vendor)
        local id = def and def.companion
        if id then ids[#ids + 1] = id end
    end
    return ids
end

-- HOW DEEP A DISCIPLINE STANDS, and the whole of it is read off what the campaign already says about
-- when that discipline is normally earned.
--
-- A discipline blueprint names the quests that unlock it (`requiredQuests`), and for a subclass that is
-- a numbered slot in its house's line -- quest_bastion_slot_03, quest_alchemist_slot_05. Quest.slotFloor
-- turns a slot into the LEVEL the campaign expects a party to be at when they reach it, which is the one
-- number a floor also has (Descent.floorLevel). So the depth a hero is met at is not a second opinion
-- about how strong that discipline is; it is the campaign's own, read in the descent's units.
--
-- A MULTICLASS IS EARNED ADVANCEMENT, not a slot: its capstone opens only once the player holds a
-- subclass of EACH parent (models/discipline.lua), so it can only stand below every subclass there is.
--
-- WHAT THE CAMPAIGN GIVES IS AN ORDER, NOT A DEPTH, and reading it as a depth was the mistake. Mapped
-- level-for-level, the seventeen subclasses land in four lumps and all twenty-one multiclass heroes
-- arrive on one floor -- because the campaign has no opinion about which multiclass comes first (they
-- are all "hold a subclass of each parent"), and the lump is that absence of an opinion showing through.
-- Four floors of five bodies and eleven floors of nobody new is not a descent that opens up; it is four
-- events with corridor between them, and the floor everything lands on is worth more than the six under
-- it put together.
--
-- SO THE ORDER IS THE CAMPAIGN'S AND THE SPACING IS THE DESCENT'S. Rank every discipline by the level
-- its gate quest expects -- which is what "normally unlocked" means and the only thing this reads off
-- the campaign -- then lay the ranked list down the floors at an even rate:
--
--   floor 1    the seven base classes                      Saber, Rowan, Clem, Kaya, Amana, Gyeom, Ren
--   floor 2    Beastmaster, Bulwark, Elementalist           the shallowest slot-3 subclasses
--   floor 3    Exorcist, Warlord, Bombardier                ...and the first of the slot-4s
--   ...
--   floor 8    the last subclasses, and the first multiclass beside them
--   floor 15   the deepest cut of all
--
-- THE FIRST FLOOR IS THE PLAIN CLASSES AND NOTHING ELSE, which is what the two halves of the rule mean
-- together: a company standing at the mouth of the descent is choosing between a fighter, a knight and
-- a rogue, exactly as a campaign party opens on the seven and specializes downward. Everything below is
-- a specialization, dealt two or three a floor for the fourteen floors under it.
--
-- Nothing is met earlier than the discipline above it in the campaign's own order, which is the half a
-- player can actually feel; what the even rate buys is that every floor is somewhere new bodies come
-- from, which is what makes going one deeper worth doing on a floor whose fights you already know.
--
-- Cumulative: a floor offers everything standing at its depth or above it.
local depths -- disciplineId -> the shallowest floor it may be met on. Built once; the data is static.

-- What level the campaign expects a party to hold when this discipline is earned. The rank key, and the
-- only thing read off the campaign.
--
-- A subclass names a numbered slot in its house's line; Quest.floorLevelFor turns that into the level.
-- The blueprint is passed when there is one -- several gate quests are still `pending` -- and an empty
-- def otherwise, which leaves it reading the slot in the id, and the slot IS the depth of the line.
--
-- A multiclass has a capstone rather than a slot, and it is past every subclass by construction, so it
-- ranks one level below the deepest of them. Which multiclass comes first is a question nothing in the
-- game answers, so they hold that rank together and the spacing below deals them out.
local function unlockLevel(id, def, deepestSlot)
    local Quest = require("models.quest")
    if Discipline.arity(id) >= 2 then return (deepestSlot or 1) + 1 end

    local level = 1
    for _, questId in ipairs(def.requiredQuests or {}) do
        local gate = Quest.floorLevelFor(Quest.defs[questId] or {}, questId)
        level = math.max(level, gate or 1)
    end
    return level
end

local function buildDepths()
    -- The base classes hold the first floor, and nothing else does.
    local out = {}
    for _, id in ipairs(rootHeroes()) do out[id] = 1 end

    -- The subclasses first, because the multiclass rank is defined against the deepest of them.
    local deepestSlot = 1
    for id, def in pairs(Discipline.defs) do
        if Discipline.arity(id) < 2 then
            deepestSlot = math.max(deepestSlot, unlockLevel(id, def, 0))
        end
    end

    local ranked = {}
    for id, def in pairs(Discipline.defs) do
        if def.hire then
            ranked[#ranked + 1] = { hire = def.hire, level = unlockLevel(id, def, deepestSlot) }
        end
    end
    -- Ties broken by id, because `pairs` over a registry is unordered and a run must lay out the same
    -- floors on any machine. Within a tie the campaign has said everything it has to say, so this is a
    -- stable arbitrary rather than a hidden opinion.
    table.sort(ranked, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.hire < b.hire
    end)

    -- The even rate, over the floors BELOW the first: rank i of n opens on floor 2 + floor((i-1) *
    -- (FLOORS - 1) / n). Every floor of the descent gets a share, and no floor gets a tier.
    local span = math.max(1, Descent.FLOORS - 1)
    for i, entry in ipairs(ranked) do
        out[entry.hire] = 2 + math.floor((i - 1) * span / #ranked)
    end
    return out
end

-- The shallowest floor `heroId` may be met on. Keyed by the BODY rather than by its discipline, because
-- the seven base classes have no discipline and are met the same way everything else is.
function Recruit.floorFor(heroId)
    depths = depths or buildDepths()
    return depths[heroId] or 1
end

-- Everybody the floors can ever offer: the seven base classes, then a hero per discipline.
function Recruit.roster()
    local ids = rootHeroes()
    for id in pairs(Discipline.defs) do
        local hero = heroOf(id)
        if hero then ids[#ids + 1] = hero end
    end
    return ids
end

-- The candidates standing at `floor` or above it, as character ids.
--
-- Sorted, and filtered through Save.known, for the two reasons DraftRun.pool does both: a slate is rolled
-- over this list and has to deal the same body from the same seed on any machine, and a discipline whose
-- hero blueprint has not landed yet must be skipped rather than offered as a name that cannot be built.
--
-- Defaults to the first floor rather than to everything: a caller that forgets to say where it is
-- standing gets the shallow end, which is wrong in the direction that cannot hand a company standing at
-- the mouth of the descent the deepest cut in the game.
function Recruit.pool(floor)
    local Save = require("models.save")
    floor = floor or 1

    local ids = {}
    for _, hero in ipairs(Recruit.roster()) do
        if Recruit.floorFor(hero) <= floor and Save.known(Character.defs, hero) then
            ids[#ids + 1] = hero
        end
    end
    table.sort(ids)
    return ids
end

-- The slate for one stop, as a list of character ids.
--
-- `exclude` is the company as it stands (a roster of characters, or a list of ids), and dropping it from
-- the pool is not politeness -- Player.recruit refuses a duplicate outright, so an id already in the
-- company would draw a card that does nothing when pressed.
--
-- `floor` is how deep the stop is standing, and it decides WHO could be there at all: a hero is met at
-- the depth the campaign would have unlocked their discipline at (Recruit.floorFor). Omitted, it is the
-- first floor -- see Recruit.pool.
--
-- Seeded through Combat.newRandom -- the same pure-Lua RNG models/draft_shop.lua rolls its store on -- so
-- a slate reproduces from the run and the floor that seated it, on any machine. The stop PINS what this
-- returns to its own cell (states/game.lua), like the merchant's shelf and the reliquary's slate, so
-- walking off the tile and back onto it is never a reroll.
function Recruit.offer(seed, exclude, count, floor)
    local taken = {}
    for _, entry in ipairs(exclude or {}) do
        taken[type(entry) == "table" and entry.id or entry] = true
    end

    local ids = {}
    for _, id in ipairs(Recruit.pool(floor)) do
        if not taken[id] then ids[#ids + 1] = id end
    end

    -- Partial Fisher-Yates over the eligible ids: draw `count` from the front and leave the rest. Uniform,
    -- without replacement (a slate offering the same body twice would be offering fewer than it says), and
    -- it does not care that the pool is far larger than the slate.
    local rand = Combat.newRandom(seed or 1)
    local n = math.min(count or Recruit.OFFER, #ids)
    for i = 1, n do
        local j = i + rand(#ids - i + 1) - 1
        ids[i], ids[j] = ids[j], ids[i]
    end

    local offer = {}
    for i = 1, n do offer[i] = ids[i] end
    return offer
end

-- What a candidate is CALLED, or nil if the id no longer names a blueprint. A slate is pinned to its cell
-- and rides in the save (states/game.lua), so it can outlive a body that was renamed or removed: the stop
-- drops a row it cannot name rather than opening a card with an id on it.
function Recruit.nameOf(id)
    local def = Character.defs[id]
    return def and (def.name or id) or nil
end

-- What a candidate IS, in one line, for the card the player picks off. A name is not a description: the
-- row a player chooses between has to carry the sentence that makes it a choice, and "Poacher" is not
-- that sentence. Two facts are, and they are the two a company short of a body actually weighs -- what
-- this one can take and deal, and what it fights with.
--
-- Both read off the blueprint rather than authored a second time here. The kit is named through
-- `signatureWeapon` / `signatureAbility` -- THE TWO ITEMS THAT ARE THIS UNIT, already authored on every
-- body in this pool because Draft strips a bought one down to exactly them (models/draft_chassis.lua) --
-- rather than by listing the whole nine-cell grid, which is five names of gear on a card two lines tall.
--
-- Fits the card it is drawn on: ui/panels/choice.lua gives a description two lines at 14px in a 414px
-- column, and anything past that overflows into the option beneath it.
function Recruit.describe(id)
    local def = Character.defs[id]
    if not def then return "" end
    local Item = require("models.item")
    local st = def.stats or {}

    local line = (st.health or 0) .. " health, " .. (st.damage or 0) .. " damage, " ..
        (st.defense or 0) .. " defense, " .. (st.movement or 0) .. " move."

    local kit = {}
    for _, itemId in ipairs({ def.signatureWeapon, def.signatureAbility }) do
        local idef = itemId and Item.defs[itemId]
        if idef and idef.name then kit[#kit + 1] = idef.name end
    end
    if #kit > 0 then
        line = line .. "  Fights with " .. table.concat(kit, " and ") .. "."
    end
    return line
end

-- The body that WOULD join, built and thrown away: the same instantiation Recruit.join performs, at the
-- same experience and resolved up the same ladder, so what the stop draws is the character that walks
-- away with you and not a level-1 sketch of them. Nil for an id that no longer names a blueprint.
--
-- Built rather than described because the panel needs the real thing: live item instances for the
-- tooltips, the loaded portrait, and stats that already carry the levels the median hands over. Growth
-- resolution is deterministic (models/growth.lua blends shares, it does not roll), so the preview and the
-- join cannot disagree.
--
-- Nothing here touches the roster -- Player.recruit is still the only door in.
function Recruit.preview(player, id)
    if not (id and Character.defs[id]) then return nil end
    local Experience = require("models.experience")
    local char = Character.instantiate(id)
    char.xp = Experience.medianOf(player and player.roster)
    Experience.resolve(char)
    return char
end

-- ---------------------------------------------------------------------------
-- WHAT USED TO BE HERE: the hall's stock, and why it is gone
-- ---------------------------------------------------------------------------
--
-- This module used to own a second half. The Hiring Hall dealt nothing of its own -- its stock was
-- THE PEOPLE YOU WALKED PAST (`Recruit.decline`, `Recruit.hallSlate`), the survivor on floor three you
-- decided you had no room for, still in town when you came back up. Refusing somebody was a decision
-- you met again rather than a free one, and a hire was never a body the player had not already stood in
-- front of and read. Beside it sat `Recruit.stake`, the one gladiator the sponsor paid for before the
-- city had even been looked at.
--
-- IT WAS COHERENT AND IT STARVED. Every part of that argument holds except the supply: a refusal can
-- only happen at a stop, a stop only ever seated while the company had ROOM, and nothing ever left a
-- company of four. So the floors stopped offering on the second floor of the first run, no refusal was
-- ever recorded again, and the hall a player walked into for the rest of the save was a room that said
-- "the company is full" forever. A consequence with no input is not a consequence.
--
-- What replaced it is models/voucher.lua: the floors hand up a VOUCHER, the hall spends it on a pull,
-- and a repeat of somebody you already hold levels the one relic that body is built around. The two
-- halves this file keeps -- WHO is down here (Recruit.roster / floorFor / pool) and what it costs to
-- read them (describe / preview / join) -- are exactly the halves the summon needed, which is why they
-- stayed here rather than moving.
--
-- `Recruit.offer` stays too, unused by the descent today. It is the seeded slate a stop dealt, and it
-- is the one piece of the old shape that is worth keeping warm: nothing else in the game deals N bodies
-- from a pinned seed, and the day a stop wants to exist again it is what it will want.

-- Take one into the company.
--
-- Player.recruit is the one path by which anything joins a roster -- it refuses a duplicate, hands the
-- newcomer the company's MEDIAN experience so a body pulled on floor four is not a level-1 liability,
-- and announces the join. A descent adds nothing to that any more: there is one XP curve in the game
-- (Experience.STEP), so a body pulled at the hall and a body sworn in Act 0 read their bank the same way.
--
-- Returns the instance, or nil if the company already held that id -- which is no longer an error case
-- but a BOND (models/voucher.lua's Voucher.pull), and the caller that matters knows the difference.
function Recruit.join(player, id)
    local Player = require("models.player")
    return Player.recruit(player, id)
end

return Recruit
