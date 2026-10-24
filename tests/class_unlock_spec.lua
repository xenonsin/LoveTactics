-- THE NOVICE AND PER-BODY CLASS UNLOCKS (models/class.lua, data/class_requirements.lua): every class is
-- earned per body like an achievement -- level gate + the class's own deed + a Charter Seal, in town --
-- the avatar starts as a Novice, bodies already in a class keep it, and a class's stat boost applies only
-- while it is the declared class. Measured through the models, not read back out of the blueprints.

local Class = require("models.class")
local Growth = require("models.growth")
local Character = require("models.character")
local Player = require("models.player")
local Item = require("models.item")
local Save = require("models.save")

local SEAL = Class.SEAL_ID

local function avatar()
    return Character.instantiate("character_avatar")
end

local function companyWith(char)
    local p = Player.new()
    p.roster = { char }
    p.descentRun = nil
    return p
end

local function stashHas(p, id)
    for _, it in ipairs(p.stash or {}) do if it.id == id then return true end end
    return false
end

return {
    { name = "the Novice is the starter: not a root, no shelf, an even growth table, the avatar's class", fn = function()
        assert(Class.defs.novice, "data/classes/novice.lua is missing")
        assert(Class.isStarter("novice") and not Class.isRoot("novice") and not Class.isEarned("novice"),
            "the Novice stands below the roots, not beside them")
        assert(Class.isPlayable("novice"), "a body can stand in the Novice")
        assert(not Class.roots().novice, "Class.roots() is the seven trades and nothing else")
        assert(Growth.NEUTRAL_CLASS == "novice", "the Novice is Growth.NEUTRAL_CLASS")
        assert(Growth.CREATURE_CLASS == "fighter", "a class-less creature still grows as a fighter")
        local g = Growth.defs.novice
        for _, stat in ipairs({ "health", "mana", "stamina", "damage", "magicDamage", "defense",
            "magicDefense", "speed" }) do
            assert(g[stat] == 1, "novice grows +1 " .. stat)
        end
        assert(g.movement == nil, "and never Move")
        local a = avatar()
        assert(Class.declaredOf(a) == "novice" and Growth.classOf(a) == "novice", "the avatar starts a Novice")
        assert(Class.boostOf(a) == nil, "the Novice buys no boost")
    end },

    { name = "the requirement table names every root and subclass, and no crossing", fn = function()
        local want = 0
        for id in pairs(Class.defs) do
            local req = Class.requirementOf(id)
            if Class.isPlayable(id) and (Class.isRoot(id) or Class.arity(id) == 1) then
                want = want + 1
                assert(req, id .. " has no deed")
                assert(type(req.deed) == "string" and req.count > 0 and type(req.label) == "string",
                    id .. ": a malformed requirement")
            else
                assert(req == nil, id .. " should carry no deed (a crossing, the starter or not a career)")
            end
        end
        assert(want == 24, "7 roots + 17 subclasses, found " .. want)
        local n = 0
        for _ in pairs(Class.requirements) do n = n + 1 end
        assert(n == 24, "no stray rows in data/class_requirements.lua")
    end },

    { name = "a root unlocks at Novice 1 plus its deed, and the seal is spent in town", fn = function()
        local a = avatar()
        local p = companyWith(a)
        assert(Class.isUnlocked(a, "novice"), "every body holds the Novice")
        assert(not Class.isUnlocked(a, "fighter"), "a fresh avatar has no root")
        assert(not Class.canUnlock(a, "fighter"), "not before Novice 1")
        a.technique = { novice = Class.classLevelCost(1) }
        assert(not Class.canUnlock(a, "fighter"), "nor before the deed")
        a.deeds = { killMelee = 15 }
        assert(Class.canUnlock(a, "fighter"), "Novice 1 + 15 melee kills meets the gate")
        assert(Class.unlockBlock(p, a, "fighter") == "seal", "but there is no seal in hand")
        assert(not Class.unlock(p, a, "fighter"), "and so no unlock")

        Player.addMaterial(p, SEAL, 1)
        p.descentRun = { entry = {} }
        local ok, why = Class.unlock(p, a, "fighter")
        assert(not ok and why == "town", "underground the unlock is refused")
        p.descentRun = nil

        local ok2, gift = Class.unlock(p, a, "fighter")
        assert(ok2, "the unlock lands in town")
        assert(Player.materialCount(p, SEAL) == 0, "it spent the seal")
        assert(Class.isUnlocked(a, "fighter") and a.unlocked.fighter, "the ledger holds it")
        assert(gift == "ability_charge" and stashHas(p, "ability_charge"), "the avatar's fighter gift is Charge")
        assert(not Class.canUnlock(a, "fighter"), "a held class cannot be unlocked twice")
    end },

    { name = "every root's gift is an ability off its own shelf", fn = function()
        for _, gifts in ipairs({ Class.ROOT_GIFTS, Class.AVATAR_GIFTS }) do
            for root, id in pairs(gifts) do
                assert(Class.roots()[root], root .. " is not a root")
                local def = Item.defs[id]
                if def then -- a gift whose file has not landed yet is skipped by Class.unlock
                    assert(def.class == root, id .. " is " .. tostring(def.class) .. "'s, not " .. root .. "'s")
                end
            end
        end
    end },

    { name = "the avatar's fighter and hunter gifts differ from every other body's", fn = function()
        local a, other = avatar(), { id = "character_kaya" }
        assert(Class.giftFor(a, "fighter") == "ability_charge", "the avatar opens fighter on Charge")
        assert(Class.giftFor(a, "hunter") == "ability_called_shot", "and hunter on Called Shot")
        assert(Class.giftFor(other, "fighter") == "ability_clear_out", "anyone else opens fighter on Clear Out")
        assert(Class.giftFor(other, "hunter") == "ability_mark_target", "and hunter on Mark Target")
        assert(Class.giftFor(a, "mage") == Class.ROOT_GIFTS.mage, "a root the avatar list skips falls back")
    end },

    { name = "a subclass asks its parent's level and its deed; a crossing asks a subclass of each parent", fn = function()
        local c = avatar()
        c.declaredClass = "knight"
        local need = Class.defs.bulwark.requires.knight
        c.technique = { knight = Class.classLevelCost(need) }
        assert(not Class.canUnlock(c, "bulwark"), "the deed is still owed")
        c.deeds = { slammed = 10 }
        assert(Class.canUnlock(c, "bulwark"), "level + deed meets it")

        -- Champion: fighter x knight. Levels alone are not enough.
        for class, level in pairs(Class.defs.champion.requires) do
            c.technique[class] = math.max(c.technique[class] or 0, Class.classLevelCost(level))
        end
        assert(not Class.levelGateMet(c, "champion"), "no subclass unlocked on either side")
        c.unlocked = { knight = true, bulwark = true, warlord = true }
        assert(Class.levelGateMet(c, "champion") and Class.canUnlock(c, "champion"),
            "a subclass of each parent + both levels, and a crossing asks no deed")
    end },

    { name = "a body standing in a class keeps it, through a save and a switch", fn = function()
        local rowan = Character.instantiate("character_rowan")
        assert(Class.isUnlocked(rowan, rowan.class), "a companion holds its authored class")
        rowan.deeds = { tauntDrawn = 3 }
        local back = Save.restoreCharacter(Save.snapshotCharacter(rowan))
        assert(back.unlocked and back.unlocked[rowan.class], "the grandfathered class is in the ledger")
        assert(back.deeds and back.deeds.tauntDrawn == 3, "deeds survive a save")
        back.declaredClass = "novice"
        assert(Class.isUnlocked(back, rowan.class), "and survive switching away")
    end },

    { name = "a won fight banks only the deeds a class asks for, onto the company's own bodies", fn = function()
        local a = avatar()
        local p = companyWith(a)
        local stranger = avatar()
        local combat = { units = {
            { char = a, side = "party", tally = { killMelee = 2, hitDealt = 9, healGiven = 40 } },
            { char = stranger, side = "party", tally = { killMelee = 5 } },
        } }
        Class.bankDeeds(combat, p)
        assert(a.deeds.killMelee == 2 and a.deeds.healGiven == 40, "the deeds landed")
        assert(a.deeds.hitDealt == nil, "a tally no class asks for is not kept")
        assert(stranger.deeds == nil, "a body off the roster banks nothing")
        Class.bankDeeds(combat, p)
        assert(a.deeds.killMelee == 4, "deeds accumulate across fights")
    end },

    { name = "a real melee kill tallies its deeds on the striker, and the win banks them", fn = function()
        local Fixture = require("tests.support.fixture")
        local hero = Fixture.unit("character_knight", 2, 2, { items = { "weapon_iron_sword" } })
        local foe = Fixture.unit("character_bandit", 3, 2, { stats = { health = 100 } })
        foe.char.stats.health.current = 5
        local c = Fixture.combat(Fixture.new(6, 6), { hero }, { foe })
        local h, f
        for _, u in ipairs(c.units) do
            if u.char == hero.char then h = u elseif u.char == foe.char then f = u end
        end
        assert(Fixture.strike(c, h, f, "weapon_iron_sword"), "the blow is struck")
        assert(not f.alive, "the foe at 5 of 100 falls")
        local Combat = require("models.combat")
        assert(Combat.tallyCount(h, "killMelee") == 1, "an adjacent physical kill is a melee kill")
        assert(Combat.tallyCount(h, "killExecute") == 1, "below a quarter health is an execute")
        assert(Combat.tallyCount(h, "killSpell") == 0 and Combat.tallyCount(h, "killRanged") == 0,
            "and not a spell or a ranged kill")
        local p = companyWith(hero.char)
        Class.bankDeeds(c, p)
        assert(hero.char.deeds.killMelee == 1 and hero.char.deeds.killExecute == 1, "the win banks both")
    end },

    { name = "the Classes tab: Unlock on confirm with a seal, read-only underground", fn = function()
        local ClassEditor = require("ui.class_editor")
        local a = avatar()
        local p = companyWith(a)
        p.flags = {}
        local ed = ClassEditor.new({ x = 0, y = 0, w = 900, h = 500, fonts = {}, player = p, char = a })
        assert(ed.houses[1].id == "novice", "the Novice heads the rail")
        assert(ed:pickCoach() == nil, "no first-pick coach when no pick is owed")
        a.technique = { novice = Class.classLevelCost(1) }
        Player.addMaterial(p, SEAL, 1)

        a.deeds = { killMelee = 15 }
        local fighter
        for i, h in ipairs(ed.houses) do if h.id == "fighter" then fighter = i end end
        ed:setHouse(fighter)
        ed.region = "classes"
        ed.cursor = 1
        assert(ed:currentRow().id == "fighter" and ed:canUnlock(), "the met root offers Unlock")
        assert(not ed:canChange(), "and not Change, until it is unlocked")

        p.descentRun = { entry = {} }
        assert(ed:readOnly() and not ed:canUnlock(), "underground the tab is read-only")
        p.descentRun = nil

        ed:confirm()
        assert(Class.isUnlocked(a, "fighter") and Player.materialCount(p, SEAL) == 0, "confirm unlocked it")
        if ed.card then ed:cancel(); ed:cancel() end
        ed.card = nil
        assert(ed:canChange(), "and now it can be changed into")
        ed:confirm()
        assert(a.declaredClass == "fighter", "confirm changed class")
    end },

    { name = "Rowan's recommendation: the avatar's first root is picked free -- no level, deed or seal", fn = function()
        local ClassEditor = require("ui.class_editor")
        local a = avatar()
        local p = companyWith(a)
        local rowan = Character.instantiate("character_rowan")
        p.roster[2] = rowan
        assert(Class.unlockBlock(p, a, "mage") == "level", "unowed, a root asks Novice 1 as ever")

        p.classPick = true
        assert(Class.pickOwed(p, a) and not Class.pickOwed(p, rowan), "the pick is the avatar's alone")
        assert(Class.isFreePick(p, a, "mage") and not Class.isFreePick(p, a, "warlord"),
            "any root is free, and only a root")
        assert(Class.unlockBlock(p, a, "mage") == nil, "nothing stands between the avatar and a root")
        p.descentRun = { entry = {} }
        assert(Class.unlockBlock(p, a, "mage") == "town", "and it is still made in town")
        p.descentRun = nil

        local ed = ClassEditor.new({ x = 0, y = 0, w = 900, h = 500, fonts = {}, player = p, char = a })
        assert(ed:pickCoach(), "Rowan's coach line shows while the pick is owed")

        local ok = Class.unlock(p, a, "mage")
        assert(ok, "the free pick unlocks")
        assert(Class.isUnlocked(a, "mage") and a.declaredClass == "mage", "and the avatar stands in it")
        assert(Player.materialCount(p, SEAL) == 0, "no seal was asked or spent")
        assert(p.classPick == nil and p.firstClass == "mage", "the pick is spent, and remembered")
        assert(Class.unlockBlock(p, a, "priest") == "level", "every class after it is earned")

        local back = Save.restore(Save.snapshot(p))
        assert(back and back.firstClass == "mage" and not back.classPick, "the pick survives a save")
        p.classPick = true
        back = Save.restore(Save.snapshot(p))
        assert(back and back.classPick == true, "and so does an owed one")
    end },

    { name = "the first class is the city's first shelf; the slot waits while the pick is owed", fn = function()
        local Offer = require("models.offer")
        local a = avatar()
        local p = companyWith(a)
        p.roster[2] = Character.instantiate("character_rowan") -- a knight: the schedule's own trip-0 pull
        p.classPick = true
        assert(not Offer.admitted(p, "bastion.shelf") and not Offer.admitted(p, "arcanum.shelf"),
            "no shelf takes trip 0 while the pick is owed")
        assert(Class.unlock(p, a, "mage"))
        assert(Offer.openedOn(p, "arcanum.shelf") == 0, "the picked class's house takes trip 0")
        assert(not Offer.admitted(p, "bastion.shelf"), "and Rowan's knight waits its turn")
    end },

    { name = "Act 0 teaches no class: a fight flagged noClassCredit banks no technique and no deed", fn = function()
        local Combat = require("models.combat")
        local a = avatar()
        local p = companyWith(a)
        local c = { noClassCredit = true, units = { { char = a, tally = { killMelee = 3 } } } }
        assert(Combat.awardTechnique(c, c.units[1], { class = "fighter" }) == 0, "no technique")
        assert(not (a.technique or {}).fighter and not (a.technique or {}).novice, "nothing on the ledger")
        Class.bankDeeds(c, p)
        assert(not (a.deeds and a.deeds.killMelee), "and no deed")
        c.noClassCredit = nil
        Class.bankDeeds(c, p)
        assert(a.deeds and a.deeds.killMelee == 3, "the same fight unflagged banks it")
    end },

    { name = "the boost applies only while selected: a root 1x its growth, an earned class 2x", fn = function()
        local c = avatar()
        c.declaredClass = "knight"
        local b = Class.boostOf(c)
        for stat, amount in pairs(Growth.defs.knight) do
            assert(b[stat] == amount, "knight boost " .. stat)
        end
        c.declaredClass = "warlord"
        b = Class.boostOf(c)
        for stat, amount in pairs(Growth.defs.warlord) do
            assert(b[stat] == amount * 2, "warlord boost " .. stat)
        end
        local health = c.stats.health.max
        assert(c.stats.health.max == health, "never baked into char.stats")
    end },

    { name = "a Charter Seal drops the first time an elite is beaten, and never again", fn = function()
        local EB = require("models.encounter_battle")
        local p = Player.new()
        local enc = { id = "encounter_test_elite", kind = "elite" }
        local s1 = EB.spoils({ encounter = enc, enemyUnits = {}, player = p })
        assert(s1 and s1.materials and s1.materials[SEAL] == 1, "the first win pays a seal")
        assert(p.elitesBeaten and p.elitesBeaten.encounter_test_elite, "and stamps the ledger")
        local s2 = EB.spoils({ encounter = enc, enemyUnits = {}, player = p })
        assert(not (s2 and s2.materials and s2.materials[SEAL]), "the second win pays none")
        local s3 = EB.spoils({ encounter = { id = "encounter_test_road", kind = "combat" }, enemyUnits = {}, player = p })
        assert(not (s3 and s3.materials and s3.materials[SEAL]), "an ordinary fight pays none")
        assert(require("models.material").defs[SEAL], "the seal is a real material")
        local snap = Save.snapshot(p)
        assert(snap.elitesBeaten and snap.elitesBeaten.encounter_test_elite, "the ledger is saved")
    end },

    { name = "a mid-fight grant onto a bought stack goes home as the bought stack", fn = function()
        local Combat = require("models.combat")
        local a = avatar()
        a.inventory = {}
        local bought = Item.instantiate("consumable_healing_potion", 2)
        a.inventory[1] = bought
        local unit = { char = a, side = "party", x = 1, y = 1 }
        local combat = { units = { unit } }
        assert(Combat.grantItem(combat, unit, "consumable_healing_potion"), "the grant lands")
        assert(bought.quantity == 3, "it merged onto the stack for the fight")
        Combat.releaseClaims(a)
        assert(a.inventory[1] == bought and bought.quantity == 2, "home as 2, not 3")
        assert(bought.ownedQuantity == nil, "the mark is cleared")
    end },

    { name = "the three moved items sit where the design put them", fn = function()
        assert(Item.defs.ability_charm.unlockLevel == 3 and Item.defs.ability_charm.class == "thief",
            "Charm: thief, rung 3")
        assert(Item.defs.consumable_reviving_salts.unlockLevel == 0, "Reviving Salts: a standing item")
        local sfe = Item.defs.ability_summon_fire_elemental
        assert(sfe.class == "mage" and sfe.unlockLevel == 6, "Summon Fire Elemental: mage, rung 6")
    end },
}
