-- Tests for THE COMPANY'S PACK: the bag that goes down the stair, and the one container a company can
-- reach while it is underground.
--
-- WHAT THIS FILE IS HOLDING. CLAUDE.md has always stated the carry law -- "what a company carries down
-- is what the four who walk down have in their grids; the stash stays in town" -- and until the pack
-- shipped that law was enforced in exactly ONE place, the overworld's Use panel. The Loadout screen
-- showed the whole town shelf as a live drag source on floor nine, so a company could reach into the
-- city from the bottom of the rift. There was also nowhere to CHOOSE what came down: the grids are the
-- build (ui/adjacency_links.lua), so every draught a company brought cost it an adjacency.
--
-- So there are two halves here and they are different questions:
--
--   THE CONTAINER -- player.pack, where a find lands underground (Player.stow) and where a provision
--   sits until it is drunk. Emptied onto the shelf on the way out (Player.unpack).
--
--   THE TWO NUMBERS -- Descent.carried counts the BAG and Descent.found counts the TRIP's finds. They
--   were one number while there was no bag, and collapsing them again would charge a company's own
--   rations at a toll stair. Case 7 is that law and it is the reason this file exists at all.
--
-- The wipe's own half -- what is at risk and what is dropped -- is tests/extraction_spec.lua's subject;
-- what is added here is only the part the pack changed.

local Player = require("models.player")
local Descent = require("models.descent")
local Save = require("models.save")
local Item = require("models.item")
local Character = require("models.character")

-- A company standing on a floor: descentRun carrying an entry snapshot, which is exactly what makes
-- Player.packOpen true (states/game.lua parks the rollback point there on arrival).
local function underground(extra)
    local player = Player.new()
    player.roster = { Character.instantiate("character_knight") }
    if extra then extra(player) end
    player.descentRun = Descent.new(player, 1)
    player.descentRun.entry = Save.snapshot(player)
    return player
end

local function countIn(list, id)
    local n = 0
    for _, it in ipairs(list or {}) do
        if it and it.id == id then n = n + (it.quantity or 1) end
    end
    return n
end

local SWORD = "weapon_iron_sword"
local POTION = "consumable_healing_potion"

