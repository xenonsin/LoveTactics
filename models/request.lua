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

-- Where a house's foragers go. Every biome except the UNDERWORLD, which is where the last door is and
-- is not somewhere anyone runs an errand.
--
-- Assigned per house rather than rolled, and stable: the Lodge's country is the Lodge's country every
-- time, so a player learns what a foraging day for them looks like. Derived from the id's own
-- characters so adding a house needs no table -- the exact mapping does not matter, only that it holds
-- still.
function Request.biomeFor(vendorId)
    local ids = {}
    for id in pairs(Biome.defs or {}) do
        if id ~= "underworld" then ids[#ids + 1] = id end
    end
    table.sort(ids)
    if #ids == 0 then return "forest" end
    local n = 0
    for i = 1, #tostring(vendorId or "") do n = n + tostring(vendorId):byte(i) end
    return ids[(n % #ids) + 1]
end

-- The synthesized quest descriptor for a day foraging on `vendorId`'s behalf.
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
function Request.payout(player, quest, carried, day, days)
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
        -- The calendar reading the advancement panel fills its bar from. A request run spends a day
        -- like anything else, so it reports one like anything else.
        day = day,
        days = days,
        standingBefore = standing, -- unchanged: a request finishes no quest
        standing = standing,
        sponsor = quest and quest.sponsor,
    }
end

return Request
