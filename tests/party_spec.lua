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
        name = "equipDelta previews a flat bonus and a resource ceiling, off the right field for each",
        fn = function()
            -- iron_plate: bonus = { defense = 13, movement = -2 }, plus a resist bag.
            local delta = Party.equipDelta(Item.instantiate("armor_iron_plate"))
            assert(delta.defense == 13, "defense bonus surfaced")
            assert(delta.movement == -2, "negative movement bonus surfaced")
            -- Resistances aren't stat rows, so they never leak into the delta.
            assert(delta.physical == nil and delta.slash == nil, "resist keys excluded")

            -- A POOL ROW moves too, and its raise lives on item.maxBonus (Toughness, Endurance,
            -- Attunement). The sheet counts those toward the ceiling it prints, so the preview of
            -- picking one up has to read the same field the sheet does.
            local charm = Item.instantiate("armor_iron_plate")
            charm.bonus, charm.maxBonus = nil, { health = 12, stamina = 3 }
            delta = Party.equipDelta(charm)
            assert(delta.health == 12 and delta.stamina == 3,
                "a maxBonus ceiling raise is previewed, on every pool row")

            -- And the mirror: `bonus.health` raises no ceiling anywhere in Combat, so previewing it
            -- would promise a pool the item never delivers.
            charm.bonus, charm.maxBonus = { health = 99 }, nil
            assert(next(Party.equipDelta(charm)) == nil,
                "a health bonus filed under `bonus` previews nothing, exactly as it does nothing")
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
        name = "growthShares reports each house's claim on the coming level, biggest first",
        fn = function()
            local char = Character.instantiate("character_knight")
            -- A class key alongside two disciplines: one ledger holds both, which is the whole reason
            -- this list replaced the two that used to be stacked here.
            char.technique = { bulwark = 10, assassin = 60, knight = 30 }
            local rows = Party.growthShares(char)
            assert(#rows == 3, "one row per house claiming the level, got " .. #rows)

            -- The SHARE, not the raw amount: a level arrives on prestige, so only the proportions are
            -- read and the magnitude buys nothing. 60/30/10 of 100 is 60% / 30% / 10%.
            assert(math.abs(rows[1].share - 0.6) < 1e-9
                and math.abs(rows[2].share - 0.3) < 1e-9
                and math.abs(rows[3].share - 0.1) < 1e-9, "rows carry the shares, descending")

            -- Display names for a discipline, title-case for a class -- never the raw id.
            assert(rows[1].name == Discipline.displayName("assassin"),
                "a discipline row carries its display name")
            assert(rows[2].name == "Knight", "and a class row is title-cased")

            -- The printed form, which is what the title line and the forecast under it are built from.
            local parts = Party.growthParts(char)
            assert(parts[1] == "60% " .. Discipline.displayName("assassin")
                and parts[2] == "30% Knight", "the parts read as percent-then-house")

            -- Doubling everything is the same character, so it must read identically.
            local twice = Character.instantiate("character_knight")
            twice.technique = { bulwark = 20, assassin = 120, knight = 60 }
            assert(math.abs(Party.growthShares(twice)[1].share - rows[1].share) < 1e-9,
                "twice the casting in the same proportions is the same level, and reads the same")
        end,
    },
    {
        name = "growthShares is empty when nothing is outstanding, rather than claiming the innate class",
        fn = function()
            local char = Character.instantiate("character_knight")
            assert(#Party.growthShares(char) == 0, "a fresh member has played nothing")
            assert(#Party.growthParts(char) == 0, "and so prints nothing")

            -- Everything earned is already checkpointed into past levels. Growth.shares would answer
            -- the innate class at 1.0 here -- true of a hypothetical level, but on a sheet it reads as
            -- a claim the player earned, and the title drops the clause instead.
            char.technique = { knight = 50 }
            char.techniqueAtLevel = { knight = 50 }
            assert(#Party.growthShares(char) == 0, "a fully checkpointed ledger claims nothing")

            -- Spending must never move the growth reading. That is the property the earned/spent split
            -- exists for, asserted at the surface the player reads it on.
            char.techniqueAtLevel = {}
            local before = Party.growthShares(char)[1].share
            char.techniqueSpent = { knight = 50 }
            assert(Party.growthShares(char)[1].share == before, "forging does not move the claim")
        end,
    },
    {
        name = "techniqueRows is one figure per house, fattest bank first",
        fn = function()
            local char = Character.instantiate("character_knight")
            assert(#Party.techniqueRows(char) == 0, "a fresh member has nothing banked")

            -- A class key alongside two disciplines: one ledger holds both, which is the whole reason
            -- this list replaced the two that used to be stacked here.
            char.technique = { bulwark = 10, assassin = 60, knight = 30 }
            char.techniqueSpent = { assassin = 55 }
            local rows = Party.techniqueRows(char)
            assert(#rows == 3, "one row per house with coin left, got " .. #rows)

            -- Ranked by what is LEFT, not by what was earned: assassin earned the most by a mile and
            -- sits last, because the Forge has already billed all but 5 of it.
            assert(rows[1].name == "Knight" and rows[1].available == 30, "the fattest bank leads")
            assert(rows[2].name == Discipline.displayName("bulwark") and rows[2].available == 10,
                "then the next -- and a discipline row carries its display name")
            assert(rows[3].name == Discipline.displayName("assassin") and rows[3].available == 5,
                "and a forged-down house falls to the bottom on 5")
            assert(rows[1].share == nil, "the claim column is gone, not merely unread")

            -- A house billed flat leaves the list entirely: there is nothing left to spend on it.
            char.techniqueSpent = { assassin = 60, bulwark = 10, knight = 30 }
            assert(#Party.techniqueRows(char) == 0, "spent out is no rows at all")

            -- Nothing earned at all is no row either, so an untouched house never appears.
            char.technique = { knight = 0 }
            char.techniqueSpent = {}
            assert(#Party.techniqueRows(char) == 0, "a zero ledger entry is not a row")
        end,
    },
    {
        -- The sheet prints the EFFECTIVE stat now, so the tooltip's parts and the sheet's figure are
        -- one list added up two ways -- Party.statTotal reads exactly what Party.statSources lists.
        name = "statSources itemizes a stat, and statTotal is the sum the sheet prints",
        fn = function()
            local char = Character.instantiate("character_knight")
            local blueprint = char.stats.damage
            char.growth = { damage = 4 }
            char.stats.damage = blueprint + 4

            local parts = Party.statSources(char, "damage")
            assert(#parts == 1, "no gear yet, so the body is the only source -- got " .. #parts)
            assert(parts[1].label == "Base" and parts[1].value == blueprint + 4,
                "the blueprint and its banked level-ups are ONE row: what the body is worth naked")
            assert(Party.statTotal(char, "damage") == blueprint + 4, "and that is the whole figure")

            char.inventory[1] = Item.instantiate("weapon_iron_sword")
            char.inventory[1].bonus = { damage = 6 }
            char.inventory[2] = Item.instantiate("weapon_iron_sword")
            char.inventory[2].bonus = { damage = -1, speed = 2 }
            parts = Party.statSources(char, "damage")
            assert(#parts == 3, "both bonus-bearing items are listed, got " .. #parts)
            assert(parts[2].value == 6 and parts[3].value == -1, "and a penalty is listed as one")
            assert(Party.statTotal(char, "damage") == blueprint + 4 + 6 - 1,
                "the sheet prints the body plus its gear -- what the unit actually swings for")

            -- An item that does not move THIS stat stays out of THIS list.
            local speed = Party.statSources(char, "speed")
            assert(#speed == 2 and speed[2].value == 2, "only the speed-moving item is listed there")

            -- A RESOURCE ceiling rides item.maxBonus, not item.bonus -- two different fields, kept
            -- apart by Combat (unit.bonus vs char.maxBonus). Reading the wrong one is silent, so it is
            -- pinned: a `bonus.health` must NOT count, and a `maxBonus.health` must.
            local baseHp = char.stats.health.max
            char.inventory[3] = Item.instantiate("weapon_iron_sword")
            char.inventory[3].bonus = { health = 99 }
            assert(Party.statTotal(char, "health") == baseHp,
                "a health bonus filed under `bonus` raises no ceiling, exactly as in battle")
            char.inventory[3].bonus = nil
            char.inventory[3].maxBonus = { health = 12 }
            local hp = Party.statSources(char, "health")
            assert(#hp == 2 and hp[1].value == baseHp and hp[2].value == 12,
                "a maxBonus item is what raises it, and it is named")
            assert(Party.statTotal(char, "health") == baseHp + 12, "so the ceiling reads 12 higher")

            assert(#Party.statSources(char, nil) == 0, "a nil key is answered, not raised")
            assert(#Party.statSources(nil, "damage") == 0, "and so is a nil character")
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