return {
    { name = "a find underground lands in the bag and never on the town shelf", fn = function()
        local player = underground()
        local before = #player.stash
        Player.stow(player, Item.instantiate(SWORD))
        assert(countIn(player.pack, SWORD) == 1, "the find did not reach the bag")
        assert(#player.stash == before, "the find reached the town shelf from underground")
    end },

    { name = "a grant in town lands on the shelf, and the bag is not the shelf", fn = function()
        local player = Player.new()
        assert(not Player.packOpen(player), "a company in town reads as underground")
        Player.stow(player, Item.instantiate(SWORD))
        assert(countIn(player.stash, SWORD) == 1, "a town grant missed the shelf")
        assert(countIn(player.pack, SWORD) == 0, "a town grant went into the bag")
    end },

    -- THE GATE IS NOT UNDERGROUND, which is the whole reason the flag reads `descentRun.entry` rather
    -- than `descentRun`. The run is seated the moment the player walks onto the Gate screen, so a
    -- company packing a bag there is still standing in the city and a purchase made there is a
    -- purchase made in town.
    { name = "a half-packed bag at the Gate is still a company standing in town", fn = function()
        local player = Player.new()
        player.descentRun = Descent.new(player, 1) -- seated by states/gate.lua on arrival
        Player.addToPack(player, Item.instantiate(POTION))
        assert(not Player.packOpen(player), "the Gate reads as underground")
        Player.stow(player, Item.instantiate(SWORD))
        assert(countIn(player.stash, SWORD) == 1, "a purchase at the Gate went into the bag")
    end },

    { name = "the ceiling counts the bag, rations included, and never the shelf", fn = function()
        local player = underground()
        for _ = 1, 40 do Player.addToStash(player, Item.instantiate(SWORD)) end
        assert(Descent.carried(player) == 0, "the town shelf is being counted against the bag")

        -- PROVISIONS COST SLOTS. This is the feature in one assertion: a draught packed at the Gate is
        -- a slot the next chest cannot have, which is the decision the bag exists to create.
        local room = Descent.carryRoom(player)
        Player.addToPack(player, Item.instantiate(POTION))
        assert(Descent.carryRoom(player) == room - 1,
            "packing a ration cost the company nothing, so the bag is not one bag")
    end },

    -- THE LAW, AND IT IS THE REASON Descent.found STILL EXISTS. The stair takes a share of the HAUL and
    -- may never reach into the kit somebody marched down with (states/game.lua's payToll). Descent.carried
    -- counts rations now, so a toll priced against it would quote a number the stair then could not
    -- take -- Player.takeAtRisk only ever hands over finds.
    { name = "the toll prices the haul, and packing rations never raises it", fn = function()
        local player = underground(function(p)
            for _ = 1, 3 do Player.addToPack(p, Item.instantiate(POTION)) end
        end)
        local run = player.descentRun
        assert(Descent.found(player, run) == 0, "what they packed reads as what they found")
        -- ONE SLOT, NOT THREE. The ceiling counts SLOTS and three draughts of the same id merge into
        -- one stack (Player.addToList, bounded by Item.maxStack) -- so a stack of potions costs the bag
        -- one cell, exactly as the pool column that draws it shows one cell. Descent.found below still
        -- counts QUANTITIES, because a toll spends pieces rather than cells; the two units are the
        -- second half of why these are two functions.
        assert(Descent.carried(player) == 1,
            "a stack of three read as " .. Descent.carried(player) .. " slots rather than one")

        Player.stow(player, Item.instantiate(SWORD))
        assert(Descent.found(player, run) == 1, "the find did not register as found")

        -- ...AND THE BAG HAS MOVED UNDER IT WITHOUT THE TOLL NOTICING. Two slots now (the ration stack
        -- and the blade) against one find, so the two numbers have genuinely come apart -- which is the
        -- state a single `carried` could not represent and the state the stair must price correctly in.
        assert(Descent.carried(player) == 2, "the bag reads " .. Descent.carried(player))
        assert(Descent.tollFor("greed", Descent.found(player, run))
            <= Descent.found(player, run),
            "the stair asked for more than the trip has found")

        -- THE PILE ITSELF CARRIES NO RATION, which is the law as the player meets it: whatever share
        -- the stair names, what is actually handed over comes off the haul (Player.takeAtRisk) and the
        -- draughts packed in town are not in it.
        local taken = Player.takeAtRisk(player, run.entry)
        for _, it in ipairs(taken) do
            assert(it.id ~= POTION,
                "the stair reached into the rations somebody marched down with")
        end
    end },

    { name = "a wipe takes the finds out of the bag and leaves the provisions in it", fn = function()
        local player = underground(function(p)
            for _ = 1, 2 do Player.addToPack(p, Item.instantiate(POTION)) end
        end)
        local entry = player.descentRun.entry
        Player.stow(player, Item.instantiate(SWORD))
        Player.stow(player, Item.instantiate(SWORD))

        local haul = Player.takeAtRisk(player, entry)
        assert(#haul == 2, "the pile holds " .. #haul .. " rather than the two finds")
        for _, it in ipairs(haul) do
            assert(it.id == SWORD, "a provision was taken onto the pile: " .. tostring(it.id))
        end
        assert(countIn(player.pack, POTION) == 2,
            "the rations went with the haul -- nothing the company owned when it walked in may be taken")
    end },

    -- A STACK PART-BROUGHT AND PART-FOUND SPLITS, which is extraction_spec's rule holding over the new
    -- container: dropping the whole stack would bill the company for what it packed.
    { name = "a stack the company packed and then added to splits at the line it walked in on", fn = function()
        local player = underground(function(p)
            local flask = Item.instantiate(POTION)
            flask.quantity = 2
            Player.addToPack(p, flask)
        end)
        local entry = player.descentRun.entry
        if not Item.isStackable(Item.defs[POTION]) then return end -- nothing to split; the rule is vacuous

        Player.stow(player, Item.instantiate(POTION)) -- merges into the packed stack
        assert(countIn(player.pack, POTION) == 3, "the find did not merge into the packed stack")

        local haul = Player.takeAtRisk(player, entry)
        local dropped = 0
        for _, it in ipairs(haul) do dropped = dropped + (it.quantity or 1) end
        assert(dropped == 1, "the wipe took " .. dropped .. " of a stack the company brought two of")
        assert(countIn(player.pack, POTION) == 2, "the two that walked in did not stay")
    end },

    { name = "climbing out empties the bag onto the shelf and closes it", fn = function()
        local player = underground()
        Player.stow(player, Item.instantiate(SWORD))
        Player.addToPack(player, Item.instantiate(POTION))

        local moved = Player.unpack(player)
        assert(moved == 2, "unpack moved " .. moved .. " rather than the two in the bag")
        assert(#player.pack == 0, "the bag still holds something after being emptied")
        assert(countIn(player.stash, SWORD) == 1, "the find never reached the shelf")
        assert(countIn(player.stash, POTION) == 1, "the ration never reached the shelf")

        player.descentRun = nil
        assert(not Player.packOpen(player), "the bag is still open with no run to hold it")
    end },

    { name = "the bag rides a save, and an older save loads carrying nothing", fn = function()
        local player = underground()
        Player.addToPack(player, Item.instantiate(POTION))
        local snap = Save.snapshot(player)
        assert(snap.pack and #snap.pack == 1, "the bag did not reach the snapshot")

        local back = Save.restore(Save.decode("return " .. Save.encode(snap, 0)))
        assert(countIn(back.pack, POTION) == 1, "the bag did not survive the round trip")

        -- EMPTY WRITES NOTHING, the `floors` rule: a company that has never packed a bag should not
        -- carry the field at all, so an older save diffs clean against a new one.
        local fresh = Save.snapshot(Player.new())
        assert(fresh.pack == nil, "an empty bag is writing a field into every save")

        -- ...AND A SAVE FROM BEFORE THE BAG EXISTED LOADS CARRYING ONE. Built by taking the field back
        -- out of a real snapshot rather than by restoring an empty table, which is not a save shape.
        snap.pack = nil
        local older = Save.restore(Save.decode("return " .. Save.encode(snap, 0)))
        assert(type(older.pack) == "table" and #older.pack == 0,
            "a save written before the bag existed did not load with an empty one")
    end },

    -- A PACKED DRAUGHT HAS TO BE DRINKABLE, or provisioning is a screen that takes things away from
    -- you. The shelf is narrowed away underground (opts.stash = false) and the bag never is.
    { name = "a draught in the bag is reachable underground, and the shelf still is not", fn = function()
        local player = underground()
        Player.addToPack(player, Item.instantiate(POTION))
        Player.addToStash(player, Item.instantiate(POTION))

        local reach = Player.partyRestoratives(player, { party = player.roster, stash = false })
        local fromPack, fromStash = 0, 0
        for _, entry in ipairs(reach) do
            if entry.where == "pack" then fromPack = fromPack + 1 end
            if entry.where == "stash" then fromStash = fromStash + 1 end
        end
        assert(fromPack == 1, "the draught in the bag is out of reach on the floor it was carried to")
        assert(fromStash == 0, "the town shelf is being poured from nine floors underground")
    end },

    -- ...AND AN EMPTIED PACK STACK IS CLEARED. Testing only for "stash" left a zero-quantity stack in
    -- the bag forever, holding a slot against a ceiling that counts slots.
    { name = "the last draught out of the bag takes its empty stack with it", fn = function()
        local player = underground()
        local flask = Item.instantiate(POTION)
        flask.quantity = 1
        Player.addToPack(player, flask)

        local body = player.roster[1]
        local hp = body.stats and body.stats.health
        if type(hp) == "table" then hp.current = math.max(1, math.floor(hp.max / 2)) end

        local entry = { item = flask, where = "pack" }
        Player.consumeRestorative(player, entry, body)
        assert(flask.quantity == 0, "the draught was not drunk")
        assert(#player.pack == 0,
            "the emptied stack is still sitting in the bag, holding a slot a chest will be refused for")
    end },
}
