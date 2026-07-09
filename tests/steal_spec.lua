-- Tests for pickpocketing (Combat.steal) and the deception around it: the Decoy that makes itself
-- the obvious thing to grab, the invisibility it buys, and the stash a full-handed thief falls back
-- on. Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- Wipe a character's grid and fill it from slot 1, so a spec owns the whole loadout.
local function equip(char, ids)
    char.inventory = {}
    for _, id in ipairs(ids) do Character.addItem(char, Item.instantiate(id)) end
end

local function itemNamed(char, id)
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory[i]
        if it and it.id == id then return it end
    end
    return nil
end

-- Run `fn` with Combat.random pinned, so a spec never depends on the global RNG's state.
local function withRandom(pick, fn)
    local saved = Combat.random
    Combat.random = function() return pick end
    local ok, err = pcall(fn)
    Combat.random = saved
    if not ok then error(err, 0) end
end

return {
    {
        name = "a thief lifts an item off its victim and into its own grid",
        fn = function()
            local thief = Character.instantiate("archer")
            equip(thief, { "ability_pickpocket" })
            local victim = Character.instantiate("bandit")
            equip(victim, { "iron_sword" })
            local c = Combat.new(arena(8, 8), { unit(thief, 2, 2) }, { unit(victim, 3, 2) })

            withRandom(1, function()
                local stolen = Combat.steal(c, c.units[1], c.units[2])
                assert(stolen and stolen.id == "iron_sword", "the sword is taken")
            end)
            assert(itemNamed(victim, "iron_sword") == nil, "the victim no longer has it")
            assert(itemNamed(thief, "iron_sword") ~= nil, "and the thief does")
        end,
    },
    {
        name = "a beast's natural weapon can never be stolen",
        fn = function()
            local thief = Character.instantiate("archer")
            equip(thief, { "ability_pickpocket" })
            local c = Combat.new(arena(8, 8), { unit(thief, 2, 2) }, { unit("wolf_grunt", 3, 2) })
            local wolf = c.units[2]

            withRandom(1, function()
                assert(Combat.steal(c, c.units[1], wolf) == nil, "there is nothing to take")
            end)
            assert(itemNamed(wolf.char, "fangs") ~= nil, "the wolf keeps its teeth")
        end,
    },
    {
        name = "a Decoy is always the first thing a thief grabs",
        fn = function()
            local thief = Character.instantiate("archer")
            equip(thief, { "ability_pickpocket" })
            local victim = Character.instantiate("bandit")
            equip(victim, { "iron_sword", "chainmail", "decoy", "healing_potion" })
            local c = Combat.new(arena(8, 8), { unit(thief, 2, 2) }, { unit(victim, 3, 2) })

            -- Pinning the RNG to 1 would pick the sword if priority didn't sort the pool first.
            withRandom(1, function()
                local stolen = Combat.steal(c, c.units[1], c.units[2])
                assert(stolen.id == "decoy", "the bait outranks everything else (got " .. stolen.id .. ")")
            end)
            assert(itemNamed(victim, "iron_sword") ~= nil, "the real gear is untouched")
        end,
    },
    {
        name = "a party thief with a full grid pockets the loot into the stash",
        fn = function()
            local thief = Character.instantiate("archer")
            equip(thief, { "bow", "chainmail", "torch", "buckler", "trap_sense",
                           "ability_spike_trap", "ability_jolt", "silk_robes", "ability_pickpocket" })
            assert(Character.firstEmptySlot(thief) == nil, "the thief's grid is full")
            local victim = Character.instantiate("bandit")
            equip(victim, { "iron_sword" })

            local c = Combat.new(arena(8, 8), { unit(thief, 2, 2) }, { unit(victim, 3, 2) })
            local stash = {}
            c.stash = stash

            withRandom(1, function() Combat.steal(c, c.units[1], c.units[2]) end)
            assert(#stash == 1 and stash[1].id == "iron_sword", "the sword goes to the stash")
            assert(itemNamed(victim, "iron_sword") == nil, "and is gone from its owner")
        end,
    },
    {
        name = "an enemy thief with a full grid simply destroys what it took",
        fn = function()
            local victim = Character.instantiate("knight")
            equip(victim, { "iron_sword" })
            local thief = Character.instantiate("bandit")
            equip(thief, { "bow", "chainmail", "torch", "buckler", "trap_sense",
                           "ability_spike_trap", "ability_jolt", "silk_robes", "ability_pickpocket" })

            local c = Combat.new(arena(8, 8), { unit(victim, 2, 2) }, { unit(thief, 3, 2) })
            local stash = {}
            c.stash = stash

            withRandom(1, function() Combat.steal(c, c.units[2], c.units[1]) end)
            assert(#stash == 0, "an enemy thief has no stash to pocket it in")
            assert(itemNamed(victim, "iron_sword") == nil, "the knight has lost it all the same")
        end,
    },
    {
        name = "the pickpocket ability steals through fx.steal and ends the turn",
        fn = function()
            local thief = Character.instantiate("archer")
            equip(thief, { "ability_pickpocket" })
            local victim = Character.instantiate("bandit")
            equip(victim, { "iron_sword" })
            local c = Combat.new(arena(8, 8), { unit(thief, 2, 2) }, { unit(victim, 3, 2) })
            openTurn(c, c.units[1])

            withRandom(1, function()
                assert(Combat.useItem(c, c.units[1], itemNamed(thief, "ability_pickpocket"), 3, 2),
                    "the cast lands on the adjacent foe")
            end)
            assert(itemNamed(thief, "iron_sword") ~= nil, "the sword changed hands")
            assert(c.turn == nil, "and the theft ended the turn")
        end,
    },
    {
        name = "an invisible unit is off the enemy's board entirely",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 3, 2) }, { unit("bandit", 4, 2) })
            local knight, bandit = c.units[1], c.units[2]
            local sword = itemNamed(bandit.char, "iron_sword") or bandit.char.unarmed

            assert(#Combat.abilityTargets(c, bandit, sword) == 1, "the knight is a target")
            Status.apply(c, knight, "invisible")
            assert(#Combat.abilityTargets(c, bandit, sword) == 0, "not once it slips out of sight")

            local plan = Combat.planEnemyAction(c, bandit)
            assert(plan.wait, "and the AI has nothing left to chase (got " .. tostring(plan.item) .. ")")
        end,
    },
    {
        name = "an ally can still support an invisible friend",
        fn = function()
            local priest = Character.instantiate("priest")
            equip(priest, { "ability_heal" })
            local c = Combat.new(arena(8, 8), { unit(priest, 2, 2), unit("knight", 3, 2) },
                { unit("bandit", 8, 8) })
            local cleric, knight = c.units[1], c.units[2]
            Status.apply(c, knight, "invisible")

            local found = false
            for _, t in ipairs(Combat.abilityTargets(c, cleric, itemNamed(priest, "ability_heal"))) do
                if t == knight then found = true end
            end
            assert(found, "a friendly cast ignores invisibility -- only foes lose sight of it")
        end,
    },
    {
        name = "invisibility lifts at the hidden unit's next turn",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 2, 2) }, { unit("bandit", 8, 8) })
            local knight = c.units[1]
            Status.apply(c, knight, "invisible")
            assert(Status.untargetable(knight), "hidden")

            Status.onTurnStart(c, knight)
            assert(not Status.untargetable(knight), "its next turn brings it back into view")
        end,
    },
    {
        name = "Decoy plants an inert double, hides the caster, and logs only a move",
        fn = function()
            local caster = Character.instantiate("archer")
            equip(caster, { "decoy" })
            local c = Combat.new(arena(8, 8), { unit(caster, 2, 2) }, { unit("bandit", 8, 8) })
            local archer = c.units[1]
            openTurn(c, archer)

            assert(Combat.useItem(c, archer, itemNamed(caster, "decoy"), 3, 2), "the double is planted")
            local double = Combat.unitAt(c, 3, 2)
            assert(double and double.decoyOf == archer, "it is tied to the caster")
            assert(double.control == "none", "and it never acts on its own")
            assert(Status.untargetable(archer), "the caster has slipped out of sight")

            -- The log must read as an ordinary step, with no trace of the trick.
            for _, entry in ipairs(c.log) do
                assert(not entry.text:find("Decoy"), "the log never names the item: " .. entry.text)
                assert(not entry.text:find("Invisible"), "nor the concealment: " .. entry.text)
            end
            local last = c.log[#c.log]
            assert(last.kind == "move" and last.text:find("moves to %(3, 2%)"),
                "it reads as a move onto the double's tile, got: " .. last.text)
        end,
    },
    {
        name = "destroying the double reveals the caster and corrects the log it faked",
        fn = function()
            local caster = Character.instantiate("archer")
            equip(caster, { "decoy" })
            local c = Combat.new(arena(8, 8), { unit(caster, 2, 2) }, { unit("bandit", 8, 8) })
            local archer = c.units[1]
            openTurn(c, archer)
            assert(Combat.useItem(c, archer, itemNamed(caster, "decoy"), 3, 2), "the double is planted")

            local double = Combat.unitAt(c, 3, 2)
            local faked = double.decoyLogEntry
            assert(faked and faked.text:find("moves to %(3, 2%)"), "the log was told a lie")
            assert(Status.untargetable(archer), "hidden behind the double")

            Combat.dealFlatDamage(c, double, 1, { "physical" })
            assert(not double.alive, "one hit destroys it")
            assert(not Status.untargetable(archer), "and the caster is revealed")

            -- The very entry that reported a move now reports the truth, in the same place.
            assert(faked.text:find("never moved to %(3, 2%)"),
                "the faked move is corrected in place, got: " .. faked.text)
            assert(faked.text:find("decoy"), "and it names the deception")

            local texts = {}
            for _, e in ipairs(c.log) do texts[#texts + 1] = e.text end
            local joined = table.concat(texts, "\n")
            assert(joined:find("decoy is destroyed"), "the destruction is logged")
            assert(joined:find("is revealed!"), "so is the reveal")
            assert(not joined:find("Archer is defeated"),
                "and the decoy's death never reads as the archer's")
        end,
    },
    {
        name = "a decoy dismissed with its dying caster still sets the record straight",
        fn = function()
            local caster = Character.instantiate("archer")
            equip(caster, { "decoy" })
            local c = Combat.new(arena(8, 8), { unit(caster, 2, 2) }, { unit("bandit", 8, 8) })
            local archer = c.units[1]
            openTurn(c, archer)
            Combat.useItem(c, archer, itemNamed(caster, "decoy"), 3, 2)
            local double = Combat.unitAt(c, 3, 2)
            local faked = double.decoyLogEntry

            Combat.dealFlatDamage(c, archer, 9999, { "physical" })
            assert(not double.alive, "the double vanishes with the archer")
            assert(faked.text:find("never moved"), "and the lie it told is corrected all the same")
        end,
    },
}
