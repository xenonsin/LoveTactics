-- REQUEST RUNS: a day spent foraging instead of on a story quest.
--
-- The calendar made this necessary rather than merely nice. A campaign of forty expeditions against
-- ninety-two quests means the player is constantly choosing which house to advance -- but until now the
-- only thing a day could BE was a story quest, so a day you did not want to spend on somebody's errand
-- was a day you could not spend at all. That is a clock with one hand.
--
-- A request run is the other hand: a procedurally rolled board with no story attached, taken on behalf
-- of a house you name. It pays that house's stock and gold, and nothing else.
--
-- WHAT IT DELIBERATELY DOES NOT PAY, each for its own reason:
--
--   standing      A house's standing IS its finished-quest count (Quest.sponsorProgress), which drives
--                 its shelf. Paying standing for a foraging trip would let a player buy the whole
--                 catalogue without running a single line, which is the campaign.
--   the ledger    Nothing is written to `completedQuests`. A request is not a quest and must never
--                 appear to have been one -- it has no id in Quest.defs, so anything that resolves an
--                 id skips it, and this is why it is synthesized rather than authored.
--   a companion, a relic, a discipline
--                 All of those are what a LINE hands over. A day of foraging buys materials.
--
-- WHY IT IS A SYNTHESIZED QUEST DESCRIPTOR rather than a new kind of run: states/game.lua already knows
-- how to enter one, roll a board for it, apply the extraction rule to it and resume it. The descent
-- takes exactly this route (Descent.floorQuest) for exactly this reason -- a descriptor that is not in
-- Quest.defs is a first-class run everywhere except the places that look an id up, which are precisely
-- the places that should skip it.
--
-- THE HAUL IS STILL EARNED. A request board has an objective like any other, so the extraction rule
-- applies unchanged: the finds are provisional until it is cleared, and a walk-out or a wipe voids
-- them (docs/overworld.md). What it costs either way is the day.
--
-- Pure model -- no love.graphics -- so it loads under the headless runner.

local Vendor = require("models.vendor")
local Material = require("models.material")
local Biome = require("models.biome")

local Request = {}

