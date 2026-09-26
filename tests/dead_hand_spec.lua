-- THE DEAD HAND (Greed's approach, reviewed over three rounds 2026-09-25): Vesh, the Hollow King, on floor
-- five's stair, and the dead of the Deeps -- dwarf and kobold skeletons that kept their class and race, the
-- barrow-wight that is only half here, the ghoul that robs the fallen -- plus the fifteen pieces they drop,
-- each a mechanic rebuilt to work on every floor. Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Trait = require("models.trait")
local Summon = require("models.summon")
local Devotion = require("models.devotion")
local Encounter = require("models.encounter")
local Descent = require("models.descent")

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

-- A body carrying exactly the pieces a case is about.
local function bearer(baseId, items)
    local char = Character.instantiate(baseId)
    char.inventory = {}
    for _, id in ipairs(items) do Character.addItem(char, Item.instantiate(id)) end
    return char
end

local function itemOf(u, id)
    for _, it in ipairs(Character.eachItem(u.char)) do
        if it.id == id then return it end
    end
    error(id .. " is not in " .. tostring(u.char.id) .. "'s grid")
end

local function hasItem(u, id)
    for _, it in ipairs(Character.eachItem(u.char)) do
        if it.id == id then return it end
    end
    return nil
end

local function openTurn(c, u) c.turn = { unit = u, moved = false, moveCost = 0 } end
local function mana(u) return u.char.stats.mana.current end
local function fell(c, u) Combat.dealFlatDamage(c, u, 9999, {}, "test") end

local function sinById(id)
    for _, s in ipairs(Descent.SINS) do if s.id == id then return s end end
end

-- The suite pins the dice (tests/runner.lua); Half Here is a statement about the dice.
local function withDice(fn)
    local was = Combat.FORCE_HIT
    Combat.FORCE_HIT = false
    local ok, err = pcall(fn)
    Combat.FORCE_HIT = was
    if not ok then error(err, 0) end
end

return {
    -- -----------------------------------------------------------------------
    -- The skeletons: the living blueprints, dead
    -- -----------------------------------------------------------------------
    { name = "a Dwarf Skeleton is still a dwarf and a fighter, and it has lost the want", fn = function()
        local c = Combat.new(arena(6, 6), { unit("character_knight", 1, 1) },
            { unit("character_dwarf_skeleton", 4, 4), unit("character_dwarf_delver", 5, 5) })
        local dead, living = c.units[2], c.units[3]
        assert(dead.char.race == "dwarf" and dead.char.class == "fighter", "race and class kept")
        assert(Character.isUndead(dead.char), "and tagged undead")
        assert(Trait.flag(dead, "wardsTheft"), "Stout's body stays: it cannot be robbed")
        assert(not Trait.flag(dead, "seeksHeaps"), "Stout's want is gone: it walks past loose gold")
        assert(Trait.flag(living, "seeksHeaps"), "a living dwarf still goes for the gold")
        assert(hasItem(dead, "ability_delve") and hasItem(dead, "utility_bare_bones"), "Delve, and the bone")
        assert(dead.resist.impact < 0 and dead.resist.slash > 0, "the lattice: a hammer, not a blade")
    end },

    { name = "a dead kobold kneels to a lich, and a living one does not", fn = function()
        local c = Combat.new(arena(8, 8), { unit("character_knight", 8, 8) },
            { unit("character_vesh", 3, 3), unit("character_kobold_skeleton", 4, 3),
              unit("character_kobold_skulker", 3, 4) })
        local vesh, dead, living = c.units[2], c.units[3], c.units[4]
        assert(Devotion.nearestDragon(c, dead) == vesh, "the dead kobold's god is Vesh")
        assert(Devotion.nearestDragon(c, living) == nil, "the living kobold has no god here")
        assert(dead.char.class == "fighter" and hasItem(dead, "utility_scurry"), "the skulker's kit, kept")
    end },

    -- -----------------------------------------------------------------------
    -- The Barrow-Wight
    -- -----------------------------------------------------------------------
    { name = "Half Here: a weapon blow has half its chance; a spell and a lit wight have all of it", fn = function()
        withDice(function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 3, 3) },
                { unit("character_barrow_wight", 4, 3) })
            local knight, wight = c.units[1], c.units[2]
            local sword = itemOf(knight, "weapon_iron_sword")
            local halved = Combat.hitChance(c, knight, wight, sword)
            Status.apply(c, wight, "status_limned")
            local lit = Combat.hitChance(c, knight, wight, sword)
            assert(lit > 0 and halved == math.floor(lit / 2), "halved " .. halved .. " of " .. lit)
            assert(not Combat.halfHere(c, wight, Item.instantiate("ability_fireball")), "a spell is not a weapon")
        end)
    end },

    { name = "the Skull-Lantern Limns foes within 2, which ends Half Here", fn = function()
        local c = Combat.new(arena(8, 8), { unit(bearer("character_knight",
                { "weapon_iron_sword", "utility_skull_lantern" }), 3, 3) },
            { unit("character_barrow_wight", 5, 3), unit("character_barrow_wight", 8, 8) })
        local knight, near, far = c.units[1], c.units[2], c.units[3]
        assert(Status.lanternLit(c, near) and not Status.lanternLit(c, far), "lit within 2, not beyond")
        assert(not Combat.halfHere(c, near, itemOf(knight, "weapon_iron_sword")), "the lit wight is all here")
        assert(Combat.halfHere(c, far, itemOf(knight, "weapon_iron_sword")), "the dark one is not")
    end },

    { name = "a wight drifts through rock and bodies", fn = function()
        local c = Combat.new(arena(6, 6), { unit("character_knight", 1, 1) },
            { unit("character_barrow_wight", 4, 4) })
        local wight = c.units[2]
        assert(hasItem(wight, "utility_wight_body"), "the Barrow-Shade is what it is")
        assert(Combat.isFlying(wight) and Combat.isPhasing(wight), "the ground and the line both open")
    end },

    { name = "the wight's touch puts a foe to Sleep", fn = function()
        local c = Combat.new(arena(6, 6), { unit("character_knight", 3, 3) },
            { unit("character_barrow_wight", 4, 3) })
        local knight, wight = c.units[1], c.units[2]
        openTurn(c, wight)
        assert(Combat.useItem(c, wight, itemOf(wight, "ability_wight_touch"), 3, 3), "the touch lands")
        assert(Status.has(knight, "status_sleep"), "and the knight sleeps")
    end },

    -- -----------------------------------------------------------------------
    -- The Ghoul
    -- -----------------------------------------------------------------------
    { name = "ghoul claws: a small Stun, and a hard one on a critical", fn = function()
        local c = Combat.new(arena(6, 6), { unit("character_knight", 3, 3) },
            { unit("character_ghoul", 4, 3) })
        local knight, ghoul = c.units[1], c.units[2]
        assert(hasItem(ghoul, "weapon_ghoul_claws"), "the ghoul's claws")
        local rider = { id = "status_stun", magnitude = 2, critMagnitude = 8 }
        local before = knight.initiative
        Combat.dealFlatDamage(c, knight, 1, { "physical" }, nil, ghoul, { inflicts = rider })
        assert(knight.initiative == before + 2, "an ordinary hit shoves 2: " .. (knight.initiative - before))
        before = knight.initiative
        Combat.dealFlatDamage(c, knight, 1, { "physical" }, nil, ghoul, { inflicts = rider, critical = true })
        assert(knight.initiative == before + 8, "a critical shoves 8: " .. (knight.initiative - before))
    end },

    { name = "Grave-Robber takes a piece off a downed foe as a loan, and the fight gives it back", fn = function()
        local c = Combat.new(arena(6, 6), { unit("character_knight", 3, 3) },
            { unit("character_ghoul", 4, 3) })
        local knight, ghoul = c.units[1], c.units[2]
        fell(c, knight)
        assert(knight.incapacitated, "the knight is down, in its window")
        openTurn(c, ghoul)
        assert(Combat.useItem(c, ghoul, itemOf(ghoul, "ability_grave_rob"), 3, 3), "the ghoul robs the body")
        assert(knight.char.stripped and #knight.char.stripped == 1, "one piece is off the knight")
        local piece = knight.char.stripped[1].item
        assert(piece.onLoan and hasItem(ghoul, piece.id), "and the ghoul wears it, on loan")
        Combat.returnStripped(c)
        assert(hasItem(knight, piece.id), "the fight gives it back")
    end },

    { name = "the ghoul hunts the sleeping first", fn = function()
        local AI = require("models.ai")
        local listed = false
        for _, p in ipairs(AI.TARGET_PREF_ORDER) do if p == "sleeping" then listed = true end end
        assert(listed, "`sleeping` is a preference an author may name")
        local rules = Character.defs.character_ghoul.ai
        assert(rules[1].targetPref == "sleeping", "and the ghoul names it first")
    end },

    -- -----------------------------------------------------------------------
    -- Vesh, the Hollow King
    -- -----------------------------------------------------------------------
    { name = "Vesh is a man, a necromancer, and dead; and he rises whole for 40 mana", fn = function()
        local c = Combat.new(arena(6, 6), { unit("character_knight", 1, 1) }, { unit("character_vesh", 4, 4) })
        local vesh = c.units[2]
        assert(vesh.char.race == "human" and vesh.char.class == "mage", "human, and a mage's shelf")
        assert(Character.isUndead(vesh.char), "tagged undead")
        assert(hasItem(vesh, "utility_the_last_rite"), "The Last Rite holds him up")
        local before = mana(vesh)
        fell(c, vesh)
        assert(vesh.alive and mana(vesh) == before - 40, "refused, for forty")
        assert(vesh.char.stats.health.current == Combat.unreservedMax(vesh.char, "health"), "and whole")
    end },

    { name = "Call the Lured reserves a fifth of his pool, and the aim picks the skeleton", fn = function()
        local c = Combat.new(arena(8, 8), { unit("character_knight", 8, 8) }, { unit("character_vesh", 4, 4) })
        local vesh = c.units[2]
        local call = itemOf(vesh, "ability_call_the_lured")
        local ceiling = Combat.unreservedMax(vesh.char, "mana")
        openTurn(c, vesh)
        assert(Combat.useItem(c, vesh, call, 5, 4), "a call into open ground")
        local called = Combat.unitAt(c, 5, 4)
        assert(called and called.char.id == "character_kobold_skeleton", "open ground calls a kobold")
        assert(Combat.unreservedMax(vesh.char, "mana") == ceiling - math.floor(vesh.char.stats.mana.max * 0.2),
            "and holds a fifth of his pool")
        vesh.cooldowns = nil -- the second aim is the question here, not the cooldown
        vesh.x, vesh.y = 2, 4
        openTurn(c, vesh)
        Combat.useItem(c, vesh, call, 1, 4)
        local wall = Combat.unitAt(c, 1, 4)
        assert(wall and wall.char.id == "character_dwarf_skeleton", "a tile against the rock calls a dwarf")
    end },

    { name = "the Offering: he eats a kobold skeleton beside him for 30 mana", fn = function()
        local c = Combat.new(arena(8, 8), { unit("character_knight", 8, 8) },
            { unit("character_vesh", 4, 4), unit("character_kobold_skeleton", 5, 4) })
        local vesh, kob = c.units[2], c.units[3]
        vesh.char.stats.mana.current = 10
        openTurn(c, vesh)
        assert(Combat.useItem(c, vesh, itemOf(vesh, "ability_the_offering"), 5, 4), "the offering is taken")
        assert(not kob.alive, "the kobold is gone into him")
        assert(mana(vesh) == 40, "and his pool gained thirty: " .. mana(vesh))
    end },

    { name = "Foreclosure: a body it downs rises in bone on his side, standing over itself", fn = function()
        local c = Combat.new(arena(8, 8), { unit("character_knight", 5, 4) }, { unit("character_vesh", 2, 4) })
        local knight, vesh = c.units[1], c.units[2]
        knight.char.stats.health.current = 1
        openTurn(c, vesh)
        assert(Combat.useItem(c, vesh, itemOf(vesh, "ability_foreclosure"), 5, 4), "the wind-up begins")
        assert(Combat.resolveChannel(c, vesh), "and lands")
        assert(knight.incapacitated, "the knight is down, in its ordinary window")
        local bone = Combat.unitAt(c, 5, 4)
        assert(bone and bone.side == vesh.side and bone.summoned, "a copy stands on his side, over the body")
        assert(Character.isUndead(bone.char) and hasItem(bone, "utility_bare_bones"), "and it is bone")
        assert(bone.char.name == knight.char.name, "the body it was")
    end },

    { name = "Grave-Chill Inters, and the Dead Hand takes mana back with it", fn = function()
        local c = Combat.new(arena(8, 8), { unit("character_mage", 5, 4) }, { unit("character_vesh", 2, 4) })
        local mage, vesh = c.units[1], c.units[2]
        vesh.char.stats.mana.current = 50
        local theirs = mana(mage)
        openTurn(c, vesh)
        assert(Combat.useItem(c, vesh, itemOf(vesh, "ability_grave_chill"), 5, 4), "the bolt lands")
        assert(Status.has(mage, "status_interred"), "Interred")
        assert(mana(mage) == theirs - 5, "five mana out of the mage: " .. (theirs - mana(mage)))
        assert(mana(vesh) == 50 - 6 + 5, "and into Vesh, after the bolt's own cost: " .. mana(vesh))
    end },

    -- -----------------------------------------------------------------------
    -- The pieces, each on a floor with none of Greed's ground
    -- -----------------------------------------------------------------------
    { name = "Nerveless Bones: a Stun and a Sleep land and cost no time", fn = function()
        local c = Combat.new(arena(6, 6), { unit(bearer("character_knight",
            { "weapon_iron_sword", "utility_nerveless_bones" }), 3, 3) }, { unit("character_bandit", 5, 5) })
        local knight = c.units[1]
        local before = knight.initiative
        Status.apply(c, knight, "status_stun", { magnitude = 5 })
        assert(Status.has(knight, "status_stun") and knight.initiative == before, "stunned, not delayed")
        assert(Status.initiativeShove(knight, "status_sleep") == 0, "and the preview agrees for Sleep")
    end },

    { name = "the Deep-Delver's Pick crits the first blow after surfacing, and only that one", fn = function()
        local c = Combat.new(arena(8, 8), { unit(bearer("character_knight",
            { "weapon_deep_delvers_pick", "ability_through_the_rock" }), 2, 4) },
            { unit("character_bandit", 6, 4) })
        local u, foe = c.units[1], c.units[2]
        local pick = itemOf(u, "weapon_deep_delvers_pick")
        openTurn(c, u)
        assert(Combat.useItem(c, u, itemOf(u, "ability_through_the_rock"), 5, 4), "through the rock")
        assert(u.x == 5 and Status.has(u, "status_surfaced"), "up beside the bandit, surfaced")
        openTurn(c, u) -- the blow is struck on the bearer's own turn
        assert(Combat.forcesCrit(c, u, foe, pick), "the next blow is a critical")
        Combat.dealDamage(c, u, foe, pick)
        assert(not Status.has(u, "status_surfaced"), "and the landing spends it")
    end },

    { name = "Hollow Helm: no Charm, no Taunt, no Cowering", fn = function()
        local helm = Item.defs.armor_hollow_helm
        local immune = {}
        for _, id in ipairs(helm.statusImmunity) do immune[id] = true end
        assert(immune.status_charm and immune.status_taunt and immune.status_cowering, "all three")
    end },

    { name = "the Ledger of the Lured halves every summon's reservation", fn = function()
        local c = Combat.new(arena(6, 6), { unit(bearer("character_mage",
            { "ability_call_the_lured", "utility_ledger_of_the_lured" }), 3, 3),
            unit(bearer("character_mage", { "ability_call_the_lured" }), 1, 1) }, { unit("character_bandit", 6, 6) })
        local kept, plain = c.units[1], c.units[2]
        local ab = itemOf(plain, "ability_call_the_lured").activeAbility
        assert(Combat.abilityReserve(kept, ab).amount * 2 <= Combat.abilityReserve(plain, ab).amount + 1,
            "half as much, give or take the floor")
    end },

    { name = "Offering Bone eats your own summon for mana and health", fn = function()
        local c = Combat.new(arena(8, 8), { unit(bearer("character_mage", { "ability_offering_bone" }), 3, 3) },
            { unit("character_bandit", 8, 8) })
        local mage = c.units[1]
        local wolf = Summon.spawn(c, mage, "character_kobold_skeleton", 4, 3)
        mage.char.stats.mana.current = 0
        mage.char.stats.health.current = mage.char.stats.health.current - 10
        local hpBefore = mage.char.stats.health.current
        local gift = math.min(30, wolf.char.stats.health.current)
        openTurn(c, mage)
        assert(Combat.useItem(c, mage, itemOf(mage, "ability_offering_bone"), 4, 3), "the offering is taken")
        assert(not wolf.alive, "the summon is gone")
        assert(mana(mage) == gift, "mana by its health: " .. mana(mage))
        assert(mage.char.stats.health.current > hpBefore, "and health")
    end },

    { name = "Raise the Owing stands a corpse up as a skeleton of itself", fn = function()
        local c = Combat.new(arena(8, 8), { unit(bearer("character_mage", { "ability_raise_the_owing" }), 3, 3) },
            { unit("character_bandit", 5, 3) })
        local mage, bandit = c.units[1], c.units[2]
        fell(c, bandit)
        bandit.incapacitated, bandit.corpse = false, true -- its window has closed
        openTurn(c, mage)
        assert(Combat.useItem(c, mage, itemOf(mage, "ability_raise_the_owing"), 5, 3), "the raise lands")
        local bone = Combat.unitAt(c, 5, 3)
        assert(bone and bone.side == mage.side and bone.char.name == bandit.char.name, "the bandit, on our side")
        assert(Character.isUndead(bone.char), "in bone")
    end },

    -- -----------------------------------------------------------------------
    -- Where they stand
    -- -----------------------------------------------------------------------
    { name = "Vesh holds Greed's minor stair with a dwarf at his side, and his dead never escort Avaritia", fn = function()
        local greed = sinById("greed")
        assert(greed.minor.lead == "character_vesh", "the stand-in Slime is gone")
        local list = Descent.guardList(greed, false, 5, 3)
        assert(list[1] == "character_vesh" and list[2] == "character_dwarf_skeleton", "Vesh and his dwarf")
        assert(list[3] == "character_kobold_skeleton" and list[4] == "character_kobold_skeleton", "then kobolds")
        for _, id in ipairs(Descent.guardList(greed, true, 6, 4)) do
            assert(not Character.isUndead(Character.defs[id]), id .. " is dead, at the living dragon's shoulder")
        end
    end },

    { name = "the three fights live on floor five and field only the dead", fn = function()
        for _, id in ipairs({ "encounter_greed_the_ossuary", "encounter_greed_the_barrow",
                              "encounter_greed_the_charnel" }) do
            local enc = Encounter.defs[id]
            assert(enc and enc.rung == 1 and enc.condition({ biome = "cave" }), id .. " is a floor-five cave fight")
            for _, body in ipairs(enc.composition({ depth = 5 })) do
                assert(Character.isUndead(Character.defs[body]), id .. " fields a living " .. body)
            end
        end
    end },

    { name = "every piece they drop is a trophy of its own, sold nowhere", fn = function()
        for _, id in ipairs({ "armor_hollow_helm", "utility_nerveless_bones", "utility_skull_lantern",
            "weapon_deep_delvers_pick", "ability_offering_bone", "utility_wights_shroud",
            "ability_through_the_rock", "ability_barrow_touch", "consumable_ghoul_nail_paste",
            "ability_ghouls_bite", "ability_foreclosure", "ability_raise_the_owing", "utility_the_dead_hand",
            "utility_ledger_of_the_lured", "ability_call_the_lured" }) do
            local def = Item.defs[id]
            assert(def and def.unstocked and not def.price, id .. " is found, never sold")
        end
    end },
}
