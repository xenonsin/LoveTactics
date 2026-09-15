-- Tests for models/bounty.lua: the board's postings, the ladder that opens them, and the quest
-- descriptor a posting synthesizes for states/game.lua.
--
-- What these are really guarding is the SEAM. A bounty is a posting of work that lives in another
-- file, so every one of these cases is a way the two can silently disagree -- a posting naming a quest
-- that has been renamed, a ground that is not a biome, a piece that is not an item, or a descriptor
-- that writes its ground back into the blueprint it borrowed. None of those crash; all of them produce
-- a board that quietly lies about what a day out is worth.

local Bounty = require("models.bounty")
local Quest = require("models.quest")
local Item = require("models.item")
local Biome = require("models.biome")
local Vendor = require("models.vendor")
local Player = require("models.player")

local function playerWith(done)
    local p = Player.new()
    p.completedQuests = done or {}
    return p
end

-- The one posting phase 0 ships. Named rather than taken off the front of Bounty.offered so a second
-- bounty landing does not silently re-point every case below at it.
local PHASE0 = "bounty_bastion_relief_column"

return {
    {
        name = "the registry discovers bounty blueprints by filename",
        fn = function()
            assert(Bounty.defs[PHASE0], PHASE0 .. " missing from Bounty.defs")
            assert(Bounty.get(PHASE0), "Bounty.get does not resolve " .. PHASE0)
        end,
    },
    {
        -- Each of these is a dangling reference that would read as a blank or a wrong line on the
        -- board rather than as an error, which is why they are swept rather than eyeballed.
        name = "every bounty names a real quest, sponsor, ground and piece",
        fn = function()
            for id, def in pairs(Bounty.defs) do
                assert(def.name, id .. " has no name")
                -- A posting is EITHER authored work or a synthesized hunt, and it must be exactly one
                -- of the two: one naming neither has no fight at the end of it, and would generate a
                -- board whose objective tile opens nothing.
                assert(def.quest or def.boss,
                    id .. " names neither a quest nor a boss, so it has no fight at the end")
                if def.quest then
                    assert(Quest.get(def.quest),
                        id .. " names a quest that does not exist: " .. tostring(def.quest))
                end
                if def.boss then
                    local Character = require("models.character")
                    assert(Character.defs[def.boss],
                        id .. " names a boss that does not exist: " .. tostring(def.boss))
                    for _, g in ipairs(def.guard or {}) do
                        assert(Character.defs[g], id .. " names an unknown guard: " .. tostring(g))
                    end
                end
                assert(Vendor.get(def.sponsor), id .. " names an unknown sponsor: " .. tostring(def.sponsor))
                -- Biome.get falls back to forest for an unknown id, so ask the defs table directly or
                -- a typo'd ground passes by being silently repaired.
                assert(Biome.defs[def.ground], id .. " names an unknown ground: " .. tostring(def.ground))
                -- A piece is optional (a stock bounty names none), but a named one must be real.
                if def.piece then
                    assert(Item.defs[def.piece], id .. " names an unknown piece: " .. tostring(def.piece))
                end
                local tier = def.tier or 1
                assert(Bounty.TIER_LEVEL[tier], id .. " sits on a tier with no level: " .. tostring(tier))
            end
        end,
    },
    {
        -- The ladder IS the gate (there are no seals), so a prerequisite naming a bounty nobody wrote
        -- would be a rung with nothing under it.
        name = "every `requires` names a bounty that exists",
        fn = function()
            for id, def in pairs(Bounty.defs) do
                for _, req in ipairs(def.requires or {}) do
                    assert(Bounty.defs[req],
                        id .. " requires a bounty that does not exist: " .. tostring(req))
                end
            end
        end,
    },
    {
        name = "questFor builds a descriptor carrying what states/game.lua reads",
        fn = function()
            local quest = Bounty.questFor(PHASE0)
            assert(quest, "questFor returned nil")
            assert(quest.id, "descriptor has no id")
            assert(quest.name, "descriptor has no name")
            assert(quest.sponsor == "bastion", "sponsor did not carry: " .. tostring(quest.sponsor))
            assert(type(quest.map) == "table", "descriptor has no map")
            assert(quest.map.objective, "descriptor's map has no objective")
            assert(type(quest.floorLevel) == "number", "descriptor has no floorLevel")
        end,
    },
    {
        -- The Bastion's slot_01 is ALSO the companion's recruit ask (models/errand.lua). If a bounty
        -- ran under the blueprint's own id, taking it off the board would silently satisfy a
        -- recruitment nobody had walked to -- a bug with no symptom.
        name = "a bounty runs under its own id, never the quest's",
        fn = function()
            local def = Bounty.get(PHASE0)
            local quest = Bounty.questFor(PHASE0)
            assert(quest.id ~= def.quest,
                "the descriptor reuses the blueprint's id, which would complete the errand")
            assert(Bounty.isBountyId(quest.id), "the descriptor's id is not a bounty id")
            assert(quest.id == Bounty.runId(PHASE0), "runId and questFor disagree about the id")
        end,
    },
    {
        -- data/quests/*.lua are immutable blueprints (CLAUDE.md). A posting that stamped its ground
        -- into the shared def would re-point every other posting of the same work.
        name = "questFor never mutates the quest blueprint it borrows",
        fn = function()
            local def = Bounty.get(PHASE0)
            local src = Quest.get(def.quest)
            local before = src.map.biome
            local quest = Bounty.questFor(PHASE0)
            assert(quest.map.biome == def.ground,
                "the descriptor did not take the bounty's ground")
            assert(src.map.biome == before,
                "questFor wrote its ground back into the blueprint")
            assert(quest.map ~= src.map, "the descriptor shares the blueprint's map table")
        end,
    },
    {
        -- The piece is a headline, not a narrowing. Dropping the other two rewards would strand them on
        -- a shelf that promises them and never sells them (tests/obtainable_spec.lua).
        name = "the blueprint's own rewards are kept whole",
        fn = function()
            local def = Bounty.get(PHASE0)
            local src = Quest.get(def.quest)
            local quest = Bounty.questFor(PHASE0)
            assert(quest.rewardItems == src.rewardItems,
                "the descriptor narrowed or dropped the quest's reward items")
            local found = false
            for _, id in ipairs(src.rewardItems or {}) do
                if id == def.piece then found = true end
            end
            assert(found, "the named piece is not among what the work actually pays")
        end,
    },
    {
        name = "the tier sets the difficulty floor",
        fn = function()
            local quest = Bounty.questFor(PHASE0)
            assert(quest.floorLevel == Bounty.TIER_LEVEL[1],
                "a tier 1 posting did not land on the first rung")
            -- The rungs must climb, or a higher tier would be the easier fight.
            for i = 2, #Bounty.TIER_LEVEL do
                assert(Bounty.TIER_LEVEL[i] > Bounty.TIER_LEVEL[i - 1],
                    "TIER_LEVEL does not ascend at rung " .. i)
            end
        end,
    },
    {
        -- THE SEASON MUST NEVER STARVE THE BOARD. data/biome_windows.lua guarantees three GROUNDS open
        -- every day, but houses share grounds -- three of the seven openers are in the swamp -- so the
        -- count that actually matters is how many HOUSES are posting, and nothing was checking it.
        --
        -- Below three the board stops being a choice of where and becomes a corridor, which is the same
        -- floor the ground schedule uses and for the same reason.
        name = "every day of the season posts at least three houses",
        fn = function()
            local BiomeWindow = require("models.biome_window")
            local MIN_HOUSES = 3
            for day = 1, BiomeWindow.SEASON do
                local p = playerWith()
                p.day = day
                local houses = {}
                for _, entry in ipairs(Bounty.offered(p)) do
                    if entry.standing then houses[entry.def.sponsor] = true end
                end
                local n = 0
                local names = {}
                for h in pairs(houses) do n = n + 1 names[#names + 1] = h end
                table.sort(names)
                assert(n >= MIN_HOUSES, string.format(
                    "day %d posts only %d house(s) (%s) -- the board needs %d",
                    day, n, table.concat(names, ", "), MIN_HOUSES))
            end
        end,
    },
    {
        name = "a standing offer is on the board from the first morning and survives finishing it",
        fn = function()
            -- Day 1 opens castle, forest and tundra, so the Bastion is posting. Pinned to a day rather
            -- than left to the default, because this case is about the STOCK and would otherwise start
            -- failing the moment somebody retuned the season table.
            local fresh = playerWith()
            fresh.day = 1
            local seen = false
            for _, entry in ipairs(Bounty.offered(fresh)) do
                assert(entry.def, "an offered entry carries no def")
                if entry.id == PHASE0 then
                    seen = true
                    assert(entry.standing, "the house opener is not marked standing")
                end
            end
            assert(seen, PHASE0 .. " is not offered to a fresh company")

            -- A FINISHED POSTING DOES NOT LEAVE THE BOARD -- it leaves when the last copy is spent, and
            -- a standing offer has no last copy. This is what stops a bad run from being a lock-out.
            local done = playerWith({ [Bounty.runId(PHASE0)] = true })
            done.day = 1
            local still = false
            for _, entry in ipairs(Bounty.offered(done)) do
                if entry.id == PHASE0 then still = true end
            end
            assert(still, "the house's standing offer vanished once it had been finished")
        end,
    },
    {
        -- The bet. A posting spent on the way out is gone whatever happens next, which is the whole of
        -- why pressing on costs something (docs/economy.md: a bet you get back is not a bet).
        name = "spending takes a held posting out of hand, and refuses when there is none",
        fn = function()
            local pl = playerWith()
            local held = { name = "Held", sponsor = "bastion", ground = "tundra", tier = 2,
                boss = "character_siege_breaker" }
            Bounty.defs.bounty_spec_held = held

            assert(Bounty.count(pl, "bounty_spec_held") == 0, "a fresh company holds postings it never found")
            assert(not Bounty.spend(pl, "bounty_spec_held"), "spent a posting that was not in hand")

            Bounty.grant(pl, "bounty_spec_held", 2)
            assert(Bounty.count(pl, "bounty_spec_held") == 2, "granting did not stack")
            assert(Bounty.spend(pl, "bounty_spec_held"), "could not spend a held posting")
            assert(Bounty.count(pl, "bounty_spec_held") == 1, "spending took more than one")
            assert(Bounty.spend(pl, "bounty_spec_held"))
            assert(Bounty.count(pl, "bounty_spec_held") == 0, "the last copy did not leave")
            assert(pl.bounties.bounty_spec_held == nil, "an empty row was left for the board to draw")
            assert(not Bounty.spend(pl, "bounty_spec_held"), "spent a posting past the last copy")

            Bounty.defs.bounty_spec_held = nil
        end,
    },
    {
        name = "a standing offer is never consumed",
        fn = function()
            local pl = playerWith()
            for _ = 1, 3 do
                assert(Bounty.spend(pl, PHASE0), "a standing offer refused to be taken")
            end
            assert(Bounty.count(pl, PHASE0) == 0, "taking a standing offer put it in hand")
        end,
    },
    {
        -- Same house, this tier or the next, never a standing offer. Each of those is a way the climb
        -- breaks: another house's work makes a house not a ladder, the apex from the opener deletes the
        -- climb, and dealing an infinite posting hands over nothing at all.
        name = "drops come from the same house, at this tier or one above, and are never standing",
        fn = function()
            local pl = playerWith()
            Bounty.defs.bounty_spec_t2 = { name = "T2", sponsor = "bastion", ground = "tundra", tier = 2 }
            Bounty.defs.bounty_spec_t3 = { name = "T3", sponsor = "bastion", ground = "tundra", tier = 3 }
            Bounty.defs.bounty_spec_t4 = { name = "T4", sponsor = "bastion", ground = "tundra", tier = 4 }
            Bounty.defs.bounty_spec_other = { name = "Other", sponsor = "arcanum", ground = "castle", tier = 2 }

            local pool = {}
            for _, id in ipairs(Bounty.dropPool(pl, Bounty.defs.bounty_spec_t2)) do pool[id] = true end
            assert(pool.bounty_spec_t2, "a house's own tier did not drop")
            assert(pool.bounty_spec_t3, "the next rung up did not drop")
            assert(not pool.bounty_spec_t4, "two rungs up dropped, which deletes the climb")
            assert(not pool.bounty_spec_other, "another house's work dropped")
            assert(not pool[PHASE0], "a standing offer was dealt, which hands over nothing")

            -- Pinned roll, so this asserts the count rather than a coin flip.
            local granted = Bounty.dealDrops(pl, Bounty.defs.bounty_spec_t2, function() return 0 end)
            assert(#granted == Bounty.DROPS_MIN, "the floor of the drop rate is not what it says")
            for _, id in ipairs(granted) do
                assert(Bounty.count(pl, id) > 0, "a dealt posting did not reach the company's hand")
            end

            for _, id in ipairs({ "bounty_spec_t2", "bounty_spec_t3", "bounty_spec_t4", "bounty_spec_other" }) do
                Bounty.defs[id] = nil
            end
        end,
    },
    {
        -- The pile has to be able to GROW, or pressing on is a slow drain whatever the player does.
        name = "the drop rate can pay more than the one it cost",
        fn = function()
            assert(Bounty.DROPS_MAX > 1,
                "a finished posting can never pay back more than it cost, so the stock only falls")
            assert(Bounty.DROPS_MIN >= 1,
                "a finished posting can pay nothing, so a run of bad luck empties the board")
        end,
    },
    {
        name = "the ladder holds a posting shut until its requirement is done",
        fn = function()
            -- Built rather than authored: phase 0 ships one bounty, so the rung above it does not
            -- exist yet and the rule has to be tested on a stand-in.
            local gated = { name = "Stand-in", quest = "quest_bastion_slot_01",
                sponsor = "bastion", ground = "tundra", tier = 2, requires = { PHASE0 } }
            local fresh = playerWith()
            assert(not Bounty.isOpen(fresh, gated), "a gated posting was open with nothing finished")

            local done = playerWith({ [Bounty.runId(PHASE0)] = true })
            assert(Bounty.isOpen(done, gated), "a gated posting stayed shut after its requirement")
        end,
    },
    {
        -- Fail-open, the same rule Descent.gateFor takes: a prerequisite naming a bounty nobody wrote
        -- must leave the board reachable rather than seal a house behind a typo.
        name = "an unknown requirement fails open",
        fn = function()
            local typo = { requires = { "bounty_that_was_never_written" } }
            assert(Bounty.isOpen(playerWith(), typo),
                "an unknown requirement sealed the posting instead of failing open")
        end,
    },
    {
        name = "offered is ordered by tier then id, so the board can be learned",
        fn = function()
            local list = Bounty.offered(playerWith())
            for i = 2, #list do
                local a, b = list[i - 1], list[i]
                local ta, tb = a.def.tier or 1, b.def.tier or 1
                assert(ta < tb or (ta == tb and a.id < b.id),
                    "offered came back out of order at " .. i)
            end
        end,
    },
    {
        -- THE LOOP ONLY CLOSES IF THE PROMISE IS KEPT OUT LOUD. The board names one piece before the
        -- day is spent; if the way home lists it as one of three undifferentiated rows -- or truncates
        -- it off a four-row cap entirely -- the player is never told they got the thing they went for.
        name = "the promised piece leads the payout and is named back",
        fn = function()
            local pl = playerWith()
            local quest = Bounty.questFor(PHASE0, pl)
            local reward = Quest.complete(pl, quest)
            assert(reward, "the bounty paid nothing at all")
            assert(reward.piece == Bounty.pieceOf(Bounty.get(PHASE0)),
                "the payout did not name the piece the board promised")
            assert(reward.received[1] and reward.received[1].id == reward.piece,
                "the promised piece is not first, so a long haul can truncate it away")
        end,
    },
    {
        -- Work that was never posted as a bounty pays exactly as it always did.
        name = "a quest with no bounty behind it names no piece",
        fn = function()
            local pl = playerWith()
            local reward = Quest.complete(pl, Quest.get("quest_colosseum_slot_01"))
            assert(reward and reward.piece == nil,
                "an unposted quest invented a promised piece")
        end,
    },
    {
        -- The ceiling models/bounty.lua declares, asserted rather than trusted: a derivation whose
        -- output nobody counts is one that can quietly double or halve.
        name = "every house has a standing opener and exactly two derived rungs above it",
        fn = function()
            local Descent = require("models.descent")
            local byHouse = {}
            for id, def in pairs(Bounty.defs) do
                local h = def.sponsor
                assert(h, id .. " belongs to no house")
                byHouse[h] = byHouse[h] or { standing = 0, derived = 0 }
                if Bounty.isStanding(def) then byHouse[h].standing = byHouse[h].standing + 1 end
                if def.derived then byHouse[h].derived = byHouse[h].derived + 1 end
            end

            for _, sin in ipairs(Descent.SINS) do
                local counts = byHouse[sin.vendor]
                assert(counts, sin.vendor .. " posts nothing at all")
                assert(counts.standing == 1,
                    sin.vendor .. " has " .. counts.standing .. " standing offers; it must have exactly one")
                assert(counts.derived == Bounty.DERIVED_PER_HOUSE,
                    sin.vendor .. " derived " .. counts.derived .. " rungs, not " .. Bounty.DERIVED_PER_HOUSE)
            end
        end,
    },
    {
        name = "a derived ladder climbs opener -> lieutenant -> apex, each gating the next",
        fn = function()
            local Descent = require("models.descent")
            for _, sin in ipairs(Descent.SINS) do
                local lieutenant, apex
                for id, def in pairs(Bounty.defs) do
                    if def.derived and def.sponsor == sin.vendor then
                        if def.tier == Bounty.TIER_LIEUTENANT then lieutenant = id
                        elseif def.tier == Bounty.TIER_APEX then apex = id end
                    end
                end
                assert(lieutenant, sin.vendor .. " derived no lieutenant rung")
                assert(apex, sin.vendor .. " derived no apex rung")

                -- Nothing above the opener is reachable on a fresh save, which is the ladder being a gate.
                local fresh = playerWith()
                assert(not Bounty.isOpen(fresh, Bounty.defs[lieutenant]),
                    sin.vendor .. "'s lieutenant is open before its opener is done")
                assert(not Bounty.isOpen(fresh, Bounty.defs[apex]),
                    sin.vendor .. "'s apex is open before its lieutenant is down")

                -- ...and each rung opens exactly the one above it, never two at once.
                local opened = playerWith()
                for _, req in ipairs(Bounty.defs[lieutenant].requires or {}) do
                    opened.completedQuests[Bounty.runId(req)] = true
                end
                assert(Bounty.isOpen(opened, Bounty.defs[lieutenant]),
                    sin.vendor .. "'s lieutenant stayed shut after its opener")
                assert(not Bounty.isOpen(opened, Bounty.defs[apex]),
                    sin.vendor .. "'s apex opened off the opener, which skips the climb")
            end
        end,
    },
    {
        -- The gap in the rungs (1 / 3 / 5) is what broke the old raw tier+1 window, and this is the
        -- case that would have caught it: the opener could not pay anything at all.
        name = "finishing the opener pays the rung above it, and only that one",
        fn = function()
            local Descent = require("models.descent")
            local sin = Descent.SINS[1]
            local opener
            for id, def in pairs(Bounty.defs) do
                if Bounty.isStanding(def) and def.sponsor == sin.vendor then opener = id end
            end
            assert(opener, sin.vendor .. " has no opener to finish")

            -- Built at the moment the ledger moves, because that is when Quest.complete deals them --
            -- the pool only offers rungs the ladder has OPENED, and finishing this posting is what
            -- opens the one above it. Dealt a line earlier and the opener pays nothing at all.
            local pl = playerWith({ [Bounty.runId(opener)] = true })
            local pool = Bounty.dropPool(pl, Bounty.defs[opener])
            assert(#pool > 0, "finishing a house's opener pays no posting at all")
            for _, id in ipairs(pool) do
                assert(Bounty.defs[id].tier == Bounty.TIER_LIEUTENANT,
                    "the opener dealt a tier " .. tostring(Bounty.defs[id].tier) .. " posting, skipping the climb")
            end
        end,
    },
    {
        -- Carried, never advertised. Without it the Colosseum's opener -- which is how Saber joins --
        -- would pay its fight and silently drop her.
        name = "a posting carries the body its work earns",
        fn = function()
            local quest = Bounty.questFor("bounty_colosseum_opening_nobody_reads")
            local src = Quest.get("quest_colosseum_slot_01")
            assert(quest, "the Colosseum's opener built no expedition")
            assert(quest.rewardCharacter == src.rewardCharacter,
                "the posting dropped the companion its work earns")
        end,
    },
    {
        -- The half of the loop that makes a posting worth taking twice. Without it a repeat run pays a
        -- second copy of a sword you already own, which is worth nothing -- and a posting worth taking
        -- exactly once is one the board may as well delete the moment you take it.
        name = "a repeat kill pays the house's trophy, and a first kill pays none",
        fn = function()
            local Material = require("models.material")
            local apex, lieutenant
            for id, def in pairs(Bounty.defs) do
                if def.derived and def.sponsor == "bastion" then
                    if def.tier == Bounty.TIER_APEX then apex = id
                    elseif def.tier == Bounty.TIER_LIEUTENANT then lieutenant = id end
                end
            end
            assert(apex and lieutenant, "the Bastion derived no apex rungs")

            assert(Bounty.trophyFor(Bounty.defs[apex], false) == nil,
                "a first kill paid a trophy, which should be the piece's job")

            local repeatPay = Bounty.trophyFor(Bounty.defs[apex], true)
            assert(repeatPay and next(repeatPay), "a repeat kill on an apex paid nothing at all")
            for matId, n in pairs(repeatPay) do
                assert(Material.isTrophy(matId), matId .. " is not an apex trophy")
                assert(n > 0, "the trophy paid a non-positive count")
            end

            -- A general is twice the walk, so she pays twice.
            local minorPay = Bounty.trophyFor(Bounty.defs[lieutenant], true)
            local function only(t) for _, n in pairs(t or {}) do return n end end
            assert(only(repeatPay) > only(minorPay),
                "a general pays no more of her house's trophy than her lieutenant does")

            -- An opener is work, not a body worth coming back for.
            local opener
            for id, def in pairs(Bounty.defs) do
                if Bounty.isStanding(def) and def.sponsor == "bastion" then opener = id end
            end
            assert(Bounty.trophyFor(Bounty.defs[opener], true) == nil,
                "a house's opener pays a trophy, which makes the apex rungs pointless")
        end,
    },
    {
        -- Each house has exactly one, and it must not collide with that house's ordinary stock -- a
        -- second material claiming a `class` would alias it in models/material.lua's house index.
        name = "every house has exactly one apex trophy, and no trophy claims a class",
        fn = function()
            local Material = require("models.material")
            local Descent = require("models.descent")
            for _, sin in ipairs(Descent.SINS) do
                local id = Material.trophyFor(sin.vendor)
                assert(id, sin.vendor .. " has no apex trophy, so its deep rungs cannot be forged")
                local def = Material.defs[id]
                assert(def.class == nil,
                    id .. " claims a class, which would alias that house's ordinary stock")
                assert(not Material.isHouse(id), id .. " reads as house stock")
                assert(Material.isTrophy(id), id .. " does not read as a trophy")
            end
        end,
    },
    {
        -- A trophy with nothing to spend it on is a trophy, and this game has enough of those.
        name = "the Forge demands a trophy at the deep rungs and never below them",
        fn = function()
            local Forge = require("models.forge")
            local Material = require("models.material")
            local Item = require("models.item")
            local pl = playerWith()

            -- A knight item: the Bastion's own gear, so the Bastion's trophy is what its top rungs want.
            local sword = Item.instantiate("weapon_iron_sword")
            sword.level = 0
            local shallow = Forge.costTo(pl, sword, Forge.TROPHY_RUNG - 1)
            for matId in pairs(shallow.materials or {}) do
                assert(not Material.isTrophy(matId),
                    "a shallow rung demanded " .. matId .. ", which walls off the middle of the bench")
            end

            local deep = Forge.costTo(pl, sword, Forge.TROPHY_RUNG)
            local wanted = false
            for matId in pairs(deep.materials or {}) do
                if Material.isTrophy(matId) then wanted = true end
            end
            assert(wanted, "the deep rungs demand no trophy, so nothing in the game spends one")
        end,
    },
    {
        name = "the boss name is readable before the map is built",
        fn = function()
            local name = Bounty.bossName(Bounty.get(PHASE0))
            assert(name and #name > 0, "the phase 0 posting cannot name its boss")
        end,
    },
}