-- The id prefix. Never in Quest.defs by construction, and checked as a prefix rather than by a flag in
-- the one place that has only the id to go on (states/game.lua's resume path).
Request.ID_PREFIX = "request_"

-- What a foraging day is worth in coin. Modest on purpose and deliberately flat: the point of the run
-- is the house stock it tags and the caches it walks to, both of which scale with the board and the
-- detours taken (models/spoils.lua, Overworld:placeCaches). Gold on top is the incidental part.
--
-- Under what a story quest pays, so a request run is never the efficient way to earn -- it is the way
-- to earn THE THING YOU NEED, from the house you need it from.
-- 50 rather than a round hundred because the cheapest posted quest in the campaign pays 60, and
-- foraging has to sit under ALL of them: the moment a day of ore out-earns the debut, the campaign
-- becomes the inefficient way to play it. Pinned by tests/request_spec.lua against the real minimum, so
-- re-pricing any quest downward fails there rather than quietly inverting this.
Request.GOLD = 50

-- ---------------------------------------------------------------------------
-- What a house asks for
-- ---------------------------------------------------------------------------
--
-- THE VOCABULARY, and it is deliberately small. A request has to be an OBJECTIVE THAT SHARES A BOARD:
-- several of them are accepted for one expedition, so none of them may own the map, dictate its biome,
-- or need a set-piece at the end of it. That rules out most of what an authored quest currently is and
-- is exactly why the story beats have to change shape to fit -- a Bastion beat becomes "bring these
-- people out", which can be one of three things you are doing today and can be half-done.
--
-- THE SHAPE FALLS OUT OF THE SIN, which is the project's own organising principle rather than a new
-- one: what a house wants is a property of what that house IS (docs/story.md). Sloth guards, so the
-- Bastion wants people brought out; envy covets, so the Crucible wants reagents; wrath is what is in
-- front of you, so the Colosseum wants a named thing dead.
--
-- Each kind declares two things and nothing else:
--   seed(board, req)   what it puts on the board, in the board's own terms
--   progress(run, req) how much of it has been done, counted off the run
--
-- Anything a kind cannot express in those two is a set-piece rather than a request, and belongs on a
-- day of its own -- which is where the seven generals stayed.
Request.KINDS = {
    -- GLUTTONY / ENVY / anything that wants stock out of the ground. The cheapest kind, because the
    -- board already grows caches and already tags them by house: a harvest request is a QUOTA over
    -- content that would have been there anyway.
    harvest = {
        label = "Harvest",
        -- Nothing to seed. The caches exist; what the request adds is somebody counting.
        seed = nil,
        progress = function(run, req)
            return (run.haul and run.haul[req.material]) or 0
        end,
    },

    -- SLOTH. The Bastion's shape: people who have to be walked off the board alive. Seeds a real
    -- encounter (data/encounters/encounter_survivors_extract.lua), which already exists because the
    -- prologue's flight leg taught this exact lesson.
    rescue = {
        label = "Rescue",
        seed = function(board, req)
            for _ = 1, (req.quota or 1) do
                board.always[#board.always + 1] = "encounter_survivors_extract"
            end
        end,
        progress = function(run, req)
            return (run.rescued and run.rescued[req.house]) or 0
        end,
    },

    -- WRATH. A named thing, dead. The only kind that names a specific body, which is what keeps it
    -- from being interchangeable with an ordinary fight on the way past.
    fell = {
        label = "Fell",
        seed = function(board, req)
            board.always[#board.always + 1] = req.encounter or "encounter_elite"
        end,
        progress = function(run, req)
            return (run.felled and run.felled[req.encounter or "encounter_elite"]) or 0
        end,
    },
}

-- How many requests one expedition may carry. Three, because the tension is arithmetic: a board holds
-- four or five caches (docs/overworld.md), so three houses asking cannot all be satisfied by a trip
-- that does not take every one of them -- including the guarded ones at the ends of the deep spurs.
--
-- Two would nearly always be fillable and four would nearly never be; three is the count at which
-- "which of these do I give up" is the ordinary outcome rather than the failure case.
Request.MAX_ACCEPTED = 3

-- Is `req` satisfied by what the run did? Read at the payout, and read the same way whether the player
-- cleared the board or turned back at the fourth stop -- partial completion is the point, so this is
-- asked per request rather than once for the expedition.
function Request.met(run, req)
    local kind = req and Request.KINDS[req.kind]
    if not kind then return false end
    return kind.progress(run or {}, req) >= (req.quota or 1)
end

function Request.isRequest(questId)
    return type(questId) == "string" and questId:sub(1, #Request.ID_PREFIX) == Request.ID_PREFIX
end

-- Every house that can be foraged for, as { id, name, material }. Ordered by name so the offer list
-- does not reshuffle between opens. A vendor with no class holds no stock and is skipped -- the Cafe
-- sells suppers, and there is nothing in the ground for it.
function Request.houses()
    local out = {}
    for _, v in ipairs(Vendor.list()) do
        local material = v.class and Material.houseFor(v.class)
        if material then
            out[#out + 1] = { id = v.id, name = v.name, material = material, class = v.class }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- WHERE A HOUSE'S FORAGERS GO. Every biome except the UNDERWORLD, which is where the last door is and
-- is not somewhere anyone runs an errand.
--
-- AUTHORED, AND IT DID NOT USED TO BE. This was a hash of the vendor id's own bytes -- stable, which
-- was the only property it needed while nothing displayed it. "The exact mapping does not matter, only
-- that it holds still" was true right up until the biome windows landed: the board now files a
-- foraging offer under the ground it is run on (ui/panels/quest_board.lua), so the mapping is a thing
-- the player reads, plans around, and finds shut some mornings. An arbitrary answer to a question the
-- player can see is just a wrong answer that happens to be consistent.
--
-- Each house's country is where its own quests are, read off data/quests (`. biome-report`'s census)
-- rather than off the sin table in models/descent.lua -- those are the descent's circles, and two of
-- them name ground their house has never once been sent to (the Alchemist has no desert quest, the
-- Undercroft no underworld one). The descent keeps its mapping; this is the campaign's.
--
-- THE COLOSSEUM GETTING ITS OWN GROUND RE-DEALT THREE OF THESE, and the re-deal is what the rule above
-- reads like when it is applied twice. The bowl (data/biomes/colosseum.lua) took nine of that house's
-- quests off the sand, so the Colosseum forages in it -- which left the desert with nobody. The
-- Undercroft is the only other house with any desert presence at all (three quests), so it moves there,
-- and the castle it was holding goes to the Cathedral, whose eight castle quests were always its
-- heaviest ground and which only ever sat in the forest because the castle was taken. Nobody was moved
-- to fill a hole who had no business in the hole.
Request.BIOMES = {
    alchemist = "swamp", -- 4 swamp quests, and the only house with a real swamp presence
    -- The Arcanum's own quests are castle-heaviest, and it is sent to the volcanic waste anyway: the
    -- Cathedral now works the castle, and a ground with no house foraging it would draw no tab on
    -- the mornings its quests happen to be elsewhere. Every ground but the underworld owes the player
    -- SOMETHING, or an open window is just a shut one that lies. The Arcanum has two volcanic quests
    -- and the fewest reasons to be underground, so it is the one that moves.
    arcanum = "volcanic",
    bastion = "tundra", -- 6 of its 10 slots, and sloth's own ground
    cathedral = "castle", -- 8 of its 10, and the ground it always worked
    colosseum = "colosseum", -- 9 of its 10: its errand is a card, and a card is fought in the bowl
    hunters_lodge = "forest", -- 8 of its 10
    undercroft = "desert", -- 3, the most of anyone now the Colosseum has gone indoors
}

-- A house's country. Falls back to the forest for a house with no row, so adding a vendor cannot
-- crash a foraging run before its ground has been decided.
function Request.biomeFor(vendorId)
    local id = Request.BIOMES[vendorId]
    if id and Biome.defs[id] then return id end
    return Biome.defs.forest and "forest" or nil
end

-- The houses that forage in `biomeId`, in the order Request.houses returns them. The board draws one
-- row per house under the ground's own tab, so a day of ore costs the same travel decision a quest
-- does -- and an open ground is never a dead end, because somebody always works it.
function Request.housesIn(biomeId)
    local out = {}
    for _, house in ipairs(Request.houses()) do
        if Request.biomeFor(house.id) == biomeId then out[#out + 1] = house end
    end
    return out
end

-- WHAT THE HOUSES HAVE POSTED TODAY. One per house that holds stock, of the shape that house asks in.
--
-- Deterministic from the DAY rather than rolled, which is what lets a player plan: the board you see on
-- day 12 is the board day 12 has, so "I will come back for the Crucible's ore tomorrow" is a sentence
-- that means something. Rolling it fresh on every open would make the offer a slot machine and the
-- decision meaningless.
--
-- The quota rises with the calendar, gently. A day-1 request wants two of something and a day-38 one
-- wants four -- enough that a late request is a real trip, not so much that it outgrows a board.
function Request.offer(player, day)
    day = day or 1
    local out = {}
    for _, house in ipairs(Request.houses()) do
        local kind = Request.KIND_BY_HOUSE[house.id] or "harvest"
        local quota = 2 + math.floor(day / 14)
        out[#out + 1] = {
            id = "req_" .. house.id .. "_" .. day,
            house = house.id,
            houseName = house.name,
            kind = kind,
            material = house.material,
            quota = quota,
            gold = Request.GOLD,
            label = (Request.KINDS[kind] and Request.KINDS[kind].label or "Fetch")
                .. " for " .. house.name,
        }
    end
    return out
end

-- Which shape each house asks in. Derived from the sin, and stated as a table rather than computed
-- because the mapping is an authorial claim about what these houses ARE, not an algorithm.
--
-- Four of seven are `harvest` today, which is honest rather than finished: harvest is the kind that
-- needed no new board content, so it is where the unbuilt ones sit until their shape is authored. The
-- three that differ are the three whose encounters already exist.
Request.KIND_BY_HOUSE = {
    bastion = "rescue",     -- sloth guards; what it wants is people brought out alive
    colosseum = "fell",     -- wrath is what is in front of you: a named thing, dead
    alchemist = "harvest",  -- envy covets: reagents, by the sackful
    hunters_lodge = "fell", -- gluttony takes the quarry
    arcanum = "harvest",    -- pride wants leyglass; `survey` is its real shape, unbuilt
    undercroft = "harvest", -- greed wants it carried home; `retrieve` is its real shape, unbuilt
    cathedral = "harvest",  -- lust holds ground; `hold` is its real shape, unbuilt
}

-- The synthesized quest descriptor for a day foraging on `vendorId`'s behalf.
-- THE DAY'S EXPEDITION, assembled from the requests accepted for it.
--
-- This is the answer to "how is the quest populated": it is not authored and not picked, it is BUILT
-- from what the player took on. Each accepted request seeds its own content onto one shared board
-- (Request.KINDS), the caches are dealt round-robin across every house asking (Overworld:placeCaches),
-- and the board does not grow to fit them -- which is what makes three requests a choice rather than a
-- checklist.
--
-- The biome is the FIRST accepted request's house country, so the day has a place and the player chose
-- it by choosing who to work for first. A destination picked separately, with the day's postings
-- attached to it, is the fuller version of this and is not built.
function Request.expedition(accepted, opts)
    opts = opts or {}
    if not accepted or #accepted == 0 then return nil end

    local lead = accepted[1]
    local board = { always = {} }
    local houseMaterials = {}
    for _, req in ipairs(accepted) do
        local kind = Request.KINDS[req.kind]
        if kind and kind.seed then kind.seed(board, req) end
        if req.material then houseMaterials[#houseMaterials + 1] = req.material end
    end

    local names = {}
    for _, req in ipairs(accepted) do names[#names + 1] = req.houseName or req.house end

    return {
        id = Request.ID_PREFIX .. "day",
        name = #accepted == 1 and (accepted[1].label or "A Day's Work")
            or ("Work for " .. table.concat(names, ", ")),
        description = "What the houses have posted, and one road to do it on. Bring back what you can.",
        difficulty = "Normal",
        sponsor = lead.house,
        rewardGold = 0, -- each request pays its own; the expedition itself pays nothing
        request = true,
        -- Carried onto the run so the payout can ask each one whether it was met.
        requests = accepted,
        map = {
            biome = opts.biome or Request.biomeFor(lead.house),
            keyCount = 0,
            -- Every house asking gets its stock dealt across the caches the board already has.
            houseMaterials = houseMaterials,
            encounters = { always = board.always },
            objective = {
                name = "The Long Way Back",
                composition = function(ctx)
                    local list = {}
                    for _ = 1, 2 + math.floor((ctx.day or 1) / 8) do
                        list[#list + 1] = "character_bandit"
                    end
                    return list
                end,
            },
        },
    }
end

function Request.quest(vendorId, opts)
    opts = opts or {}
    local def = Vendor.get(vendorId)
    if not def then return nil end

    local biome = opts.biome or Request.biomeFor(vendorId)

    return {
        id = Request.ID_PREFIX .. vendorId,
        name = "Foraging for " .. (def.name or vendorId),
        description = "No errand and nobody's story. A day on the road, and whatever the ground gives "
            .. "up, carried back to " .. (def.name or vendorId) .. ".",
        difficulty = "Normal",
        -- The sponsor is what tags the caches and the fight salvage with this house's stock
        -- (states/game.lua resolves houseMaterial off it). It is the whole point of choosing a house.
        sponsor = vendorId,
        rewardGold = Request.GOLD,
        -- THE FLAG states/game.lua BRANCHES ON. A request never reaches Quest.complete: that function
        -- writes the quest ledger, advances the sponsor's standing and runs the whole advancement path,
        -- none of which a foraging day has earned. See Request.payout.
        request = true,
        map = {
            biome = biome,
            keyCount = 0, -- no locked-door puzzle on a day out; the board is the whole of it
            objective = {
                name = "The Long Way Back",
                -- Ordinary opposition, sized by the calendar like everything else on the road. A
                -- request has no set-piece at the end of it -- what is at the end of it is leaving.
                composition = function(ctx)
                    local list = {}
                    for _ = 1, 2 + math.floor((ctx.day or 1) / 8) do
                        list[#list + 1] = "character_bandit"
                    end
                    return list
                end,
            },
        },
    }
end

-- What clearing a request board pays. The small sibling of Quest.complete, and small on purpose: gold,
-- and the run's carried materials. Returns the same shape the reward panel reads, minus everything a
-- foraging day does not earn.
--
-- `carried` is the run's cache haul, exactly as Quest.complete takes it -- the extraction rule is what
-- makes it provisional until this point, and this is the point.
-- PAID PER REQUEST, NOT PER TRIP, which is the whole of "complete them all or only a few".
--
-- `run` is what the expedition actually did -- the haul it carried, who it rescued, what it felled --
-- and each accepted request is asked separately whether that met its quota. Two of three filled pays
-- two of three, and the third is simply not paid; there is no all-or-nothing anywhere in here.
--
-- Read at the payout rather than tracked as a running "complete" flag, so turning back early and
-- clearing the board go through the same arithmetic. The player who leaves at the fourth stop is not on
-- a different code path from the one who cleared it; they just carried less.
function Request.settle(player, quest, run)
    local Player = require("models.player")
    local met, missed, gold = {}, {}, 0
    for _, req in ipairs((quest and quest.requests) or {}) do
        if Request.met(run, req) then
            met[#met + 1] = req
            gold = gold + (req.gold or Request.GOLD)
        else
            missed[#missed + 1] = req
        end
    end
    if gold > 0 then Player.addGold(player, gold) end
    return met, missed, gold
end

-- IT TOOK `day, days` AND REPORTED THEM BACK. That pair filled the advancement panel's bar -- how far
-- into a campaign of forty this run stood -- and both the bar and the forty are retired
-- (models/calendar.lua). Dropped from the signature rather than left accepted and ignored, so nothing
-- passes a reading into a function that no longer has one.
function Request.payout(player, quest, carried)
    local Player = require("models.player")
    local gold = (quest and quest.rewardGold) or Request.GOLD
    Player.addGold(player, gold)

    local materials = {}
    for matId, count in pairs(carried or {}) do
        if count and count > 0 then
            Player.addMaterial(player, matId, count)
            materials[matId] = (materials[matId] or 0) + count
        end
    end

    -- A supper is bought for one expedition and this was one, whatever it was for.
    require("models.meal").clear(player)
    Player.save()

    local standing = Player.questsCompleted(player)
    return {
        gold = gold,
        materials = materials,
        received = {},
        standingBefore = standing, -- unchanged: a request finishes no quest
        standing = standing,
        sponsor = quest and quest.sponsor,
    }
end

return Request
