-- Tests for the discipline contract (docs/classes.md "Disciplines"; slate in docs/disciplines-plan.md).
-- A discipline is a shop taxonomy: arity is the whole distinction (1 parent = subclass, 2 = multiclass),
-- and the gate is earned advancement. This pins the structural rules so a malformed blueprint, a reused
-- gate quest, or a mistagged item fails the build rather than vanishing silently.
--
-- Deliberately NOT asserted yet: that every `exemplar` character exists. ~27 of them are pending
-- content (see the "pending" markers in data/disciplines/*.lua) and asserting them now would fail the
-- build on work that is scheduled, not wrong -- a missing exemplar costs a quest its intended body,
-- which is a stand-in, not a dead gate.
--
-- Capstone quests USED to be exempt for the same reason and are not any more: all 21 are on disk, and
-- unlike an exemplar a missing gate quest is fatal rather than cosmetic (see the capstone case below).
-- What is pinned: structure, both tiers of gate quest, the no-reuse rule, the satisfiable-gate rule,
-- and the item tagging invariant.
--
-- Pure logic, headless.

local Discipline = require("models.discipline")
local Item = require("models.item")
local Vendor = require("models.vendor")
local Quest = require("models.quest")

local tests = {}

-- The sponsoring vendor's class for a quest id, or nil.
local function questClass(questId)
    local q = Quest.defs[questId]
    local sponsor = q and q.sponsor
    local v = sponsor and Vendor.defs[sponsor]
    return v and v.class
end

tests[#tests + 1] = { name = "every discipline is well-formed (name, 1-2 real parents, exemplar, gate)", fn = function()
    for id, def in pairs(Discipline.defs) do
        assert(type(def.name) == "string" and def.name ~= "", id .. ": missing name")
        local n = #(def.classes or {})
        assert(n == 1 or n == 2, id .. ": must have 1 or 2 parent classes, has " .. n)
        for _, c in ipairs(def.classes) do
            assert(Item.CLASSES[c], id .. ": unknown parent class " .. tostring(c))
        end
        assert(type(def.exemplar) == "string" and def.exemplar ~= "", id .. ": missing exemplar")
        assert(type(def.requiredQuests) == "table" and #def.requiredQuests >= 1, id .. ": needs requiredQuests")
    end
end }

-- A locked path COLLAPSES to its header on the shelf (ui/panels/shop.lua), so the section detail is the
-- only room a player has to read what the path is before earning it. Without a blurb that pane names a
-- gate and a stock count and never says why anyone would want either. Bounded at both ends for the same
-- reason the class blurbs are (tests/class_spec.lua): a stub answers nothing, and a paragraph overruns
-- the detail column.
tests[#tests + 1] = { name = "every discipline says what it is, in a blurb the shop can print", fn = function()
    for id, def in pairs(Discipline.defs) do
        local blurb = Discipline.description(id)
        assert(type(blurb) == "string" and #blurb >= 40, id .. ": missing description")
        assert(#blurb <= 260, id .. ": description is " .. #blurb
            .. " chars; the shop's detail column fits about 260")
        assert(blurb == def.description, id .. ": Discipline.description must read the blueprint field")
    end
end }

tests[#tests + 1] = { name = "a subclass gate is one existing quest in its parent vendor's line", fn = function()
    for id, def in pairs(Discipline.defs) do
        if #def.classes == 1 then
            local parent = def.classes[1]
            for _, q in ipairs(def.requiredQuests) do
                assert(Quest.defs[q], id .. ": subclass gate quest '" .. q .. "' does not exist")
                assert(questClass(q) == parent,
                    id .. ": gate quest '" .. q .. "' is sponsored by a " .. tostring(questClass(q))
                    .. " vendor, not " .. parent)
            end
        end
    end
end }

-- The capstones. A gate quest that does not exist is not a soft "pending" state -- `Player.hasCompleted`
-- returns false for an id nothing defines, forever, so `Discipline.isUnlocked` can never return true and
-- the discipline's whole shelf is dead stock. All 21 multiclass capstones are on disk now; this is what
-- keeps them there.
--
-- Sponsor is deliberately NOT asserted to match a parent the way the subclass rule above does: a
-- capstone stages a fusion, and either parent's vendor is a legitimate host for it (the Ninja's is the
-- Undercroft, the Battlemage's the Arcanum). Existence is the contract; whose board it sits on is a
-- staging call.
tests[#tests + 1] = { name = "a multiclass capstone gate names a quest that exists", fn = function()
    for id, def in pairs(Discipline.defs) do
        if #def.classes == 2 then
            for _, q in ipairs(def.requiredQuests) do
                assert(Quest.defs[q], id .. ": capstone gate quest '" .. q .. "' does not exist -- the "
                    .. "discipline can never unlock and its shelf is unreachable")
            end
        end
    end
end }

-- WHERE a subclass gate sits, not just which line it sits in. A discipline handed over on a line's
-- first or second quest is not earned advancement -- it is a welcome gift, collected before the player
-- has done anything with the base shelf, and it makes the whole lattice in docs/disciplines-plan.md
-- decorative. Slot 3 is the floor: by then the line has introduced itself, handed over its companion,
-- and asked for something.
--
-- SLOT IS READ OFF THE ID. It used to be derived by walking the line's chain backwards from its
-- general, which was exact while a house ran ten quests linked by requiredQuests. The retired board took
-- both ends of that walk -- the generals are met on their circles now, and models/errand.lua drops the
-- chain field at the door -- so the position is parsed from the id, which is what the chain spelled out.
local SUBCLASS_GATE_FLOOR = 3

local function slotOf(questId)
    return tonumber(tostring(questId or ""):match("_slot_(%d+)$") or "")
end

tests[#tests + 1] = { name = "a subclass gate sits at slot 3 or later in its line", fn = function()
    for id, def in pairs(Discipline.defs) do
        if #def.classes == 1 then
            for _, q in ipairs(def.requiredQuests) do
                local slot = slotOf(q)
                assert(slot, id .. ": gate quest '" .. q .. "' is not on its line's chain")
                assert(slot >= SUBCLASS_GATE_FLOOR, id .. ": gates on '" .. q .. "', slot " .. slot
                    .. " -- a subclass opens no earlier than slot " .. SUBCLASS_GATE_FLOOR)
            end
        end
    end
end }

-- A capstone must be GATED ON ITS PARENTS, not on a prestige number. `Discipline.isUnlocked` has
-- always walked the parents itself, but that only decides whether the shelf opens -- it does not stop
-- the quest appearing on the board, being cleared, and sitting completed while the discipline stays
-- shut for reasons the player was never shown. The quest has to carry the same rule.
--
-- Naming one specific quest per parent is exact rather than over-strict BECAUSE the lines are chains:
-- a later subclass gate cannot be reached without clearing the earlier one, so "any subclass of X"
-- and "X's first subclass gate" are the same set. See data/quests/colosseum/quest_colosseum_champions_challenge.lua.
tests[#tests + 1] = { name = "a multiclass capstone gates on a subclass quest of each parent", fn = function()
    -- Which quests gate a subclass, by parent class.
    local subclassGates = {}
    for id, def in pairs(Discipline.defs) do
        if #def.classes == 1 then
            for _, q in ipairs(def.requiredQuests) do
                subclassGates[def.classes[1]] = subclassGates[def.classes[1]] or {}
                subclassGates[def.classes[1]][q] = true
            end
        end
    end

    for id, def in pairs(Discipline.defs) do
        if #def.classes == 2 then
            local capstoneId = def.requiredQuests[1]
            local capstone = Quest.defs[capstoneId]
            assert(capstone, id .. ": capstone '" .. tostring(capstoneId) .. "' does not exist")

            local req = capstone.requiredQuests or {}
            for _, parent in ipairs(def.classes) do
                local covered = false
                for _, q in ipairs(req) do
                    if (subclassGates[parent] or {})[q] then covered = true end
                end
                assert(covered, id .. ": capstone '" .. capstoneId .. "' names no " .. parent
                    .. " subclass quest in requiredQuests -- it would open on prestige alone")
            end
        end
    end
end }

tests[#tests + 1] = { name = "a multiclass gate is satisfiable: each parent has at least one subclass", fn = function()
    for id, def in pairs(Discipline.defs) do
        if #def.classes == 2 then
            for _, parent in ipairs(def.classes) do
                assert(#Discipline.subclassesOf(parent) >= 1,
                    id .. ": parent '" .. parent .. "' has no subclass, so its gate can never be met")
            end
        end
    end
end }

-- Every discipline must actually STOCK something. Unlocking a discipline does exactly one thing --
-- un-greys its items on the parent shelves (models/vendor.lua) -- so a discipline with no tagged
-- buyable item is a gate the player clears for an empty shelf. This was the live hole after the
-- capstones landed: all 21 multiclasses were tagged (2 items each) but all 16 subclasses had ZERO,
-- so the earned-advancement lattice paid out nothing on its first sixteen rungs.
--
-- "Buyable" is the operative word: a quest-only item (no price) carries a discipline tag for growth
-- and identity but never reaches the shop, so it cannot be the thing a shelf unlock delivers. The
-- stock a player is promised is the priced, gated cut.
-- THE FLOOR. Raised from "at least one buyable item", which was only ever a check against a DEAD
-- shelf -- it could not see the real failure, which is a shelf that unlocks and hands you one cast and
-- two charms. Three is too few to read as a build, and for a long while every multiclass had TWO.
--
-- Five, matching the subclasses, which have run 5-8 since their own retag pass. Two shelves stand at six
-- (Ninja and Spellbreaker) and that is inside the range on purpose -- see docs/disciplines-plan.md.
tests[#tests + 1] = { name = "every discipline stocks at least five buyable items", fn = function()
    local FLOOR = 5
    local count = {}
    for _, def in pairs(Item.defs) do
        if def.discipline and def.price then
            count[def.discipline] = (count[def.discipline] or 0) + 1
        end
    end

    local short = {}
    for did in pairs(Discipline.defs) do
        local n = count[did] or 0
        if n < FLOOR then short[#short + 1] = string.format("%s (%d)", did, n) end
    end
    table.sort(short)
    assert(#short == 0, "discipline(s) below the five-item floor -- a shelf that unlocks and hands you "
        .. "one cast and two charms is not a build: " .. table.concat(short, ", "))
end }

-- ...and the floor nobody was looking for. A multiclass item is stocked on BOTH parents' shelves
-- (Vendor.carries routes it by the discipline's `classes`), so a discipline whose every item sits on one
-- parent still "has stock" by the count above -- while the OTHER vendor announces the unlock and then
-- sells nothing for it. Six multiclasses were in that state; Artificer and Plague Knight each had a
-- completely empty parent.
--
-- Checked on `class`, which is where an item's home shelf is declared -- the growth tally and the
-- vendor's own rack are the same field (docs/classes.md).
tests[#tests + 1] = { name = "a multiclass stocks at least one item on EACH parent's shelf", fn = function()
    local byParent = {}
    for _, def in pairs(Item.defs) do
        if def.discipline and def.price and def.class then
            byParent[def.discipline] = byParent[def.discipline] or {}
            byParent[def.discipline][def.class] = true
        end
    end

    local bare = {}
    for did, def in pairs(Discipline.defs) do
        if #def.classes == 2 then
            local homes = byParent[did] or {}
            for _, parent in ipairs(def.classes) do
                if not homes[parent] then
                    bare[#bare + 1] = did .. " sells nothing at " .. parent
                end
            end
        end
    end
    table.sort(bare)
    assert(#bare == 0, "multiclass shelf/shelves with an empty parent -- that vendor announces the "
        .. "discipline and then stocks nothing for it: " .. table.concat(bare, ", "))
end }

tests[#tests + 1] = { name = "no rung opens more than two disciplines", fn = function()
    -- IT USED TO BE ONE, and that was right while a house had twelve rungs to hang seven subclasses
    -- from. A house asks for six jobs now (models/errand.lua) and the Cathedral has six subclasses, the
    -- Lodge seven -- so a rung apiece is arithmetic the ladder cannot do, and the choice is between two
    -- on a rung or a subclass nobody can reach. Two is the cap: a rung that opened three would be a job
    -- carrying more than the player can read as one reward.
    --
    -- What a shared rung must still be is a SUBJECT rather than a leftover pile -- the Lodge's spirit
    -- wood opens the shaman and the totemist, which are the two spirit paths.
    local counts, who = {}, {}
    for id, def in pairs(Discipline.defs) do
        for _, q in ipairs(def.requiredQuests) do
            counts[q] = (counts[q] or 0) + 1
            who[q] = who[q] and (who[q] .. ", " .. id) or id
            assert(counts[q] <= 2, "quest '" .. q .. "' gates " .. counts[q] .. ": " .. who[q])
        end
    end
end }

tests[#tests + 1] = { name = "every discipline-tagged item's class is one of its discipline's parents", fn = function()
    for id, item in pairs(Item.defs) do
        if item.discipline then
            local def = Discipline.defs[item.discipline]
            assert(def, id .. ": unknown discipline '" .. tostring(item.discipline) .. "'")
            local ok = false
            for _, parent in ipairs(def.classes) do
                if item.class == parent then ok = true; break end
            end
            assert(ok, id .. ": class '" .. tostring(item.class) .. "' is not a parent of discipline '"
                .. item.discipline .. "'")
        end
    end
end }

tests[#tests + 1] = { name = "every discipline-tagged item resolves to a display name", fn = function()
    -- The panels that name an item's discipline (the tooltip row, the shop shelf, the forge) all go
    -- through Discipline.displayName, so a tagged item that fails to resolve would print nothing at
    -- all rather than a wrong word -- silent, and exactly the kind of hole a sweep would miss.
    for id, item in pairs(Item.defs) do
        if item.discipline then
            local name = Discipline.displayName(item.discipline)
            assert(type(name) == "string" and name ~= "",
                id .. ": discipline '" .. tostring(item.discipline) .. "' has no display name")
        end
    end
    -- An absent or stale id names nothing, so the label is simply skipped instead of leaking a slug.
    assert(Discipline.displayName(nil) == nil, "no discipline names nothing")
    assert(Discipline.displayName("not_a_discipline") == nil, "an unknown discipline names nothing")
end }

tests[#tests + 1] = { name = "growthClasses tallies the discipline itself, else the bare class", fn = function()
    -- A discipline item grows ITS OWN path (ninja), not its parents -- each discipline has a growth
    -- table of its own now (data/growth/ninja.lua), so a ninja build grows into a ninja.
    local g = Discipline.growthClasses({ class = "rogue", discipline = "ninja" })
    assert(#g == 1 and g[1] == "ninja", "a ninja item tallies the ninja growth path")
    -- A plain classed item grows its one class.
    local gp = Discipline.growthClasses({ class = "fighter" })
    assert(#gp == 1 and gp[1] == "fighter", "a plain item tallies its single class")
    -- A class-less, discipline-less item (a natural weapon, a torch) tallies nothing.
    assert(#Discipline.growthClasses({}) == 0, "a class-less item tallies nothing")
    -- An item whose discipline id is unknown falls through to its class rather than tallying a
    -- growth path that has no table.
    local gu = Discipline.growthClasses({ class = "mage", discipline = "not_a_discipline" })
    assert(#gu == 1 and gu[1] == "mage", "an unknown discipline falls back to the class")
end }

tests[#tests + 1] = { name = "every discipline has a growth table of its own, naming only real stats", fn = function()
    -- The growth model reads a tally key straight into data/growth/<key>.lua (Growth.applyLevel), so a
    -- discipline that is tallied but has no table would silently grow nothing. Every discipline must
    -- carry one -- this is what lets growthClasses return the discipline id above.
    local Growth = require("models.growth")
    local Character = require("models.character")
    local known = {}
    for _, s in ipairs(Character.RESOURCE_STATS) do known[s] = true end
    for _, s in ipairs({ "staminaRegen", "damage", "magicDamage", "defense", "magicDefense", "speed" }) do
        known[s] = true
    end

    for id in pairs(Discipline.defs) do
        local def = Growth.defs[id]
        assert(def, id .. ": no data/growth/" .. id .. ".lua -- its items would grow nothing")
        assert(next(def), id .. " growth table is empty")
        assert(def.movement == nil, id .. " must not grow movement (grid balance)")
        for stat in pairs(def) do
            assert(known[stat], id .. " grows unknown stat '" .. tostring(stat) .. "'")
        end
    end
end }

-- ---------------------------------------------------------------- announcements
tests[#tests + 1] = { name = "a newly unlocked discipline is pending at its parent vendor, once", fn = function()
    local Player = require("models.player")
    local p = Player.new()

    -- Nothing done: nothing to announce anywhere.
    assert(#Discipline.pendingAnnouncements(p, "fighter") == 0, "a fresh player has no unlocks")

    -- Warlord (a fighter subclass) gates on warlord_keep. Clear it, and the discipline is pending at
    -- the fighter shelf.
    p.completedQuests.quest_colosseum_slot_03 = true
    local pend = Discipline.pendingAnnouncements(p, "fighter")
    local found = false
    for _, id in ipairs(pend) do if id == "warlord" then found = true end end
    assert(found, "warlord should be pending at the fighter vendor once its gate is done")

    -- It is not pending on an unrelated shelf.
    for _, id in ipairs(Discipline.pendingAnnouncements(p, "priest")) do
        assert(id ~= "warlord", "warlord is not a priest discipline")
    end

    -- Announced once, it drops off -- the scene never repeats.
    Player.markDisciplineAnnounced(p, "warlord")
    for _, id in ipairs(Discipline.pendingAnnouncements(p, "fighter")) do
        assert(id ~= "warlord", "an announced discipline is no longer pending")
    end
    assert(Player.hasAnnouncedDiscipline(p, "warlord"), "the flag records the announcement")
end }

tests[#tests + 1] = { name = "a multiclass announces at exactly one of its two parents", fn = function()
    local Player = require("models.player")
    local Conversation = require("models.conversation")
    local p = Player.new()

    -- Champion (fighter x knight) needs a subclass of each parent, then its capstone. Clear the
    -- shortest path: warlord_keep (fighter), held_position (knight), quest_colosseum_champions_challenge (capstone).
    for _, q in ipairs({ "quest_colosseum_slot_03", "quest_bastion_slot_03", "quest_colosseum_champions_challenge" }) do
        p.completedQuests[q] = true
    end
    assert(Discipline.isUnlocked(p, "champion"), "champion should be unlocked by the three quests")

    -- Pending at BOTH parent shelves before it is announced.
    local function pends(class, id)
        for _, d in ipairs(Discipline.pendingAnnouncements(p, class)) do
            if d == id then return true end
        end
        return false
    end
    assert(pends("fighter", "champion") and pends("knight", "champion"),
        "an un-announced multiclass is pending on both parent shelves")

    -- Announcing it at the first shop opened claims it for good -- the second parent does not repeat.
    Player.markDisciplineAnnounced(p, "champion")
    assert(not pends("fighter", "champion") and not pends("knight", "champion"),
        "one announcement covers both shelves")
end }

tests[#tests + 1] = { name = "every vendor class has an announcement scene to play", fn = function()
    local Vendor = require("models.vendor")
    local Conversation = require("models.conversation")
    -- Every discipline's parents are real vendor classes, and each of those vendors owns a
    -- conversation_<id>_discipline_unlocked scene -- otherwise a shelf could unlock stock with no way to announce it.
    local classToVendor = {}
    for id, def in pairs(Vendor.defs) do
        if def.class then classToVendor[def.class] = id end
    end
    local parents = {}
    for _, ddef in pairs(Discipline.defs) do
        for _, c in ipairs(ddef.classes or {}) do parents[c] = true end
    end
    for class in pairs(parents) do
        local vendorId = classToVendor[class]
        assert(vendorId, "no vendor sells the " .. class .. " shelf")
        assert(Conversation.defs["conversation_" .. vendorId .. "_discipline_unlocked"],
            vendorId .. " has no discipline_unlocked scene for its shelf")
    end
end }

-- ---------------------------------------------------------------- growth wiring
tests[#tests + 1] = { name = "a discipline-heavy build grows along the discipline's own table", fn = function()
    local Growth = require("models.growth")
    local Character = require("models.character")

    -- A character who casts mostly Ninja stock should grow as a ninja, not as rogue or mage.
    local c = Character.instantiate("character_clem") -- innate rogue
    for _ = 1, 5 do
        for _, cls in ipairs(Discipline.growthClasses({ class = "rogue", discipline = "ninja" })) do
            Character.recordTechnique(c, cls, Discipline.TECHNIQUE_PER_ACTION)
        end
    end
    Character.recordTechnique(c, "rogue", Discipline.TECHNIQUE_PER_ACTION) -- some base-class use, but ninja leads
    assert(Growth.dominantClass(c) == "ninja", "the ninja ledger should lead the build")

    -- And it leads the level-up's apportionment too, rather than merely the title.
    local shares = Growth.shares(c)
    assert(shares.ninja > shares.rogue, "the ninja share is the larger half of the next level")

    -- And applying that level uses the ninja table, which is neither parent's.
    local before = c.growth and c.growth.magicDamage or 0
    Growth.applyLevel(c, "ninja")
    local after = c.growth.magicDamage or 0
    assert(after > before, "ninja growth adds magicDamage (rogue alone never would)")
end }

-- --------------------------------------------------------- missingParents (the shelf's direction)
tests[#tests + 1] = { name = "missingParents names the crossing's unmet half, and empties as it is met", fn = function()
    local Player = require("models.player")
    local p = Player.new()
    p.completedQuests = {}

    -- Ninja is rogue x mage. With nothing done, BOTH halves are missing.
    local missing = Discipline.missingParents(p, "ninja")
    assert(#missing == 2, "a fresh player is short both of Ninja's parents, got " .. #missing)

    -- Open every ROGUE subclass and only the rogue half is satisfied. This is the case the shop's
    -- lockReason renders as "needs a mage path (The Arcanum)" -- if this ever returned the wrong
    -- class, the shelf would point the player at the wrong building.
    for _, def in pairs(Discipline.defs) do
        if #(def.classes or {}) == 1 and def.classes[1] == "rogue" then
            for _, q in ipairs(def.requiredQuests or {}) do p.completedQuests[q] = true end
        end
    end
    missing = Discipline.missingParents(p, "ninja")
    assert(#missing == 1 and missing[1] == "mage",
        "only the mage half should remain, got " .. table.concat(missing, ","))

    -- A SUBCLASS has no parent requirement of its own, so it never reports one -- its gate is its
    -- own quest, which is a different sentence in the panel.
    assert(#Discipline.missingParents(p, "assassin") == 0, "a subclass has no parents to be short of")
    assert(#Discipline.missingParents(p, nil) == 0, "an absent id is not an error")
    assert(#Discipline.missingParents(p, "not_a_discipline") == 0, "nor is an unknown one")
end }

tests[#tests + 1] = { name = "every class maps to the house that sells it, and the Forge agrees", fn = function()
    local Vendor = require("models.vendor")
    local Forge = require("models.forge")
    local Item = require("models.item")

    for class in pairs(Item.CLASSES) do
        local id = Vendor.forClass(class)
        assert(id, class .. " has no house")
        assert((Vendor.get(id) or {}).class == class, "the house " .. tostring(id) .. " sells " .. class)
        -- The Forge's own accessor now delegates here. Pinned because the two used to keep separate
        -- reverse indexes over the same field, which is exactly how they would drift apart.
        assert(Forge.houseVendorFor(class) == id, "Forge and Vendor must name the same house for " .. class)
    end
    assert(Vendor.forClass(nil) == nil, "a classless item wants no house")
end }

return tests
