-- Tests for models/draft_chassis.lua and the blueprint fields it reads: a drafted body arrives as its
-- signature weapon and verb, not its whole authored kit. Also the CONTRACT on data/characters -- every
-- id the draft pool can offer must name a signature, and that signature must be an item the blueprint
-- actually carries. Headless.

local DraftChassis = require("models.draft_chassis")
local DraftRun = require("models.draft_run")
local Character = require("models.character")
local Item = require("models.item")

-- Every id the pool can ever offer (the last wave opens at round 9; 12 covers the whole ladder).
local function poolIds()
    return DraftRun.pool(12)
end

local function kitIds(def)
    local ids = {}
    for _, entry in ipairs(def.startingItems or {}) do
        if type(entry) == "string" then ids[entry] = true
        elseif type(entry) == "table" then ids[entry.id or entry[1]] = true end
    end
    return ids
end

return {
    {
        name = "every draftable character names a signature weapon",
        fn = function()
            local ids = poolIds()
            assert(#ids > 0, "the pool is not empty")
            for _, id in ipairs(ids) do
                local def = Character.defs[id]
                assert(def.signatureWeapon,
                    id .. " must name a signatureWeapon -- it is what the draft strips it down to")
            end
        end,
    },
    {
        name = "a signature names a real item the blueprint actually carries",
        fn = function()
            for _, id in ipairs(poolIds()) do
                local def = Character.defs[id]
                local kit = kitIds(def)
                for _, field in ipairs({ "signatureWeapon", "signatureAbility" }) do
                    local sig = def[field]
                    if sig then
                        assert(Item.defs[sig], id .. "." .. field .. " names a real item: " .. sig)
                        -- A signature must be part of the authored kit, not an invention: the chassis is
                        -- a SUBSET of what the character was designed carrying, never a new loadout.
                        assert(kit[sig], id .. "." .. field .. " (" .. sig .. ") must be in its own startingItems")
                    end
                end
            end
        end,
    },
    {
        name = "the signature weapon and verb are two different items",
        fn = function()
            for _, id in ipairs(poolIds()) do
                local def = Character.defs[id]
                if def.signatureAbility then
                    assert(def.signatureWeapon ~= def.signatureAbility,
                        id .. " names the same item as both its weapon and its verb")
                end
            end
        end,
    },
    {
        name = "a drafted body carries only its signatures -- one item, or two",
        fn = function()
            for _, id in ipairs(poolIds()) do
                local char = DraftChassis.instantiate(id)
                local n = Character.itemCount(char)
                local def = Character.defs[id]
                local want = def.signatureAbility and 2 or 1
                assert(n == want, id .. " strips to " .. want .. " item(s), carried " .. n)

                local carried = {}
                for _, item in ipairs(Character.eachItem(char)) do carried[item.id] = true end
                assert(carried[def.signatureWeapon], id .. " kept its signature weapon")
                if def.signatureAbility then
                    assert(carried[def.signatureAbility], id .. " kept its signature verb")
                end
            end
        end,
    },
    {
        name = "the strip drops a lot -- the whole point of the change",
        fn = function()
            -- The Barbarian is the extreme case: a full nine-cell blueprint grid.
            local whole = Character.instantiate("character_barbarian")
            local chassis = DraftChassis.instantiate("character_barbarian")
            assert(Character.itemCount(whole) == 9, "the blueprint Barbarian fills the grid")
            assert(Character.itemCount(chassis) == 2, "the drafted one carries two")
            assert(Character.firstEmptySlot(chassis), "with room to buy into")
        end,
    },
    {
        name = "survivors are packed into the front cells, so adjacency is predictable",
        fn = function()
            for _, id in ipairs(poolIds()) do
                local char = DraftChassis.instantiate(id)
                local n = Character.itemCount(char)
                for cell = 1, n do
                    assert(char.inventory[cell], id .. " has no gap before cell " .. n)
                end
                for cell = n + 1, Character.MAX_INVENTORY do
                    assert(char.inventory[cell] == nil, id .. " left cell " .. cell .. " occupied")
                end
            end
        end,
    },
    {
        name = "the pinned default action still resolves after the repack",
        fn = function()
            for _, id in ipairs(poolIds()) do
                local def = Character.defs[id]
                local char = DraftChassis.instantiate(id)
                if char.defaultActionSlot then
                    local item = char.inventory[char.defaultActionSlot]
                    assert(item and item.id == def.defaultAction,
                        id .. " pins its default action at the wrong cell after stripping")
                end
            end
        end,
    },
    {
        name = "stripping is idempotent -- it never eats gear bought afterwards",
        fn = function()
            local char = DraftChassis.instantiate("character_ninja")
            local before = Character.itemCount(char)
            Character.addItem(char, Item.instantiate("weapon_iron_sword"))
            DraftChassis.strip(char)
            assert(Character.itemCount(char) == before + 1,
                "a second strip kept the signatures AND the piece the player bought")
        end,
    },
    {
        name = "a bound relic is never stripped away",
        fn = function()
            -- Rowan is not in the draft pool, but the rule is the strip's, not the pool's: a bound item
            -- is nailed to the body (models/draft_run.lua refuses to strip one off merge fodder too).
            local char = DraftChassis.instantiate("character_rowan")
            local kept = false
            for _, item in ipairs(Character.eachItem(char)) do
                if Item.isBound(item) then kept = true end
            end
            assert(kept, "Rowan kept her bound Sworn Aegis through the strip")
        end,
    },
    {
        name = "a character naming no signature falls back to its default action, not an empty body",
        fn = function()
            local char = Character.instantiate("character_barbarian")
            char.signatureWeapon, char.signatureAbility = nil, nil
            DraftChassis.strip(char)
            assert(Character.itemCount(char) == 1, "it degrades to a thin chassis, not nothing")
            assert(Character.eachItem(char)[1].id == Character.defs["character_barbarian"].defaultAction,
                "and what it kept is the blueprint's default action")
        end,
    },
    {
        name = "keywords summarise a chassis in a couple of words",
        fn = function()
            local char = DraftChassis.instantiate("character_fighter")
            local words = DraftChassis.keywords(char)
            assert(#words > 0, "a fighter reads as something")
            assert(words[1] == "Axe", "its weapon family leads: " .. tostring(words[1]))
            assert(#words <= 3, "and it stays glanceable")
        end,
    },
    {
        -- The censer is the priest's OWN family and belongs to no other shelf; a priest swinging a staff
        -- was carrying the mage's arm. Pinned here because it is the chassis a player meets in round one.
        name = "the priest drafts as a censer-bearer who heals",
        fn = function()
            local def = Character.defs["character_priest"]
            assert(def.signatureWeapon == "weapon_censer", "the priest's weapon is the censer")

            local char = DraftChassis.instantiate("character_priest")
            local carried = {}
            for _, item in ipairs(Character.eachItem(char)) do carried[item.id] = true end
            assert(carried["weapon_censer"] and carried["ability_heal"],
                "its chassis is the censer and the heal")

            local censer = Item.instantiate("weapon_censer")
            assert(Item.archetype(censer) == "censer", "and that weapon really is of the censer family")
            assert(DraftChassis.keywords(char)[1] == "Censer",
                "so the store card leads with Censer, not Staff")
        end,
    },
}
