-- Tests for the progression layer: the save round trip, the gold/prestige/quest-standing
-- economy, vendor stock derivation and rank gating, quest sponsorship and completion, and
-- the composable `protect` objective.
--
-- The save specs write to a throwaway filename so a developer's real save is never touched.

local Player = require("models.player")
local Building = require("models.building") -- vendorUnlockPrestige: when a house's door opens
local Vendor = require("models.vendor")
local Quest = require("models.quest")
local Item = require("models.item")
local Forge = require("models.forge")
local Discipline = require("models.discipline")
local Save = require("models.save")
local Character = require("models.character")
local Combat = require("models.combat")
local Arena = require("models.arena")
local Growth = require("models.growth")
local Errand = require("models.errand") -- the jobs a house asks for, which are the rungs its bench climbs

-- Run `fn` with Save pointed at a scratch file, cleaning up afterwards either way.
local function withScratchSave(fn)
    local real = Save.FILE
    Save.FILE = "save_spec_scratch.lua"
    local ok, err = pcall(fn)
    Save.clear()
    Save.FILE = real
    if not ok then error(err, 0) end
end

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(id, x, y, control)
    return { char = Character.instantiate(id), x = x, y = y, control = control }
end

-- A player whose CAMPAIGN STANDING is `standing`. Standing is a count of finished quests now
-- (Player.standing) rather than a stored number, so it has to be built rather than assigned -- and the
-- authored gates are still on the old scale, where standing 1 is a fresh save with nothing done.
--
-- Filled with SYNTHETIC ids on purpose. A real quest id would drag its sponsor into
-- Quest.sponsorProgress and quietly open a shelf the case never asked for; an id that is not in
-- Quest.defs is skipped by every reader that resolves one, so this moves the count and nothing else.
local function playerAt(standing)
    local p = Player.new()
    p.completedQuests = {}
    for i = 1, math.max(0, (standing or 1) - 1) do
        p.completedQuests["_standing_filler_" .. i] = true
    end
    return p
end

