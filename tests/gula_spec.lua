-- GULA, THE APEX: the Gluttony general's fight, re-premised on review 2026-09-23 ("think Kirby"). She eats
-- a body and takes the one thing it is known for (models/palate.lua); the huntress holds one and a hard
-- blow knocks it out of her; the beast she turns into keeps everything and grows what it eats twice; every
-- blow teaches her its kind; and her stair is a wave battle won on her body. Each rule is held here by the
-- behaviour it promises, against the real blueprints. Headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Item = require("models.item")
local Palate = require("models.palate")
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

-- A glade with one party body and Gula, plus whatever of her own side the case wants beside her.
local function glade(extraEnemies, partyId)
    local enemies = { { char = Character.instantiate("character_general_gluttony"), x = 4, y = 4 } }
    for _, e in ipairs(extraEnemies or {}) do
        enemies[#enemies + 1] = { char = Character.instantiate(e.id), x = e.x, y = e.y }
    end
    local c = Combat.new(arena(9, 9),
        { { char = Character.instantiate(partyId or "character_bandit"), x = 1, y = 1 } }, enemies)
    return c, c.units[2], c.units[1]
end

local function holds(unit, id)
    for _, item in ipairs(Character.eachItem(unit.char)) do
        if item.id == id then return item end
    end
    return nil
end

-- The menu, by name: the thing each beast of the wood gives up when she eats it.
local MENU = {
    character_wolf_grunt   = "weapon_wolf_fangs",
    character_wolf_alpha   = "ability_howl_lesser",
    character_boar         = "ability_gore",
    character_bear         = "utility_the_same_wound",
    character_stag_beast   = "weapon_stag_antlers",
    character_giant_spider = "ability_silk_shot",
    character_manticore    = "ability_tail_volley",
    character_wyvern       = "ability_take_wing",
    character_wyvern_alpha = "ability_take_wing",
}

return {
    {
        name = "the menu: every beast of the wood names a power that loads and is its own kit",
        fn = function()
            for id, want in pairs(MENU) do
                local def = Character.defs[id]
                assert(def, id .. " does not exist")
                assert(def.palate == want, id .. " gives up " .. tostring(def.palate) .. ", expected " .. want)
                assert(Item.defs[want], id .. "'s power " .. want .. " does not load")
                local own = false
                for _, s in ipairs(def.startingItems or {}) do if s == want then own = true end end
                assert(own, id .. "'s power is not in its own kit: it must be the thing the body is known for")
            end
            -- Every palate named anywhere loads, so a new body with a typo is caught on arrival.
            for id, def in pairs(Character.defs) do
                if def.palate then assert(Item.defs[def.palate], id .. " names a palate that does not load") end
            end
        end,
    },
    {
        name = "Devour eats her own side alive and takes its power into her grid",
        fn = function()
            local c, gula = glade({ { id = "character_wolf_grunt", x = 5, y = 4 } })
            local wolf = c.units[3]
            local hurt = gula.char.stats.health
            hurt.current = hurt.max - 60
            local before = hurt.current

            local Devour = Item.instantiate("ability_devour")
            local pick = Palate.edibleNear(c, gula)
            assert(pick[1] == wolf, "her own wolf, beside her, is on the menu")
            Combat.useItem(c, gula, Devour, gula.x, gula.y)

            assert(not wolf.alive and wolf.devoured, "the wolf is eaten, not merely killed")
            assert(not wolf.corpse, "it leaves no corpse to raise")
            assert(holds(gula, "weapon_wolf_fangs"), "she takes the wolf's fangs")
            assert(hurt.current > before, "a meal heals her")
            assert(Status.has(gula, "status_gorged"), "and leaves her Gorged, the gain the planner can see")
        end,
    },
    {
        name = "the huntress holds one power: a new meal replaces the old",
        fn = function()
            local c, gula = glade({ { id = "character_wolf_grunt", x = 5, y = 4 },
                                    { id = "character_boar", x = 3, y = 4 } })
            local wolf, boar = c.units[3], c.units[4]
            assert(Combat.devour(c, gula, wolf), "she eats the wolf")
            assert(holds(gula, "weapon_wolf_fangs"), "the fangs are hers")
            assert(Combat.devour(c, gula, boar), "then the boar")
            assert(holds(gula, "ability_gore"), "Gore is hers now")
            assert(not holds(gula, "weapon_wolf_fangs"), "and the fangs are gone -- nothing in her keeps things")
            assert(#gula.palate == 1, "one power at a time")
        end,
    },
    {
        name = "the Knock: a heavy blow or a crit makes the huntress lose her power",
        fn = function()
            local c, gula = glade({ { id = "character_giant_spider", x = 5, y = 4 } })
            assert(Combat.devour(c, gula, c.units[3]), "she eats the spider")
            assert(holds(gula, "ability_silk_shot"), "and holds Silk Shot")
            -- A scratch does nothing.
            Combat.dealFlatDamage(c, gula, 14, { "physical" }, "test")
            assert(holds(gula, "ability_silk_shot"), "a light blow does not knock it loose")
            -- A blow of 12% of her ceiling does.
            Combat.dealFlatDamage(c, gula, 60, { "physical" }, "test")
            assert(not holds(gula, "ability_silk_shot"), "a heavy blow knocks the power out of her")
            assert(#gula.palate == 0, "and she holds nothing")
        end,
    },
    {
        name = "at half health she turns into the beast, and keeps what she was holding",
        fn = function()
            local c, gula = glade({ { id = "character_manticore", x = 5, y = 4 } })
            assert(Combat.devour(c, gula, c.units[3]), "she eats the manticore")
            local hp = gula.char.stats.health
            hp.current = math.floor(hp.max / 2) + 1
            Combat.dealFlatDamage(c, gula, 2, {}, "test")
            assert(gula.char.id == "character_gula_the_apex", "she turned")
            assert(holds(gula, "ability_tail_volley"), "the beast still holds what the huntress ate")
            assert(holds(gula, "ability_the_breath"), "and draws breath")
        end,
    },
    {
        name = "the beast keeps everything, grows a power it eats twice, and cannot be knocked",
        fn = function()
            local c, gula = glade({ { id = "character_wolf_grunt", x = 5, y = 4 },
                                    { id = "character_wolf_grunt", x = 3, y = 4 },
                                    { id = "character_boar", x = 4, y = 5 } })
            require("models.transform").apply(c, gula, "character_gula_the_apex")
            assert(Combat.devour(c, gula, c.units[3]), "the first wolf")
            local fangs = holds(gula, "weapon_wolf_fangs")
            assert(fangs and fangs.level == 0, "fangs at base")
            assert(Combat.devour(c, gula, c.units[5]), "the boar")
            assert(Combat.devour(c, gula, c.units[4]), "the second wolf")
            fangs = holds(gula, "weapon_wolf_fangs")
            assert(fangs and fangs.level == 1, "a kind it already holds grows a forge level")
            assert(holds(gula, "ability_gore"), "and it kept the boar's Gore beside it")
            assert(not Palate.knock(c, gula), "nothing knocks the beast's powers out")
            assert(holds(gula, "ability_gore"), "Gore survives a knock attempt")
        end,
    },
    {
        name = "Studied: each hit teaches her its kind, and the last lesson is dropped for the next",
        fn = function()
            local c, gula = glade()
            Combat.dealFlatDamage(c, gula, 5, { "slash", "physical" }, "test")
            assert(Status.has(gula, "status_resistant_slash"), "a sword teaches her swords")
            Combat.dealFlatDamage(c, gula, 5, { "pierce", "physical" }, "test")
            assert(Status.has(gula, "status_resistant_pierce"), "an arrow teaches her arrows")
            assert(not Status.has(gula, "status_resistant_slash"), "and she forgets the sword: one lesson at a time")
            Combat.dealFlatDamage(c, gula, 5, { "wind" }, "test")
            assert(Status.has(gula, "status_resistant_wind"), "wind is a lesson too (the ninth element's ward)")
        end,
    },
    {
        name = "a living FOE is eaten only through the Breath's door, beaten, and never a boss",
        fn = function()
            local c, gula, foe = glade()
            assert(not Combat.devour(c, gula, foe), "a standing foe is a fight, not a meal")
            local hp = foe.char.stats.health
            hp.current = math.floor(hp.max * 0.5)
            assert(not Combat.devour(c, gula, foe, { weakFoe = 0.3 }), "half-health is not beaten enough")
            hp.current = math.floor(hp.max * 0.2)
            assert(Combat.devour(c, gula, foe, { weakFoe = 0.3 }), "a beaten foe dragged to her mouth is swallowed")
            local c2, gula2 = glade()
            local me = c2.units[1]
            assert(not Combat.devour(c2, me, gula2, { weakFoe = 1 }), "a boss is never eaten")
        end,
    },
    {
        name = "a companion she eats is out of the fight, never out of the roster",
        fn = function()
            local c, gula, hero = glade()
            Combat.dealFlatDamage(c, hero, 999, { "physical" }, "test", gula)
            assert(not hero.alive, "the hero is down")
            assert(Combat.devour(c, gula, hero), "she eats the fallen")
            assert(hero.devoured and not hero.incapacitated and not hero.corpse, "nothing lies on the tile")
            local fallen = Combat.fallenParty(c)
            assert(#fallen == 1 and fallen[1] == hero.char, "a lost fight still wounds them")
            local carried = Combat.reviveFallenParty(c)
            assert(#carried == 1 and carried[1] == hero.char, "a won fight carries them home")
            assert(hero.alive and not hero.devoured, "on their feet, and no longer eaten")
        end,
    },
    {
        name = "only a body that EATS takes a power by eating: a company member swallowing takes nothing",
        fn = function()
            local c, _, hero = glade({ { id = "character_wolf_grunt", x = 2, y = 1 } })
            local wolf = c.units[3]
            wolf.side = "party" -- the company's own, so the ally door is open to the hero
            assert(Combat.devour(c, hero, wolf), "the hero eats it")
            assert(not holds(hero, "weapon_wolf_fangs"), "and takes no power: that is the Maw's job, on a kill")
        end,
    },
    {
        name = "the Maw of the Unfed becomes what its bearer last killed, and is itself again at the bell",
        fn = function()
            local hero = Character.instantiate("character_bandit")
            local maw = Item.instantiate("utility_maw_of_the_unfed")
            assert(Character.addItem(hero, maw), "the bandit carries the Maw")
            local c = Combat.new(arena(9, 9), { { char = hero, x = 1, y = 1 } },
                { { char = Character.instantiate("character_wolf_grunt"), x = 2, y = 1 },
                  { char = Character.instantiate("character_hawk"), x = 5, y = 5 } })
            local me, wolf, hawk = c.units[1], c.units[2], c.units[3]
            local slot = Character.slotIndex(hero, maw)
            Combat.dealFlatDamage(c, wolf, 999, { "physical" }, "test", me)
            local cell = hero.inventory[slot]
            assert(cell and cell.id == "weapon_wolf_fangs", "the Maw's cell holds the wolf's fangs")
            assert(cell.morphOf == maw and cell.ephemeral, "borrowed, with the relic kept behind it")
            Combat.dealFlatDamage(c, hawk, 999, { "physical" }, "test", me)
            assert(hero.inventory[slot] == maw, "a body that gives nothing turns it back into the Maw")
            -- ...and whatever it is wearing, the bell hands the relic back.
            local c2 = Combat.new(arena(9, 9), { { char = hero, x = 1, y = 1 } },
                { { char = Character.instantiate("character_boar"), x = 2, y = 1 } })
            Combat.dealFlatDamage(c2, c2.units[2], 999, { "physical" }, "test", c2.units[1])
            assert(hero.inventory[slot].id == "ability_gore", "it became the boar's Gore")
            Combat.releaseClaims(hero)
            assert(hero.inventory[slot] == maw, "the bell puts the Maw back in its own cell")
        end,
    },
    {
        name = "the Breath drags the band to her, swallows the beaten, and leaves the Rooted where they stand",
        fn = function()
            local c = Combat.new(arena(9, 9),
                { { char = Character.instantiate("character_bandit"), x = 7, y = 4 },
                  { char = Character.instantiate("character_bandit"), x = 6, y = 5 } },
                { { char = Character.instantiate("character_general_gluttony"), x = 3, y = 4 } })
            local weak, rooted, gula = c.units[1], c.units[2], c.units[3]
            require("models.transform").apply(c, gula, "character_gula_the_apex")
            local hp = weak.char.stats.health
            hp.current = math.max(1, math.floor(hp.max * 0.2))
            Status.apply(c, rooted, "status_root")

            -- The wind-up is the telegraph and is held by the turn loop; the effect is what is under test.
            local breath = Item.instantiate("ability_the_breath")
            breath.activeAbility.windup = nil
            Combat.useItem(c, gula, breath, 4, 4)

            assert(not weak.alive and weak.devoured, "the beaten body is dragged in and swallowed whole")
            assert(rooted.x == 6 and rooted.y == 5, "a rooted body is anchored and does not come")
            assert(rooted.alive, "and it is only bitten")
        end,
    },
    {
        name = "her kit is natural and hers, and what she hands over is the Maw, then the two halves of her rule",
        fn = function()
            for _, id in ipairs({ "ability_devour", "ability_the_breath", "weapon_rending_maw",
                                  "utility_the_turning_hunger", "utility_hunters_read" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not load")
                assert(def.class == "creature" and def.noSteal and not def.price,
                    id .. " is natural kit: a creature's, unpriced, and nothing lifts it off her")
            end
            local drops = Descent.DROPS.gluttony.general
            assert(drops[1] == "utility_maw_of_the_unfed", "the Maw never moves off the top")
            assert(drops[2] == "ability_draw_breath" and drops[3] == "armor_studied_hide",
                "then the Breath and the Hide, lifted off her")
            local hide = Item.defs["armor_studied_hide"]
            assert(hide.traits and hide.traits[1] == "trait_studied", "the Hide learns what she learned")
            local maw = Item.defs["utility_maw_of_the_unfed"]
            assert(maw.traits and maw.traits[1] == "trait_palate", "the Maw morphs; it no longer heals")
        end,
    },
    {
        name = "Draw Breath: the company's inhale drags foes in and swallows the beaten, and takes no power",
        fn = function()
            local hero = Character.instantiate("character_bandit")
            local c = Combat.new(arena(9, 9), { { char = hero, x = 2, y = 4 } },
                { { char = Character.instantiate("character_wolf_grunt"), x = 5, y = 4 } })
            local me, wolf = c.units[1], c.units[2]
            local hp = wolf.char.stats.health
            hp.current = math.max(1, math.floor(hp.max * 0.2))
            local draw = Item.instantiate("ability_draw_breath")
            draw.activeAbility.windup = nil
            Combat.useItem(c, me, draw, 3, 4)
            assert(not wolf.alive and wolf.devoured, "the beaten wolf is dragged in and swallowed")
            assert(not holds(me, "weapon_wolf_fangs"), "and the company takes no power by eating")
        end,
    },
    {
        -- A rule the planner never takes is a rule that is not in the game. Asked of the real planner, far
        -- from any foe, with her own wolf beside her: she eats it rather than walking.
        name = "the planner eats: with her own beast beside her and no foe in reach, Gula devours it",
        fn = function()
            local c = Combat.new(arena(12, 9),
                { { char = Character.instantiate("character_bandit"), x = 12, y = 9 } },
                { { char = Character.instantiate("character_general_gluttony"), x = 2, y = 2 },
                  { char = Character.instantiate("character_wolf_grunt"), x = 3, y = 2 } })
            local gula = c.units[2]
            local plan = Combat.planEnemyAction(c, gula)
            assert(plan and plan.item and plan.item.id == "ability_devour",
                "she plans to eat, not to walk: " .. tostring(plan and (plan.reason or (plan.item and plan.item.id))))
        end,
    },
    {
        name = "her stair is a wave battle won on her body; every other stair is a clear",
        fn = function()
            for _, sin in ipairs(Descent.SINS) do
                local win = Descent.stairWin(sin, true)
                if sin.id == "gluttony" then
                    assert(win.type == "assassinate" and win.target == "character_general_gluttony",
                        "Gula's stair is won on Gula")
                    assert(win.waves and #win.waves >= 5, "and the wood keeps walking in")
                    for _, w in ipairs(win.waves) do
                        for _, id in ipairs(w.composition) do
                            assert(Character.defs[id], "a wave names a body that does not exist: " .. id)
                        end
                        assert(w.maxAlive, "every stream tops up rather than floods")
                    end
                    assert(win.waves ~= sin.guardian.waves, "copied, never aliased into Descent.SINS")
                else
                    assert(win.type == "killAll", sin.id .. "'s stair stays a clear")
                end
                assert(Descent.stairWin(sin, false).type == "killAll", sin.id .. "'s minor stair stays a clear")
            end
        end,
    },
}
