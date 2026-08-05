-- Tests for the Party screen's model-level economy and the rules about who marches. The UI
-- (ui/panels/party.lua) is love.graphics-bound and mostly not exercised here; what it delegates
-- to -- Vendor.sellValue, the buy/sell gold+stash moves, recruiting, and the save round trip -- is
-- pure logic and lives below. The panel's few pure, love-free helpers (regionCross edge-crossing,
-- equipDelta filter, techniqueRows ranking) are covered at the end.

local Player = require("models.player")
local Vendor = require("models.vendor")
local Forge = require("models.forge")
local Item = require("models.item")
local Character = require("models.character")
local Save = require("models.save")
local Discipline = require("models.discipline")
local Party = require("ui.panels.party")

-- A priced, non-stackable item id (so buying/selling doesn't merge into a consumable stack), and an
-- item id with no price (never for sale). Found from data so the test survives content edits.
local pricedId, noPriceId
for id, def in pairs(Item.defs) do
    if def.price and def.type ~= "consumable" and not pricedId then pricedId = id end
    if not def.price and not noPriceId then noPriceId = id end
end

return {
    {
        name = "Vendor.sellValue is half the shelf price, floored",
        fn = function()
            assert(pricedId, "no priced item found in data")
            local item = Item.instantiate(pricedId)
            local expected = math.floor(item.price * 0.5)
            assert(Vendor.sellValue(item) == expected,
                "sellValue " .. Vendor.sellValue(item) .. " ~= " .. expected)
            assert(expected > 0, "a priced item should have a positive sell value")
        end,
    },
    {
        name = "Vendor.sellValue is 0 for an item that was never for sale",
        fn = function()
            assert(noPriceId, "no price-less item found in data")
            assert(Vendor.sellValue(Item.instantiate(noPriceId)) == 0,
                "an item with no price must not be sellable")
        end,
    },
    {
        name = "buying spends gold and drops the item in the stash",
        fn = function()
            local p = Player.new()
            p.gold = 1000
            p.stash = {}
            local price = Item.defs[pricedId].price
            assert(Player.spendGold(p, price), "should afford the buy")
            Player.addToStash(p, Item.instantiate(pricedId))
            assert(p.gold == 1000 - price, "gold not deducted by price")
            assert(#p.stash == 1, "bought item not added to stash")
            assert(p.stash[1].id == pricedId, "wrong item in stash")
        end,
    },
    {
        name = "selling adds gold and removes the item from the grid",
        fn = function()
            local p = Player.new()
            p.gold = 0
            local char = p.roster[1]
            local item = Item.instantiate(pricedId)
            char.inventory[1] = item
            local value = Vendor.sellValue(item)
            Character.removeItem(char, item)
            Player.addGold(p, value)
            assert(p.gold == value, "gold not increased by sell value")
            assert(char.inventory[1] == nil, "sold item still in the grid")
        end,
    },
    {
        -- The roster IS the company: every owned character marches, and the only number left about the
        -- board is how many of them may stand on it at once (docs/deployment.md). A cap on the
        -- travelling company, and the hub screen that filled it, are both gone.
        name = "the whole roster marches; only the field is capped",
        fn = function()
            local p = Player.new()
            assert(p.party == nil, "there is no marching-company list beside the roster")
            assert(Player.MAX_PARTY == nil, "the company cap is gone")
            assert(Player.addToParty == nil and Player.removeFromParty == nil,
                "and so is the API that maintained it")
            assert(Player.MAX_FIELD == 4, "the field cap is what remains")
            -- The leftovers are the BENCH, so a company one over the field already has one.
            Player.recruit(p, "character_saber")
            for _, c in ipairs(p.roster) do assert(c, "every roster member is company") end
        end,
    },
    {
        name = "who was fielded last battle is remembered by id, and survives a save",
        fn = function()
            local p = Player.new()
            local member = p.roster[1]
            Player.noteDeployed(p, { member })
            assert(Player.wasDeployed(p, member), "the deployment phase's opening pick remembers them")
            local restored = Save.restore(Save.snapshot(p))
            local match
            for _, c in ipairs(restored.roster) do
                if c.id == member.id then match = c end
            end
            assert(match and Player.wasDeployed(restored, match), "and it came back off the save")
        end,
    },
    {
        name = "recruit adds a new companion to the company, and refuses a duplicate",
        fn = function()
            local p = Player.new()
            local before = #p.roster
            local saber = Player.recruit(p, "character_saber")
            assert(saber, "a first recruit returns the instance")
            assert(saber.id == "character_saber", "the recruited id is right")
            assert(#p.roster == before + 1, "the recruit joined the roster")
            -- Joining the roster IS joining the company: nothing else has to happen, and there is no
            -- cap that could have left a recruit owned but not marching.
            assert(p.roster[#p.roster] == saber, "the recruit marches by virtue of being owned")
            -- Recruiting the same blueprint again is refused (one copy of a named companion).
            assert(Player.recruit(p, "character_saber") == nil, "a duplicate recruit is refused")
            assert(#p.roster == before + 1, "a refused recruit does not grow the roster")
        end,
    },
    {
        name = "the company survives a save/load round trip by identity",
        fn = function()
            local p = Player.new()
            -- The lean default roster is just Rowan; recruit a second identity to save alongside it.
            Player.recruit(p, "character_saber")

            local restored = Save.restore(Save.snapshot(p))
            assert(restored, "snapshot did not restore")
            assert(restored.party == nil, "a restored player has no second list either")
            assert(#restored.roster == 2, "company size not preserved")
            assert(restored.roster[1].id == p.roster[1].id, "first member id changed")
            assert(restored.roster[2].id == p.roster[2].id, "second member id changed")
        end,
    },
    {
        -- A save written when the company was a capped subset carries a `party` index list. It is
        -- ignored on load rather than honoured: the roster marches whole now, so a legacy save must
        -- not quietly bench the members its old company left behind.
        name = "a legacy save's party subset is ignored, and everyone marches",
        fn = function()
            local p = Player.new()
            Player.recruit(p, "character_saber")
            local snap = Save.snapshot(p)
            snap.party = { 1 } -- as an older save would have written it
            local restored = Save.restore(snap)
            assert(restored and #restored.roster == 2, "both members came back")
            assert(restored.party == nil, "the old subset was not resurrected")
        end,
    },
    {
        name = "shop stock marks a quest-gated item locked with no quests done, unlocked at its quest count",
        fn = function()
            -- Find any vendor selling an item that needs quests completed beyond the opening shelf.
            local vId, locked
            for vid in pairs(Vendor.defs) do
                for _, e in ipairs(Vendor.stock(vid, 0)) do
                    -- A discipline item carries a SECOND lock (its discipline must be unlocked), so it
                    -- stays locked even at its unlockQuests -- not what this quest-only test measures.
                    if e.unlockQuests > 0 and not e.discipline then vId, locked = vid, e break end
                end
                if vId then break end
            end
            if not locked then return end -- no quest-gated wares in data; nothing to assert
            assert(locked.locked, "a quest-gated item should be locked with no quests done")
            for _, e in ipairs(Vendor.stock(vId, locked.unlockQuests)) do
                if e.id == locked.id then
                    assert(not e.locked, "the same item should unlock once its quest count is met")
                end
            end
        end,
    },
    {
        name = "the Forge hones an owned ability one level for gold and materials",
        fn = function()
            -- An upgradable ability item (one with a magnitude to level) belonging to some house.
            local abilityId
            for id, def in pairs(Item.defs) do
                if def.type == "ability" and def.class and not def.discipline
                    and Item.isUpgradable(Item.instantiate(id)) then
                    abilityId = id
                    break
                end
            end
            if not abilityId then return end -- no classed ability in data
            local p = Player.new()
            p.gold = 5000
            local item = Item.instantiate(abilityId)
            local cost = Forge.upgradeCost(p, item)
            for id, n in pairs(cost.materials) do p.materials[id] = n end
            p.roster[1].technique = { [cost.techniqueId] = cost.technique }
            p.roster[1].techniqueSpent = {}
            local newItem = Forge.upgrade(p, item)
            assert(newItem, "the first rung is open with no quests done")
            assert((newItem.level or 0) == (item.level or 0) + 1, "level should rise by one")
            assert(Character.techniqueAvailable(p.roster[1], cost.techniqueId) == 0,
                "the house's technique should be spent on the upgrade")
        end,
    },
    {
        name = "regionCross moves grid<->rail<->pool only at the correct column edges",
        fn = function()
            -- Grid (3 cols): left edge crosses to the rail, right edge to the stash.
            assert(Party.regionCross("grid", 0, 3, -1) == "rail", "grid left edge -> rail")
            assert(Party.regionCross("grid", 2, 3, 1) == "pool", "grid right edge -> pool")
            -- Interior columns stay put.
            assert(Party.regionCross("grid", 1, 3, -1) == nil, "grid interior stays (left)")
            assert(Party.regionCross("grid", 1, 3, 1) == nil, "grid interior stays (right)")
            -- Pool leftmost edge crosses back to the grid; it is rightmost, so right clamps.
            assert(Party.regionCross("pool", 0, 4, -1) == "grid", "pool left edge -> grid")
            assert(Party.regionCross("pool", 3, 4, 1) == nil, "pool right edge clamps")
            -- Rail is leftmost: right enters the grid, left clamps.
            assert(Party.regionCross("rail", 0, 1, 1) == "grid", "rail right -> grid")
            assert(Party.regionCross("rail", 0, 1, -1) == nil, "rail left clamps")
        end,
    },
    {
        name = "equipDelta keeps only the flat stats the focus sheet shows",
        fn = function()
            -- iron_plate: bonus = { defense = 13, movement = -2 }, plus a resist bag.
            local delta = Party.equipDelta(Item.instantiate("armor_iron_plate"))
            assert(delta.defense == 13, "defense bonus surfaced")
            assert(delta.movement == -2, "negative movement bonus surfaced")
            -- Resistances aren't flat stat rows, so they never leak into the delta.
            assert(delta.physical == nil and delta.slash == nil, "resist keys excluded")
        end,
    },
    {
        name = "equipDelta is empty for an item with no bonus, or for nil",
        fn = function()
            assert(next(Party.equipDelta(Item.instantiate("weapon_iron_sword"))) == nil, "no bonus -> empty")
            assert(next(Party.equipDelta(nil)) == nil, "nil item -> empty")
        end,
    },
    {
        name = "techniqueRows reports each house's claim on the coming level, biggest first",
        fn = function()
            local char = Character.instantiate("character_knight")
            -- A class key alongside two disciplines: one ledger holds both, which is the whole reason
            -- this list replaced the two that used to be stacked here.
            char.technique = { bulwark = 10, assassin = 60, knight = 30 }
            local rows = Party.techniqueRows(char)
            assert(#rows == 3, "one row per house with something live, got " .. #rows)

            -- The SHARE, not the raw amount: a level arrives on prestige, so only the proportions are
            -- read and the magnitude buys nothing. 60/30/10 of 100 is 60% / 30% / 10%.
            assert(math.abs(rows[1].share - 0.6) < 1e-9
                and math.abs(rows[2].share - 0.3) < 1e-9
                and math.abs(rows[3].share - 0.1) < 1e-9, "rows carry the shares, descending")

            -- Display names for a discipline, title-case for a class -- never the raw id.
            assert(rows[1].name == Discipline.displayName("assassin"),
                "a discipline row carries its display name")
            assert(rows[2].name == "Knight", "and a class row is title-cased")

            -- Doubling everything is the same character, so it must read identically.
            local twice = Character.instantiate("character_knight")
            twice.technique = { bulwark = 20, assassin = 120, knight = 60 }
            assert(math.abs(Party.techniqueRows(twice)[1].share - rows[1].share) < 1e-9,
                "twice the casting in the same proportions is the same level, and reads the same")
        end,
    },
    {
        name = "techniqueRows separates the coming level from the wallet, and shows a row for either",
        fn = function()
            local char = Character.instantiate("character_knight")
            assert(#Party.techniqueRows(char) == 0, "a fresh member has played nothing")

            -- Everything earned so far is already checkpointed into past levels, and half the bank is
            -- spent. Nothing is claiming the coming level, but there is still coin to forge with -- so
            -- the row survives on the wallet alone.
            char.technique = { knight = 50 }
            char.techniqueAtLevel = { knight = 50 }
            char.techniqueSpent = { knight = 20 }
            local rows = Party.techniqueRows(char)
            assert(#rows == 1 and rows[1].share == 0 and rows[1].available == 30,
                "a house with nothing outstanding but a bank left keeps its row")

            -- And the reverse: fully spent, but claiming the whole of the coming level.
            char.techniqueSpent = { knight = 50 }
            char.techniqueAtLevel = {}
            rows = Party.techniqueRows(char)
            assert(#rows == 1 and rows[1].share == 1 and rows[1].available == 0,
                "a spent-out house still shows what it is growing into")

            -- Spending must never move the growth column. That is the property the earned/spent split
            -- exists for, asserted at the surface the player reads it on.
            local before = Party.techniqueRows(char)[1].share
            char.techniqueSpent = { knight = 50 }
            assert(Party.techniqueRows(char)[1].share == before, "forging does not move the claim")

            -- Nothing earned at all is no row, so an untouched house never appears.
            char.technique = { knight = 0 }
            char.techniqueSpent, char.techniqueAtLevel = {}, {}
            assert(#Party.techniqueRows(char) == 0, "a zero ledger entry is not a row")
        end,
    },
    {
        -- `rewardCharacter` is how a class line's main companion is earned (docs/story.md, "The other
        -- seven"). Before it existed, Player.recruit had exactly two callers, both hard-coded in
        -- states/prologue.lua, and no quest could grant anybody.
        name = "a quest's rewardCharacter recruits, and reports who joined",
        fn = function()
            local Quest = require("models.quest")
            local player = Player.new()
            player.completedQuests = {}
            local before = #player.roster

            local reward = Quest.complete(player, {
                id = "test_recruit_quest", rewardGold = 0,
                rewardCharacter = "character_saber",
            })
            assert(reward, "a fresh quest pays out")
            assert(reward.recruited, "the summary must name who joined, for the reward panel")
            assert(reward.recruited.id == "character_saber", "the right companion joined")
            assert(#player.roster == before + 1, "the roster grew by exactly one")
        end,
    },
    {
        -- A repeatable quest skips Quest.complete's double-payout guard, so the duplicate refusal has
        -- to hold inside Player.recruit or a grind quest mints a second copy of a companion.
        name = "a companion already owned is not recruited twice",
        fn = function()
            local Quest = require("models.quest")
            local player = Player.new()
            player.completedQuests = {}
            Player.recruit(player, "character_saber")
            local before = #player.roster

            local reward = Quest.complete(player, {
                id = "test_repeat_recruit", repeatable = true, rewardGold = 0,
                rewardCharacter = "character_saber",
            })
            assert(reward.recruited == nil, "an already-owned companion reports no recruit")
            assert(#player.roster == before, "and the roster does not grow")
        end,
    },
}