return {
    -- ---------------------------------------------------------------- economy
    {
        name = "spendGold refuses a purchase the player cannot afford, and charges nothing",
        fn = function()
            local p = Player.new()
            p.gold = 100

            assert(Player.spendGold(p, 40) == true, "should afford 40")
            assert(p.gold == 60, "gold should drop to 60")

            assert(Player.spendGold(p, 61) == false, "should not afford 61")
            assert(p.gold == 60, "a refused purchase must not charge")

            assert(Player.spendGold(p, 60) == true, "spending the exact balance is allowed")
            assert(p.gold == 0, "gold should be spent to zero")
        end,
    },
    {
        name = "Quest.sponsorProgress counts a vendor's finished quests; unknown vendors read zero",
        fn = function()
            local Quest = require("models.quest")
            local p = Player.new()
            assert(Quest.sponsorProgress(p, "colosseum") == 0, "unseen vendor should read 0")
            p.completedQuests = {
                quest_colosseum_slot_01 = true,
                quest_cathedral_slot_01 = true, -- a different sponsor
                quest_bastion_slot_01 = true, -- a different sponsor must not count toward the colosseum
            }
            assert(Quest.sponsorProgress(p, "colosseum") == 1, "only the colosseum's own quests count")
            assert(Quest.sponsorProgress(p, "bastion") == 1, "each sponsor counts independently")
        end,
    },
    {
        -- Replaces a case that pinned Vendor.tier's four-value wave enum. That enum is gone: item gates
        -- moved to per-quest `unlockQuests` and the forge ceiling onto the errand ladder, which left it
        -- with no callers. What the case was really protecting -- "standing with a house turns into a
        -- deeper ladder, one house at a time" -- is what is checked here instead.
        --
        -- IT WALKED EVERY QUEST THE BASTION SPONSORS and demanded exactly one rung apiece, which is the
        -- assumption that broke when the shelves were re-cut: a house asks for six errands and sponsors
        -- thirteen, so the old claim was measured on a line no player can run and the step is no longer
        -- a constant. The two ENDS are the contract now -- an unworked house opens CEILING_BASE, a
        -- finished ladder opens the whole bench -- and in between it may only climb.
        name = "a house's forge ceiling climbs with its class level and tops out at the ladder's end",
        fn = function()
            local Disc = require("models.discipline")
            local p = Player.new()
            local sword = Item.instantiate("weapon_iron_sword") -- knight gear -> the knight ladder

            -- A fresh company holds no class levels at all, whatever its bodies have been doing, so the
            -- bench opens where every bench opens.
            for _, c in ipairs(p.roster) do c.technique = {} end
            assert(Forge.ceilingFor(p, sword) == Forge.CEILING_BASE,
                "a fresh save opens at the base ceiling")

            local body = p.roster[1]
            local prev = Forge.ceilingFor(p, sword)
            for level = 1, Disc.CLASS_LEVEL_CAP do
                body.technique.knight = Disc.classLevelCost(level)
                local ceiling = Forge.ceilingFor(p, sword)
                assert(ceiling >= prev, "knight " .. level .. " must never lower the ceiling")
                assert(ceiling <= Item.MAX_LEVEL, "and must never pass the top of the curve")
                prev = ceiling
            end
            assert(prev == Item.MAX_LEVEL, "a mastered class reaches the top of the curve")

            -- The ladder is laid over the rungs the class has, so re-cutting it moves the size of a step
            -- and never where it stops. Halfway up the class is halfway up the bench.
            body.technique.knight = Disc.classLevelCost(math.floor(Disc.CLASS_LEVEL_CAP / 2))
            local mid = Forge.ceilingFor(p, sword)
            assert(mid > Forge.CEILING_BASE and mid < Item.MAX_LEVEL,
                "half a ladder buys real rungs and stops short of the top, got +" .. mid)

            -- READ AS THE ROSTER'S BEST HOLDER, which is the same reading every company-facing question
            -- about the ladder takes: specializing one body opens the deep end, and spreading the same
            -- tally over four does not. A second body who has never touched knight gear cannot pull the
            -- bench back down.
            p.roster[#p.roster + 1] = { level = 1, technique = {} }
            assert(Forge.ceilingFor(p, sword) == mid, "a body with no knight play does not lower the bench")
        end,
    },
    {
        name = "Player.restore refills every roster member's resources, leaving flat stats alone",
        fn = function()
            local p = Player.new()
            local knight = p.roster[1]

            knight.stats.health.current = 1
            knight.stats.mana.current = 0
            knight.stats.stamina.current = 3
            local movement = knight.stats.movement

            Player.restore(p)

            assert(knight.stats.health.current == knight.stats.health.max, "health should refill")
            assert(knight.stats.mana.current == knight.stats.mana.max, "mana should refill")
            assert(knight.stats.stamina.current == knight.stats.stamina.max, "stamina should refill")
            assert(knight.stats.movement == movement, "flat stats must not be touched")
        end,
    },
    {
        name = "Player.restore reaches every roster member, fielded last battle or not",
        fn = function()
            local p = Player.new()
            local benched = assert(Player.recruit(p, "character_saber"))
            Player.noteDeployed(p, { p.roster[1] }) -- the newcomer sat out the last fight
            benched.stats.health.current = 5

            Player.restore(p)
            assert(benched.stats.health.current == benched.stats.health.max,
                "a benched character rests too")
        end,
    },

    -- ----------------------------------------------------------------- vendor
    {
        name = "vendor registry discovers all seven class vendors, each claiming one deadly sin",
        fn = function()
            local claimed = {}
            for _, id in ipairs({ "colosseum", "cathedral", "hunters_lodge", "bastion",
                                  "arcanum", "undercroft", "alchemist" }) do
                local def = Vendor.defs[id]
                assert(def, id .. " vendor missing")
                assert(def.sin, id .. " names no sin")
                assert(not claimed[def.sin], "two vendors claim " .. tostring(def.sin))
                claimed[def.sin] = true
            end
            -- Seven vendors, seven sins, one each: the shape the whole endgame hangs off.
            for _, sin in ipairs({ "wrath", "lust", "gluttony", "sloth", "pride", "greed", "envy" }) do
                assert(claimed[sin], "no vendor claims " .. sin)
            end
        end,
    },
    {
        name = "Vendor.stock sells only items of its own class, and only priced ones",
        fn = function()
            local stock = Vendor.stock("undercroft", 4)
            assert(#stock > 0, "the Undercroft should stock something")

            local ids = {}
            for _, entry in ipairs(stock) do
                ids[entry.id] = true
                -- A discipline item is a legitimate guest on a parent's shelf even when its own `class`
                -- is the OTHER parent (docs/classes.md): a Poacher item (rogue x hunter) sits on the
                -- rogue shelf whether its home class is rogue or hunter.
                local bp = Item.defs[entry.id]
                local onShelf = bp.class == "rogue"
                for _, p in ipairs(bp.discipline and Discipline.parents(bp.discipline) or {}) do
                    if p == "rogue" then onShelf = true end
                end
                assert(onShelf, entry.id .. " is on the rogue shelf without being a rogue item or a rogue-discipline guest")
                assert(entry.price, entry.id .. " is for sale with no price")
            end

            assert(ids.ability_pickpocket, "pickpocket should be a rogue item")
            assert(not ids.iron_sword, "the iron sword is a fighter item, not a rogue one")
        end,
    },
    {
        name = "Vendor.stock shows quest-locked items, flagged rather than hidden",
        fn = function()
            local low = Vendor.stock("colosseum", 0)
            local high = Vendor.stock("colosseum", 999)
            assert(#low == #high, "the shelf is the same length at every quest count")

            -- A discipline item carries a SECOND lock (its discipline must be unlocked) that quests never
            -- lift, so it is not part of this quest-only measure -- count only quest-gated wares.
            local lockedAtLow, lockedAtHigh = 0, 0
            for _, e in ipairs(low) do if e.locked and not e.discipline then lockedAtLow = lockedAtLow + 1 end end
            for _, e in ipairs(high) do if e.locked and not e.discipline then lockedAtHigh = lockedAtHigh + 1 end end

            assert(lockedAtLow > 0, "a player with no quests done should see items they cannot buy yet")
            assert(lockedAtHigh == 0, "a player past every gate should have everything quest-unlocked")
        end,
    },
    {
        -- The point of the whole rescale (tools/unlock_rescale): a shelf that used to move four times a
        -- campaign now moves every quest. Asserted as a floor rather than an exact shape, so retuning a
        -- house's stock does not break the test -- what must not come back is the clumping.
        name = "every house's shelf opens something on nearly every quest of its line",
        fn = function()
            local Errand = require("models.errand")
            for vendorId, vdef in pairs(Vendor.defs) do
                if vdef.sells ~= false and Discipline.CLASS_LEVEL_CAP > 0 then
                    -- THE LINE IS THE LADDER, not the count of quests a house sponsors. A house asks for
                    -- the work that OPENS something -- its opener and the jobs its disciplines hang off
                    -- (models/errand.lua) -- and the rest of what it sponsors is not on any shelf's
                    -- ladder at all, so walking every sponsored quest here reads the plain numbered
                    -- fights as gates that opened nothing.
                    local rungs = Discipline.CLASS_LEVEL_CAP
                    -- How many rows each rung newly unlocks, walked up the ladder.
                    local seen, silent = 0, {}
                    for done = 0, rungs - 1 do
                        local open = 0
                        for _, e in ipairs(Vendor.stock(vendorId, done)) do
                            if (e.unlockQuests or 0) <= done then open = open + 1 end
                        end
                        if open == seen then silent[#silent + 1] = done end
                        seen = open
                    end
                    -- At most one quiet quest per line: an even spread over 12-14 quests leaves room
                    -- for a rounding gap, never for a four-quest silence.
                    assert(#silent <= 1, vendorId .. " opens nothing on quests: " .. table.concat(silent, ", "))
                    assert(seen > 0, vendorId .. " never opens anything at all")
                end
            end
        end,
    },
    {
        name = "every class has a vendor, and every vendor has an opening-shelf item to sell",
        fn = function()
            for class in pairs(Item.CLASSES) do
                local vendorId
                for id, def in pairs(Vendor.defs) do
                    if def.class == class then vendorId = id end
                end
                assert(vendorId, "class '" .. class .. "' has no vendor")

                local entry = Vendor.stock(vendorId, 0)[1]
                assert(entry and not entry.locked,
                    vendorId .. " has nothing a new player can buy")
            end
        end,
    },
    {
        name = "every priced item has a shelf, and every shelf is a class vendor",
        fn = function()
            -- There is no general store any more. The Cafe was one -- classless goods plus a potion
            -- resale rack -- and it sells suppers now (models/meal.lua), so a price with no class is
            -- once again unbuyable dead data with nowhere to go.
            for id, def in pairs(Item.defs) do
                if def.class then
                    assert(Item.CLASSES[def.class], id .. " has unknown class '" .. def.class .. "'")
                else
                    assert(not def.price,
                        id .. " has a price but no class -- no vendor can stock it (docs/classes.md)")
                end
            end
        end,
    },
    {
        -- The five wares that were classless while the Cafe was a general store, each now on the house
        -- that actually wanted it -- and each on that house's OPENING shelf, since being available from
        -- the first visit was the one thing the general store was really providing.
        name = "the redistributed general goods sit on a class shelf, un-gated",
        fn = function()
            local homes = {
                utility_torch = "hunter",
                utility_boots_of_speed = "rogue",
                utility_stormglass_rod = "mage",
                consumable_witchlight_flare = "alchemist",
                utility_wellspring_sandals = "alchemist",
            }
            for id, class in pairs(homes) do
                local def = Item.defs[id]
                assert(def, id .. " has gone missing")
                assert(def.class == class, id .. " should be sold by " .. class)
                assert((def.unlockQuests or 0) == 0,
                    id .. " was available from the first visit at the Cafe and must stay so")

                local vendorId
                for vid, vdef in pairs(Vendor.defs) do
                    if vdef.class == class then vendorId = vid end
                end
                local found
                for _, entry in ipairs(Vendor.stock(vendorId, 0)) do
                    if entry.id == id then found = entry end
                end
                assert(found and not found.locked,
                    id .. " is not buyable at " .. tostring(vendorId) .. " on the opening shelf")
            end
        end,
    },
    {
        name = "the Cafe stocks no items at all, and its potions went home to the Crucible",
        fn = function()
            local cafe = Vendor.defs.cafe
            assert(cafe and cafe.sells == false, "the Cafe declares that it sells no items")
            assert(#Vendor.stock("cafe", 999) == 0, "the Cafe's shelf is empty at any standing")
            assert(not Vendor.hasMarkedStock("cafe", { consumable_healing_potion = true }),
                "and nothing a quest opens can ever dot the Cafe's door")

            -- The resale is gone: a potion is sold by the house that brews it and nowhere else.
            assert(Item.defs.consumable_healing_potion.class == "alchemist",
                "the healing potion is an alchemist item")
            local atAlchemist
            for _, entry in ipairs(Vendor.stock("alchemist", 0)) do
                if entry.id == "consumable_healing_potion" then atAlchemist = entry end
            end
            assert(atAlchemist and not atAlchemist.locked,
                "the Crucible sells its steadiest seller from the opening shelf -- nowhere else does now")

            -- And no shelf refines anything: every recipe is honed at the Forge (models/forge.lua).
            assert(Vendor.canRefineHere == nil and Vendor.upgradeRecipe == nil,
                "a vendor sells; upgrading moved to the Forge")
        end,
    },
    {
        name = "class survives instantiation and is absent on universal items",
        fn = function()
            assert(Item.instantiate("weapon_iron_sword").class == "knight", "class should reach the instance")
            assert(Item.classOf(Item.instantiate("weapon_iron_sword")) == "knight", "classOf should read it")
            assert(Item.instantiate("weapon_unarmed").class == nil, "the unarmed fallback belongs to no class")
        end,
    },
    {
        name = "blueprints are untouched after Vendor.stock",
        fn = function()
            Vendor.stock("colosseum", 1)
            assert(Item.defs.weapon_iron_sword.locked == nil, "item blueprint gained a `locked` field")
            assert(Item.defs.weapon_iron_sword.id == nil, "item blueprint gained an `id` field")
        end,
    },

    -- ------------------------------------------------------------------ quest
    {
        -- EVERY quest is sponsored now, where one used to be exempt: the Gate Below answered to all
        -- seven houses and so to none of them, and it went with the retired board. A house is what seats
        -- a quest on a floor (models/errand.lua asks Errand.forVendor per vendor), so an unsponsored one
        -- is unreachable by construction rather than special.
        name = "every quest names a sponsoring vendor that exists",
        fn = function()
            for id, def in pairs(Quest.defs) do
                assert(def.sponsor, id .. " has no sponsor, so no house can ever seat it")
                assert(Vendor.defs[def.sponsor], id .. " names unknown sponsor " .. tostring(def.sponsor))
            end
        end,
    },
    -- ------------------------------------------- WHAT THE QUEST BOARD TOOK WITH IT
    --
    -- Six cases stood here and every one asked what the player may PICK today: whether
    -- Quest.available dropped a finished quest and opened the next, whether it hid one behind a
    -- sponsor gate, whether it copied requiredQuests and rewardItems onto its runtime entry, and
    -- three about the Gate Below being hidden, then locked, then keyed.
    --
    -- Picking is what the board did. A descent seats work on its floors (models/errand.lua), so
    -- Quest.available is gone and the Gate Below with it -- the ending is the Hollow Crown at the
    -- bottom of a run, and tests/ending_spec.lua guards it now.
    --
    -- One rule they protected is worth writing down even with nowhere left to assert it: what
    -- opened the endgame was the quest you FINISHED, never an item you were still holding, so
    -- selling or re-equipping a trophy could not soft-lock the game.
    {
        name = "a house's opener is its own line's first slot, and it is reachable",
        fn = function()
            -- THIS CASE HAS BEEN REVERSED THREE TIMES and the current answer is the plainest of them.
            --
            -- It began as "a house's work waits for the house's door to open": a Bastion quest stayed off
            -- the board until prestige 2, because a quest pointing at a locked door is an errand the
            -- player cannot spend the reward of. That rule needed a house that is NOT open from the
            -- start, and there is no longer any such thing on the prestige scale -- the seven doors carry
            -- no `unlockPrestige` at all now, because the number is parked at 1 forever with the board
            -- retired (Player.standing).
            --
            -- What replaced it inverts the dependency rather than retuning it. `slot_01` of a house's own
            -- line IS the door: it is seated on a descent floor unasked, and running it opens the shop
            -- (models/errand.lua's Errand.opener). So the first piece of work no longer waits for the
            -- door -- it is the thing that opens it, which is the only arrangement where a shut house can
            -- ever be opened by a player who has never been able to talk to it.
            --
            -- Pinned here because the failure is silent in exactly the way the old prestige gate was: an
            -- opener that does not exist, or that belongs to another house, is a card that never turns
            -- over and nothing errors.
            local Errand = require("models.errand")
            local Vendor = require("models.vendor")

            for vendorId, vdef in pairs(Vendor.defs) do
                if vdef.class then
                    local opener = Errand.opener(vendorId)
                    assert(opener, vendorId .. " has no opener, so its door can never be opened")
                    assert(Quest.defs[opener], vendorId .. "'s opener is not a quest: " .. tostring(opener))
                    assert(Quest.defs[opener].sponsor == vendorId,
                        vendorId .. "'s opener belongs to " .. tostring(Quest.defs[opener].sponsor))
                    assert(Quest.defs[opener].map and Quest.defs[opener].map.objective,
                        opener .. " has no objective, so no floor can seat it")

                    -- And it is SLOT ONE specifically, which is not the same as the head of the line:
                    -- Errand.forVendor sorts by id, so a house whose line carries a story quest gets it
                    -- sorted in by alphabet. The Colosseum's door was opening on its Champion's
                    -- Challenge and the Crucible's on Ren's recruit, because "champions" and
                    -- "apothecary" both precede "slot". Neither is the job a house posts to introduce
                    -- itself, and a door on the wrong one is a shelf nobody reaches.
                    assert(opener:match("_slot_01$"),
                        vendorId .. "'s opener is " .. opener .. ", not its first slot")

                    -- Running it opens the door and nothing else does.
                    local shut, open = Player.new(), Player.new()
                    shut.completedQuests, open.completedQuests = {}, { [opener] = true }
                    assert(not Errand.doorOpen(shut, vendorId), vendorId .. " opens without its opener")
                    assert(Errand.doorOpen(open, vendorId), vendorId .. " stays shut with its opener run")
                end
            end
        end,
    },
    {
        name = "Quest.complete grants gold and standing, and advances the sponsor, exactly once",
        fn = function()
            local p = playerAt(1)
            p.gold = 0

            local quest = Quest.get("quest_colosseum_slot_01")
            assert(quest, "arena_debut should be available at prestige 1")

            local before = Quest.sponsorProgress(p, "colosseum")
            local reward = Quest.complete(p, quest)
            assert(reward, "completing a fresh quest should pay out")
            assert(p.gold == quest.rewardGold, "gold should be granted")
            -- Campaign standing is a count of finished quests now. Prestige is gone: it was one number
            -- doing two jobs, and both moved -- standing here, the world's difficulty onto the calendar
            -- (models/calendar.lua).
            assert(Player.questsCompleted(p) == 1, "finishing a quest is what advances standing")
            assert(reward.standing == 1 and reward.standingBefore == 0,
                "the reward reports standing either side, for the panel that used to draw a prestige bar")
            assert(Player.hasCompleted(p, "quest_colosseum_slot_01"), "the quest should be marked completed")
            assert(Quest.sponsorProgress(p, "colosseum") == before + 1,
                "finishing the quest is what advances the Colosseum's standing")
            assert(reward.sponsorQuests == before + 1, "the reward should report the sponsor's new quest count")

            -- A second payout is refused: the objective tile could otherwise be re-cleared.
            local gold, standing = p.gold, Player.questsCompleted(p)
            assert(Quest.complete(p, quest) == nil, "a completed quest must not pay twice")
            assert(p.gold == gold and Player.questsCompleted(p) == standing,
                "the refused payout must grant nothing")
        end,
    },

    {
        -- The run's forging haul: the caches the party walked to PLUS the objective fight's own salvage
        -- (states/game.lua merges the two before calling this). Both ride the double-payout guard, and
        -- both must be named in the reward table -- that table is the only place the post-quest panel
        -- can read them off, and before it did, the whole material economy moved in silence.
        name = "Quest.complete banks the run's carried materials, names them, and never twice",
        fn = function()
            local Material = require("models.material")
            local p = playerAt(1)
            local scrap, house = "material_iron_scrap", Material.houseFor("knight")
            assert(Material.get(scrap) and house, "the fixture materials must exist")
            local before = Player.materialCount(p, scrap)

            local quest = { id = "quest_colosseum_slot_01", rewardGold = 0, sponsor = "colosseum",
                rewardMaterials = { [scrap] = 1 } }
            -- 2 scrap from a cache + 1 more from the general's salvage, plus the quest's own 1.
            local reward = Quest.complete(p, quest, { [scrap] = 3, [house] = 1 })
            assert(reward, "a fresh quest should pay out")
            assert(Player.materialCount(p, scrap) == before + 4,
                "the quest's own materials and the carried haul should both bank")
            assert(Player.materialCount(p, house) == 1, "the house stock should bank too")
            assert(reward.materials[scrap] == 4 and reward.materials[house] == 1,
                "the reward table must name the whole haul, for the advancement panel to print")

            local held = Player.materialCount(p, scrap)
            assert(Quest.complete(p, quest, { [scrap] = 3 }) == nil, "a re-clear pays nothing")
            assert(Player.materialCount(p, scrap) == held, "...including no second haul")
        end,
    },

    {
        -- IT WAS IRA'S MAIL, off quest_colosseum_slot_10 with the nine slots in front of it faked into
        -- completedQuests. That quest went with the retired board, and a general's relic does not come
        -- off a quest any more -- it comes off the body standing on her circle's stair (models/descent
        -- .lua's DROPS, pinned by tests/sin_drops_spec.lua).
        --
        -- What is left here is the rule that was always this case's real subject and is asserted nowhere
        -- else: Quest.complete puts a quest's rewardItems in the stash, once, and a second clear of the
        -- same quest pays nothing. The debut carries rewardItems, so it does the job.
        name = "Quest.complete grants a quest's items into the stash exactly once",
        fn = function()
            local p = playerAt(5)
            local quest = Quest.get("quest_colosseum_slot_01")
            assert(quest, "the debut should resolve")

            local function stashCount(id)
                local n = 0
                for _, item in ipairs(p.stash) do
                    if item.id == id then n = n + 1 end
                end
                return n
            end
            assert(stashCount("weapon_ledgemans_axe") == 0, "the axe starts on nobody")

            local reward = Quest.complete(p, quest)
            assert(stashCount("weapon_ledgemans_axe") == 1, "finishing it drops the axe into the stash")
            assert(reward.received and #reward.received > 0,
                "and the summary names what was received, for the reward panel")

            assert(Quest.complete(p, quest) == nil, "a second clear pays nothing")
            assert(stashCount("weapon_ledgemans_axe") == 1, "and mints no second copy")
        end,
    },
    {
        name = "Player.grantItem stacks a consumable rather than filling the stash with singles",
        fn = function()
            local p = Player.new()
            p.stash = {}
            Player.grantItem(p, "consumable_healing_potion")
            Player.grantItem(p, "consumable_healing_potion")
            assert(#p.stash == 1, "two potions collapse into one stack")
            assert(p.stash[1].quantity == 2, "and the stack counts both")
        end,
    },
    {
        name = "Quest.complete names the wares its completion put on the sponsor's shelf",
        fn = function()
            local p = playerAt(1)
            -- The shelf as the player would see it walking in before the quest (same three gates the
            -- shop reads: shelf rung, discipline unlocked, discipline level). The rung rather than the
            -- standing, because the first errand a house is run for buys its door -- Quest.shelfRung.
            local function shelf()
                local locked = {}
                for _, entry in ipairs(Vendor.stock("colosseum", Quest.shelfRung(p, "colosseum"),
                        p.recipes, Discipline.unlockedSet(p), Discipline.levelSet(p))) do
                    locked[entry.id] = entry.locked
                end
                return locked
            end

            local before = shelf()
            local reward = Quest.complete(p, { id = "quest_colosseum_slot_01", sponsor = "colosseum", rewardGold = 0 })
            local after = shelf()

            local opened = 0
            for id, wasLocked in pairs(before) do
                if wasLocked and not after[id] then opened = opened + 1 end
            end

            if opened == 0 then
                assert(reward.unlockedStock == nil, "a quest that opened nothing announces nothing")
            else
                local stock = reward.unlockedStock
                assert(type(stock) == "table", "a quest that opened stock reports it")
                assert(stock.vendorId == "colosseum", "and names the house whose shelf moved")
                assert(stock.vendor and stock.vendor ~= "colosseum", "by its shop name, not its id")
                assert(#stock.items == opened, "listing exactly the items that came off the gate")
                for _, item in ipairs(stock.items) do
                    assert(before[item.id] and not after[item.id], item.id .. " should be newly on sale")
                    assert(item.name, "each named for the panel")
                end
            end
        end,
    },
    {
        name = "Quest.complete announces no new stock when the completion opened none",
        fn = function()
            local p = playerAt(1)
            -- An unsponsored quest (the Gate Below is one) moves no house's standing, so no shelf moves.
            local reward = Quest.complete(p, { id = "quest_spec_unsponsored", rewardGold = 0 })
            assert(reward.unlockedStock == nil, "no sponsor, no shelf to open")
        end,
    },

    -- ------------------------------------------------------ unseen (red dot) marks
    {
        name = "an item granted into the stash is marked unseen until it is looked at",
        fn = function()
            local p = Player.new()
            p.newItems = {}
            assert(not Player.isNew(p, Player.NEW_STASH, "consumable_healing_potion"),
                "nothing is new before it arrives")

            Player.grantItem(p, "consumable_healing_potion")
            assert(Player.isNew(p, Player.NEW_STASH, "consumable_healing_potion"),
                "a granted item wears the dot")

            assert(Player.seeNew(p, Player.NEW_STASH, "consumable_healing_potion") == true,
                "looking at it clears the mark, and reports that it did")
            assert(not Player.isNew(p, Player.NEW_STASH, "consumable_healing_potion"), "and it stays cleared")
            assert(Player.seeNew(p, Player.NEW_STASH, "consumable_healing_potion") == false,
                "a second look changes nothing, so the caller does not re-save")
        end,
    },
    {
        name = "the two unseen ledgers are separate: reading a stash mark leaves the shelf mark standing",
        fn = function()
            local p = Player.new()
            Player.markNew(p, Player.NEW_STASH, "weapon_iron_sword")
            Player.markNew(p, Player.NEW_STOCK, "weapon_iron_sword")

            Player.seeNew(p, Player.NEW_STASH, "weapon_iron_sword")
            assert(Player.isNew(p, Player.NEW_STOCK, "weapon_iron_sword"),
                "owning one is not the same news as a house starting to sell it")
        end,
    },
    {
        name = "Quest.complete marks the stock it opened as unseen, so the shop can dot it",
        fn = function()
            local p = playerAt(1)
            p.newStock = {}
            local reward = Quest.complete(p, { id = "quest_colosseum_slot_01", sponsor = "colosseum", rewardGold = 0 })
            for _, item in ipairs(reward.unlockedStock and reward.unlockedStock.items or {}) do
                assert(Player.isNew(p, Player.NEW_STOCK, item.id),
                    item.id .. " was announced as new stock, so it must carry the mark the shop draws")
            end
        end,
    },
    {
        -- THE DOT IS THE MARKET'S NOW, and there is only one door to wear it.
        --
        -- This case used to complete a quest and assert the dot landed on that house's counter and no
        -- other. Both halves are gone: there is one counter (data/buildings/market.lua), and finishing
        -- a quest no longer opens stock at all -- a shelf rung is a class level now
        -- (Quest.shelfRung), so what opens a band is a body levelling, not a job being run.
        --
        -- KNOWN GAP, recorded here because this is where it would have been caught: nothing yet DIFFS
        -- the shelf when a class level rises, so a rung can open with no dot on the door. Quest.complete
        -- still carries the diff machinery (Quest.openedStock) and now has nothing to diff. What is
        -- pinned below is the half that still holds -- unread stock dots the door, reading it puts the
        -- dot out -- so the marking contract cannot rot while the trigger is re-hung.
        name = "unread stock dots the market's door, and reading it clears the dot",
        fn = function()
            local p = playerAt(1)
            p.newStock = {}
            assert(not Vendor.hasMarkedStock("market", p.newStock),
                "an unread shelf is the only thing that dots a door")

            local sample
            for _, row in ipairs(Vendor.stock("market", 0)) do
                if not row.locked then sample = row.id; break end
            end
            assert(sample, "the market stocks something at the opening rung")

            Player.markNew(p, Player.NEW_STOCK, sample)
            assert(Vendor.hasMarkedStock("market", p.newStock),
                "stock the player has not seen wears the dot")

            Player.seeNew(p, Player.NEW_STOCK, sample)
            assert(not Vendor.hasMarkedStock("market", p.newStock),
                "and reading the shelf puts it out")
        end,
    },
    {
        name = "a stash mark dots the Armory's door, and only while the item is still in the stash",
        fn = function()
            local p = Player.new()
            p.newItems = {}
            p.stash = {}
            assert(not Player.hasNewStash(p), "an unread stash is the only thing that dots that door")

            Player.grantItem(p, "consumable_healing_potion")
            assert(Player.hasNewStash(p), "a granted item lights the Armory")

            -- The mark stands, but the item is gone (sold, or carried off into a character's grid):
            -- a door that points at nothing must not keep glowing.
            p.stash = {}
            assert(not Player.hasNewStash(p), "a mark with nothing behind it is not news")

            p.stash = { Item.instantiate("consumable_healing_potion") }
            assert(Player.hasNewStash(p), "and it is news again the moment the item is back")
            Player.seeNew(p, Player.NEW_STASH, "consumable_healing_potion")
            assert(not Player.hasNewStash(p), "reading the stash takes the dot off the door")
        end,
    },
    {
        name = "New Game+ clears the shelf marks, since every shelf re-locked with the quest ledger",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                Player.active = p
                Player.markNew(p, Player.NEW_STOCK, "weapon_iron_sword")
                Player.markNew(p, Player.NEW_STASH, "weapon_iron_sword")

                Player.newGamePlus(p)
                assert(not Player.isNew(p, Player.NEW_STOCK, "weapon_iron_sword"),
                    "nothing on a shelf that dropped back to its opening stock is new")
                assert(Player.isNew(p, Player.NEW_STASH, "weapon_iron_sword"),
                    "the stash carries over, and so do its marks")
                Player.active = nil
            end)
        end,
    },

    -- ------------------------------------------------------------------- save
    {
        name = "a save round trip preserves the unseen marks on both ledgers",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                Player.markNew(p, Player.NEW_STASH, "consumable_healing_potion")
                Player.markNew(p, Player.NEW_STOCK, "weapon_iron_sword")
                Player.markNew(p, Player.NEW_STOCK, "item_that_no_longer_exists")

                Save.write(p)
                local loaded = Save.read()

                assert(Player.isNew(loaded, Player.NEW_STASH, "consumable_healing_potion"),
                    "a stash mark survives -- a dot must not be cleared by closing the game")
                assert(Player.isNew(loaded, Player.NEW_STOCK, "weapon_iron_sword"), "and so does a shelf mark")
                assert(not Player.isNew(loaded, Player.NEW_STOCK, "item_that_no_longer_exists"),
                    "an id no longer in data/ is dropped rather than dotting nothing")
            end)
        end,
    },
    {
        name = "a save round trip preserves gold, prestige and completed quests",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                p.gold = 777
                p.prestige = 4
                p.completedQuests.quest_colosseum_slot_01 = true

                assert(Save.write(p), "save should write")
                assert(Save.exists(), "the save file should exist")

                local loaded = Save.read()
                assert(loaded, "save should read back")
                assert(loaded.gold == 777, "gold should survive")
                assert(loaded.prestige == 4, "prestige should survive")
                assert(Player.hasCompleted(loaded, "quest_colosseum_slot_01"),
                    "completed quests should survive -- and with them the vendor standing they represent")
            end)
        end,
    },
    {
        name = "a save round trip preserves the roster, party identity, and each 3x3 grid cell",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                -- Park an item in a deliberately sparse cell: adjacency auras depend on placement,
                -- so the exact cell is gameplay state and must survive.
                local knight = p.roster[1]
                knight.inventory = {}
                knight.inventory[7] = Item.instantiate("consumable_fire_stone")

                Save.write(p)
                local loaded = Save.read()

                assert(#loaded.roster == #p.roster, "roster size should survive")
                assert(loaded.roster[1].id == "character_rowan", "roster order should survive")
                assert(loaded.roster[1].inventory[7], "the item should be back in cell 7")
                assert(loaded.roster[1].inventory[7].id == "consumable_fire_stone", "the right item should be in cell 7")
                assert(loaded.roster[1].inventory[1] == nil, "empty cells should stay empty")
            end)
        end,
    },
    {
        name = "a save round trip preserves stash contents and consumable stack sizes",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                p.stash = {}
                Player.addToStash(p, Item.instantiate("consumable_healing_potion", 5))

                Save.write(p)
                local loaded = Save.read()

                assert(#loaded.stash == 1, "the stash should hold one entry")
                assert(loaded.stash[1].id == "consumable_healing_potion", "the potion should survive")
                assert(loaded.stash[1].quantity == 5, "the stack size should survive")
            end)
        end,
    },
    {
        name = "an unreadable or wrong-version save is discarded rather than half-loaded",
        fn = function()
            withScratchSave(function()
                love.filesystem.write(Save.FILE, "return { this is not lua")
                assert(Save.read() == nil, "a malformed save should read as nil")

                love.filesystem.write(Save.FILE, "return { version = 9999, gold = 1 }")
                assert(Save.read() == nil, "a future-version save should read as nil")
            end)
        end,
    },
    {
        name = "loading drops ids that no longer exist in data/ instead of crashing",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                Save.write(p)

                local snap = Save.snapshot(p)
                snap.stash[#snap.stash + 1] = { id = "item_that_was_deleted", quantity = 1 }
                snap.roster[#snap.roster + 1] = { id = "character_that_was_deleted", inventory = {} }

                local loaded = Save.restore(snap)
                assert(loaded, "the save should still restore")
                for _, item in ipairs(loaded.stash) do
                    assert(item.id ~= "item_that_was_deleted", "the unknown item should be dropped")
                end
                assert(#loaded.roster == #p.roster, "the unknown character should be dropped")
            end)
        end,
    },

    -- --------------------------------------------------- character progression (levels/growth)
    {
        name = "resolveLevels catches every roster member up to what it banked, and reports who advanced",
        fn = function()
            -- Was "syncLevels catches every roster member up to prestige". Prestige no longer levels
            -- anybody -- a body earns its own level by acting and by felling (models/experience.lua) --
            -- so what this case now guards is the CATCH-UP: banked experience that has not been
            -- resolved yet must be resolved on demand, which is what makes it safe to call on load and
            -- after every fight.
            local Experience = require("models.experience")
            local p = Player.new() -- roster at level 1
            local expected = 7
            for _, char in ipairs(p.roster) do Experience.award(char, Experience.totalFor(expected)) end

            -- A recruit added mid-campaign by hand (rather than through Player.recruit, which seeds the
            -- company median) starts at level 1 and must be caught up too.
            local recruit = Character.instantiate("character_mage")
            Experience.award(recruit, Experience.totalFor(expected))
            p.roster[#p.roster + 1] = recruit
            assert(recruit.level == 1, "a fresh instance starts at level 1 whatever it is holding")

            local summary = Player.resolveLevels(p)
            assert(#summary == #p.roster, "every roster member advanced from level 1")
            for _, char in ipairs(p.roster) do
                assert(char.level == expected, char.name .. " should be caught up to level " .. expected)
            end

            -- Summary entries carry the shape the advancement overlay renders.
            local entry = summary[1]
            assert(entry.char and entry.fromLevel == 1 and entry.toLevel == expected, "summary spans the climb")
            assert(entry.class and next(entry.gains), "summary names the growth class and its gains")

            -- Already caught up: a second resolve reports nothing.
            assert(#Player.resolveLevels(p) == 0, "a re-resolve on the same bank advances no one")
        end,
    },
    {
        name = "a companion joins on the company's median rather than at level 1",
        fn = function()
            -- Under prestige every recruit arrived at the company's level for free. Under experience a
            -- fresh instance is level 1, which is a body nobody would ever field -- so Player.recruit
            -- seeds the newcomer with the median of the company they are joining.
            local Experience = require("models.experience")
            local p = Player.new()
            for _, char in ipairs(p.roster) do Experience.award(char, Experience.totalFor(9)) end
            Player.resolveLevels(p)

            local joined = Player.recruit(p, "character_mage")
            assert(joined, "the recruit should be added")
            assert(joined.level > 1, "a recruit nobody can field is not a reward, got level " .. joined.level)
            assert(joined.level <= 9, "and it is not a free ride past the company either")
        end,
    },
    {
        name = "Quest.complete reports where the company stands, and hands out no levels",
        fn = function()
            -- WAS "folds the roster's advancement into its reward table", and the absence is now the
            -- contract. Completing a quest used to grant prestige, prestige levelled the whole roster
            -- at once, and this table carried the list. A body earns its own level in the fighting now
            -- (models/experience.lua), resolved at the end of every battle -- so by the time the
            -- objective pays out, the levelling has happened and been announced where it was earned.
            --
            -- What the panel reads instead is the standing, which is what is asserted here: it is the
            -- last of three things to have replaced the prestige bar and the only one still standing.
            local p = playerAt(1)
            local quest = Quest.get("quest_colosseum_slot_01")
            assert(quest, "arena_debut should be available on the first day")
            local fought = #p.roster

            local reward = Quest.complete(p, quest)
            assert(reward.advancement == nil,
                "a quest hands out no levels -- they were earned in the fight and reported there")
            assert(reward.prestige == nil, "and prestige is gone entirely, not merely unused")
            assert(reward.days == nil,
                "nor a campaign length: there is no deadline to be a fraction of")
            assert(reward.standing == reward.standingBefore + 1,
                "finishing one quest advances standing by exactly one")
            assert(reward.recruited and #p.roster == fought + 1,
                "and the bout's real reward still joined")
        end,
    },
    {
        name = "a save round trip preserves level, the ledger, and re-bakes accumulated growth",
        fn = function()
            withScratchSave(function()
                local p = Player.new()
                local knight = p.roster[1]
                -- One ledger, read as the career title AND as what the next level-up apportions
                -- (models/growth.lua). Nothing is checkpointed yet, so all of it is outstanding.
                knight.technique = { mage = 12 }
                -- DECLARED a mage, which is what growth reads now (Growth.jobOf). The ledger
                -- above is what the class LEVEL is read off and no longer steers the table.
                knight.job = "mage"
                -- Banked experience rather than prestige: a body earns its own level now
                -- (models/experience.lua), so the fixture buys the level it wants outright.
                local Experience = require("models.experience")
                local expected = 5
                Experience.award(knight, Experience.totalFor(expected))
                Player.resolveLevels(p) -- knight climbs 1 -> `expected` as a mage; stats baked

                local grownMagic = knight.stats.magicDamage
                local grownHealthMax = knight.stats.health.max
                assert(knight.level == expected, "the knight reached level " .. expected)
                assert(grownMagic > Character.instantiate("character_rowan").stats.magicDamage,
                    "the mage growth actually raised magic")

                Save.write(p)
                local loaded = Save.read()
                assert(loaded, "the save should read back")

                local loadedKnight = loaded.roster[1]
                assert(loadedKnight.level == expected, "level should survive")
                assert(loadedKnight.technique.mage == 12, "the ledger should survive")
                assert(loadedKnight.stats.magicDamage == grownMagic, "growth should re-bake onto magic")
                assert(loadedKnight.stats.health.max == grownHealthMax, "growth should re-bake onto the HP pool")
                assert(Growth.jobOf(loadedKnight) == "mage", "the loaded knight still grows as a mage")
            end)
        end,
    },
    {
        -- The technique wallet has to ride in the CHARACTER snapshot specifically, not merely somewhere
        -- in the save: "Try Again" restores the party from a pre-fight snapshot (states/game.lua), and
        -- that rollback is the only thing stopping a player from losing on purpose to farm a fight's
        -- technique over and over. Move this field out of the character and that defence disappears
        -- silently, so the round trip is pinned here.
        name = "a save round trip preserves banked discipline technique",
        fn = function()
            withScratchSave(function()
                local Discipline = require("models.discipline")
                local disciplineId = next(Discipline.defs)
                assert(disciplineId, "there is at least one discipline")

                local p = Player.new()
                p.roster[1].technique = { [disciplineId] = 34 }

                Save.write(p)
                local loaded = Save.read()
                assert(loaded, "the save should read back")
                assert(loaded.roster[1].technique[disciplineId] == 34, "the wallet should survive the trip")

                -- A wallet spent back to nothing drops out entirely, and reads as zero rather than nil
                -- on the far side -- the same shape an untouched discipline has.
                p.roster[1].technique = { [disciplineId] = 0 }
                Save.write(p)
                local emptied = Save.read()
                assert((emptied.roster[1].technique or {})[disciplineId] == nil,
                    "a spent-out discipline is omitted, like an unearned one")
                assert(Discipline.technique(emptied, disciplineId) == 0, "and reads back as zero")
            end)
        end,
    },

    {
        -- A quest that levels nobody is the ORDINARY case, and always was -- so the reward table has to
        -- carry something that moved, or half of all quests report nothing at all. That used to be a
        -- prestige step filling a bar, then the day filling the same bar. Neither survives: what is left
        -- is STANDING, which moves by exactly one on every quest that finishes and is what the town
        -- reads anyway.
        name = "Quest.complete always reports something that moved, even when nobody levels",
        fn = function()
            local p = playerAt(1)
            local quest = Quest.get("quest_colosseum_slot_01")
            assert(quest, "the fixture quest should be available")

            local reward = Quest.complete(p, quest)

            assert(reward.standing == reward.standingBefore + 1,
                "standing moved by one, which is what the town reads")
            assert(#(reward.advancement or {}) == 0,
                "nobody levelled here -- levels are earned in the fighting, not at the payout")
            -- The property that matters, stated plainly: there is always a reading that changed.
            assert(reward.standing ~= reward.standingBefore,
                "a completed quest must never report a company that stood entirely still")
        end,
    },

    {
        -- Every save written before per-class level crediting existed has no `growthBy`. Such a save
        -- must not read as a character that never levelled -- and it must not have its stats recomputed
        -- either, since the deltas it stores were earned under the old winner-takes-all rule.
        name = "a save from before the per-class ledger loads with its history seeded, not lost",
        fn = function()
            local live = Character.instantiate("character_rowan")
            live.technique = { mage = 30 }
            Growth.resolve(live, 6)

            -- The same character as an OLD save would have stored it: level, tally and baked deltas,
            -- but no ledger at all.
            local legacy = {
                id = live.id,
                level = live.level,
                classUse = { mage = 30 },
                growth = live.growth,
            }
            assert(legacy.growthBy == nil, "the fixture must actually be a pre-ledger save")

            local loaded = Save.restoreCharacter(legacy)

            assert(loaded.level == live.level, "the level survives")
            assert(loaded.stats.magicDamage == live.stats.magicDamage,
                "and the stats are the ones that save had, re-baked rather than recomputed")
            assert(loaded.stats.health.max == live.stats.health.max, "pools too")

            -- NOTHING IS SEEDED ANY MORE, and that is the point of the change rather than a loss. This
            -- used to reconstruct a `growthBy` ledger from the save's dominant class, because the class
            -- level was read off that ledger and an old save would otherwise have looked like a body
            -- that had never levelled. The class level is read off `technique` now
            -- (Discipline.classLevel), which these saves already carried, so there is nothing to invent.
            assert(loaded.growthBy == nil, "the retired ledger is not rebuilt")
            assert(loaded.job == nil, "an old save arrives undeclared, and grows as its innate class")

        end,
    },
    {
        -- A save written before the growth tally and the technique wallet became one ledger carries
        -- `classUse` (one tick per action) and `technique` (two per action, disciplines only). It is
        -- folded forward on read rather than discarded -- Save.VERSION deliberately does not move,
        -- because a mismatch throws the whole save away for a change that reads forward exactly.
        name = "a pre-merge save folds its two tallies into the one ledger",
        fn = function()
            local Discipline = require("models.discipline")
            local rate = Discipline.TECHNIQUE_PER_ACTION

            local loaded = Save.restoreCharacter({
                id = "character_rowan",
                level = 4,
                classUse = { mage = 30, knight = 10 },     -- the old growth vote, one per action
                classUseSinceLevel = { mage = 6 },         -- six casts outstanding toward the next level
                technique = { mage = 5 },                  -- an old wallet, mostly spent
                growthBy = { mage = 3 },
            })

            -- Earned is reconstructed at the merged rate, so the same play banks what it would today.
            assert(loaded.technique.mage == 30 * rate, "the career reading multiplies up to the new rate")
            assert(loaded.technique.knight == 10 * rate, "for every house, not only the ones with a wallet")
            assert(loaded.classUse == nil and loaded.classUseSinceLevel == nil, "the old tallies are gone")

            -- Banks come back FULL. The gap between the two old numbers also contains the old
            -- per-battle cap's clipping, so deriving spending from it would bill for forges never made.
            assert(Character.techniqueAvailable(loaded, "mage") == 30 * rate, "the bank is refilled once")

            -- The checkpoint is seeded so the outstanding reading survives -- otherwise every loaded
            -- character would arrive holding a free level's worth of growth.
            assert(Character.techniqueSinceLevel(loaded, "mage") == 6 * rate,
                "what was outstanding toward the next level is still outstanding")
            assert(Character.techniqueSinceLevel(loaded, "knight") == 0,
                "and a house with nothing outstanding has nothing outstanding")

            -- A pre-merge save carries no declaration, so it arrives growing as its innate class.
            -- The ledger it DID carry is what the class level is read off, and that survived above.
            assert(loaded.job == nil, "an old save arrives undeclared")
        end,
    },

    -- ---------------------------------------------------------------- protect
    {
        name = "a protect objective loses the battle the moment the charge falls",
        fn = function()
            local objective = { type = "killAll", protect = "character_caravan_master" }
            local c = Combat.new(arena(8, 8, objective),
                { unit("character_rowan", 3, 6), unit("character_caravan_master", 4, 6, "ai") },
                { unit("character_bandit", 4, 1) })

            assert(Combat.evaluate(c) == nil, "the battle is undecided while everyone stands")

            local escortee = c.units[2]
            assert(escortee.char.id == "character_caravan_master", "the escortee should be unit 2")
            escortee.alive = false
            assert(Combat.evaluate(c) == "loss", "losing the charge should lose the battle")
        end,
    },
    {
        name = "protect does not block the win when the charge survives",
        fn = function()
            local objective = { type = "killAll", protect = "character_caravan_master" }
            local c = Combat.new(arena(8, 8, objective),
                { unit("character_rowan", 3, 6), unit("character_caravan_master", 4, 6, "ai") },
                { unit("character_bandit", 4, 1) })

            c.units[3].alive = false -- the last enemy falls
            assert(Combat.evaluate(c) == "win", "killAll should still resolve with the charge alive")
        end,
    },
    {
        name = "an escorted ally fights on the party's side but is not player-controlled",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 3, 6), unit("character_caravan_master", 4, 6, "ai") },
                { unit("character_bandit", 4, 1) })

            local knight, escortee = c.units[1], c.units[2]
            assert(Combat.isPlayerControlled(knight), "the knight takes an interactive turn")
            assert(not Combat.isPlayerControlled(escortee), "the escortee runs itself")
            assert(escortee.side == "party", "the escortee is on the party's side")

            -- The AI plans against the *other* side, so an escort never turns on its escort.
            local plan = Combat.planEnemyAction(c, escortee)
            assert(plan, "the escortee should produce a plan")
            if plan.item and plan.tx then
                local target = Combat.unitAt(c, plan.tx, plan.ty)
                assert(not target or target.side == "enemy", "the escortee must not attack the party")
            end
        end,
    },
    {
        name = "Arena.build spawns escorted allies on party tiles, after the party itself",
        fn = function()
            local built = Arena.build({ prestige = 1 }, {
                biome = "forest",
                party = { "character_rowan", "character_mage" },
                allies = { "character_caravan_master" },
                composition = { "character_bandit" },
                objective = { type = "killAll", protect = "character_caravan_master" },
                seed = 4242,
            })

            assert(#built.party == 2, "both party members should spawn")
            assert(#built.allies == 1, "the escortee should spawn")
            assert(built.allies[1].id == "character_caravan_master", "the escortee should be the caravan master")

            -- Nobody shares a tile.
            local seen = {}
            for _, u in ipairs({ built.party[1], built.party[2], built.allies[1] }) do
                local k = u.x .. "," .. u.y
                assert(not seen[k], "two units spawned on the same tile")
                seen[k] = true
            end
        end,
    },
    {
        name = "a build with no allies has an empty ally list, not a default foe",
        fn = function()
            -- Arena.resolveComposition defaults a nil composition to a lone bandit; allies must
            -- not inherit that fallback or every battle would gain a stray ally.
            local built = Arena.build({ prestige = 1 }, {
                biome = "forest", party = { "character_rowan" }, composition = { "character_bandit" }, seed = 7,
            })
            assert(#built.allies == 0, "no allies were asked for, so none should spawn")
        end,
    },
}
