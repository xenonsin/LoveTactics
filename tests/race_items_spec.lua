-- THE SIXTEEN RACE ITEMS ("The Rift's Adventurers", slice D, approved 2026-10-09): one item per race-and-class
-- pairing (models/adventurers.lua's RACE_ITEMS), each its own piece behind a hard race gate (Character.canCarry).
-- Each case below pins one approved rule on a bare board, carried by a body of the right race and measured
-- against the same body without the piece; the last two hold the blueprints to the shelf and the gate.
--
-- The adventurer bodies are another slice's; these fixtures are the generic knight with its race set, which is
-- all the gate and every rule here read.

local Adventurers = require("models.adventurers")
local Character = require("models.character")
local Combat = require("models.combat")
local Devotion = require("models.devotion")
local Feud = require("models.feud")
local Hazard = require("models.hazard")
local Item = require("models.item")
local RaceItems = require("models.race_items")
local Status = require("models.status")
local Summon = require("models.summon")
local Trait = require("models.trait")
local Trap = require("models.trap")
local Fixture = require("tests.support.fixture")

local itemNamed, hp = Fixture.itemNamed, Fixture.hp

-- A bare body of `race` at (x, y) carrying `items`, on a deep pool so nothing a case does fells it by accident.
local function body(race, x, y, items, stats)
    local char = Character.instantiate("character_knight")
    char.race = race
    local s = { health = 300, stamina = 200, mana = 200, defense = 0, magicDefense = 0 }
    for k, v in pairs(stats or {}) do s[k] = v end
    return Fixture.unit(char, x, y, { isolate = "bare", items = items or {}, stats = s })
end

-- The live unit wearing `spawn`'s character.
local function live(c, spawn)
    for _, u in ipairs(c.units) do if u.char == spawn.char then return u end end
end

local function board(party, enemies) return Fixture.combat(Fixture.new(10, 10), party, enemies) end

-- Run `fn` with the dice live, for the two rules that are ABOUT the dice (the suite pins FORCE_HIT).
local function withDice(fn)
    local was = Combat.FORCE_HIT
    Combat.FORCE_HIT = false
    local ok, err = pcall(fn)
    Combat.FORCE_HIT = was
    if not ok then error(err, 0) end
end

local function sword(u) return itemNamed(u.char, "weapon_iron_sword") end

return {
    -- 1 ----------------------------------------------------------------------------------- Mountain's Root
    { name = "Mountain's Root: the bearer and an ally beside it cannot be moved or robbed; one further off can", fn = function()
        local bearer = body("dwarf", 3, 3, { "utility_mountains_root" })
        local beside = body("human", 4, 3, { "weapon_iron_sword" })
        local apart = body("human", 7, 7, { "weapon_iron_sword" })
        local thief = body("goblin", 4, 4)
        local c = board({ bearer, beside, apart }, { thief })
        local b, n, a, t = live(c, bearer), live(c, beside), live(c, apart), live(c, thief)
        assert(Status.blocksForcedMove(b), "the bearer can be moved")
        assert(Status.blocksForcedMove(n), "an ally beside the bearer can be moved")
        assert(not Status.blocksForcedMove(a), "an ally three tiles off is held too")
        assert(Combat.steal(c, t, n) == nil and itemNamed(n.char, "weapon_iron_sword"), "the ally beside was robbed")
        assert(Combat.steal(c, t, a) ~= nil, "an ally off the root should be robbable")
        assert(#Combat.strip(c, t, n) == 0, "a strip took something off the ally beside")
    end },

    -- 2 ---------------------------------------------------------------------------------------- Hoardkeeper
    { name = "Hoardkeeper: a heap banks twice its gold, and a Skimmer's Cut lifts nothing off the bearer", fn = function()
        local keeper = body("dwarf", 2, 2, { "utility_hoardkeeper" })
        local plain = body("dwarf", 6, 6)
        local c = board({ keeper, plain }, { body("human", 9, 9) })
        Hazard.place(c, 3, 2, "hazard_coin_heap", { amount = 10 })
        Hazard.place(c, 6, 7, "hazard_coin_heap", { amount = 10 })
        Hazard.onEnter(c, live(c, keeper), 3, 2)
        assert(c.bounty == 20, "the Hoardkeeper banked " .. tostring(c.bounty) .. ", not 20")
        Hazard.onEnter(c, live(c, plain), 6, 7)
        assert(c.bounty == 30, "a plain body should bank the heap once")

        local cutter = body("human", 2, 2, { "armor_cutpurse_coat", "weapon_iron_sword" })
        local hoard = body("dwarf", 2, 3, { "utility_hoardkeeper" })
        local c2 = board(cutter, hoard)
        Fixture.strike(c2, live(c2, cutter), live(c2, hoard), sword(live(c2, cutter)))
        assert((c2.skimmed or 0) == 0, "the skim lifted " .. tostring(c2.skimmed) .. " off a Hoardkeeper")
        local cutter2 = body("human", 2, 2, { "armor_cutpurse_coat", "weapon_iron_sword" })
        local c3 = board(cutter2, body("dwarf", 2, 3))
        Fixture.strike(c3, live(c3, cutter2), c3.units[2], sword(live(c3, cutter2)))
        assert((c3.skimmed or 0) > 0, "the control skim lifted nothing, so the case measures nothing")
    end },

    -- 3 -------------------------------------------------------------------------------------- Flawless Shot
    { name = "Flawless Shot: while Unblemished a bow shot skips the dice and reaches a tile further", fn = function()
        local shot = body("elf", 2, 2, { "weapon_iron_bow", "utility_flawless_shot" })
        local plain = body("elf", 2, 6, { "weapon_iron_bow" })
        local foe = body("human", 6, 2)
        local c = board({ shot, plain }, foe)
        local s, p, f = live(c, shot), live(c, plain), live(c, foe)
        local bowS, bowP = itemNamed(s.char, "weapon_iron_bow"), itemNamed(p.char, "weapon_iron_bow")
        withDice(function()
            assert(Combat.rollsToHit(c, s, f, bowS), "a blemished elf's shot should still roll")
            assert(Combat.abilityRange(c, s, bowS.activeAbility) == Combat.abilityRange(c, p, bowP.activeAbility),
                "Flawless Shot lent reach before the bearer was Unblemished")
            Status.apply(c, s, "status_unblemished", { applier = s })
            Status.apply(c, p, "status_unblemished", { applier = p })
            assert(not Combat.rollsToHit(c, s, f, bowS) and Combat.hitChance(c, s, f, bowS) == 100,
                "an Unblemished Flawless Shot asked the dice")
            assert(Combat.rollsToHit(c, p, f, bowP), "a plain Unblemished elf's shot should still roll")
            assert(Combat.abilityRange(c, s, bowS.activeAbility) == Combat.abilityRange(c, p, bowP.activeAbility) + 1,
                "the bow did not reach a tile further")
        end)
    end },

    -- 4 --------------------------------------------------------------------------------------- Perfect Form
    { name = "Perfect Form: while Unblemished the same-target streak and En Garde build two a blow", fn = function()
        local function streak(items)
            local duelist = body("elf", 2, 2, items)
            local foe = body("human", 2, 3, nil, { health = 999 })
            local c = board(duelist, foe)
            local d, f = live(c, duelist), live(c, foe)
            Status.apply(c, d, "status_unblemished", { applier = d })
            local blade = itemNamed(d.char, "ability_en_garde")
            for _ = 1, 2 do
                Fixture.openTurn(c, d)
                d.actionSpent, d.freeActionsUsed = nil, nil
                assert(Combat.useItem(c, d, blade, f.x, f.y), "En Garde was refused")
            end
            return Combat.tallyCount(d, "repeatStrike"), d.enGardeStacks
        end
        local tally, stacks = streak({ "ability_en_garde", "utility_perfect_form" })
        local tally0, stacks0 = streak({ "ability_en_garde" })
        assert(tally0 == 1 and stacks0 == 2, "the control streak moved " .. tostring(tally0) .. "/" .. tostring(stacks0))
        assert(tally == 2, "Perfect Form banked " .. tostring(tally) .. " repeat strikes, not 2")
        assert(stacks == 3, "Perfect Form's En Garde sits at " .. tostring(stacks) .. ", not 3")
    end },

    -- 5 ---------------------------------------------------------------------------------------- Blood Tally
    { name = "Blood Tally: each Proven reads as a tenth of health spent, and Desperate Strike lands for it", fn = function()
        local function swing(items)
            local orc = body("orc", 2, 2, items)
            local foe = body("human", 2, 3, nil, { health = 999 })
            local c = board(orc, foe)
            local o, f = live(c, orc), live(c, foe)
            for _ = 1, 3 do Status.apply(c, o, "status_proven") end
            local spent = RaceItems.healthSpent(o)
            local before = hp(f)
            Fixture.strike(c, o, f, itemNamed(o.char, "ability_desperate_strike"))
            return spent, before - hp(f)
        end
        local spent, dealt = swing({ "ability_desperate_strike", "utility_blood_tally" })
        local spent0, dealt0 = swing({ "ability_desperate_strike" })
        assert(math.abs(spent - 0.3) < 1e-9, "three Proven read as " .. tostring(spent) .. " spent, not 0.3")
        assert(spent0 == 0, "a full orc without the Tally reads health spent")
        assert(dealt > dealt0, string.format("Desperate Strike landed %d with the Tally, %d without", dealt, dealt0))
    end },

    -- 6 -------------------------------------------------------------------------------------- Trophy Banner
    { name = "Trophy Banner: an ally's kill inside the bearer's banner field makes the bearer Proven", fn = function()
        local warlord = body("orc", 3, 2, { "ability_rally_banner", "utility_trophy_banner" })
        local inside = body("human", 4, 5, { "weapon_iron_sword" })
        local outside = body("human", 8, 8, { "weapon_iron_sword" })
        local foeIn = body("human", 4, 6, nil, { health = 1 })
        local foeOut = body("human", 8, 9, nil, { health = 1 })
        local c = board({ warlord, inside, outside }, { foeIn, foeOut })
        local w = live(c, warlord)
        Fixture.openTurn(c, w)
        local planted, why = Combat.useItem(c, w, itemNamed(w.char, "ability_rally_banner"), 4, 4)
        assert(planted, "the banner was refused: " .. tostring(why))
        local o = live(c, outside)
        Combat.dealDamage(c, o, live(c, foeOut), sword(o))
        assert(not live(c, foeOut).alive, "the outside kill did not land")
        assert(not Status.has(w, "status_proven"), "a kill outside the field made the warlord Proven")
        local i = live(c, inside)
        Combat.dealDamage(c, i, live(c, foeIn), sword(i))
        assert(not live(c, foeIn).alive, "the inside kill did not land")
        assert(Status.has(w, "status_proven"), "a kill inside the banner's field did not make the warlord Proven")
    end },

    -- 7 --------------------------------------------------------------------------------------- Grudge Purse
    { name = "Grudge Purse: the thief's steals from the Feud skip the dice, and nothing else does", fn = function()
        local thief = body("goblin", 2, 2, { "ability_sap", "weapon_iron_sword", "utility_grudge_purse" })
        local plain = body("goblin", 6, 6, { "ability_sap" })
        local feud = body("human", 2, 3)
        local other = body("human", 3, 2)
        local c = board({ thief, plain }, { feud, other })
        local t, p, f, o = live(c, thief), live(c, plain), live(c, feud), live(c, other)
        Feud.mark(c, f, t)
        assert(Feud.isFeudOf(t, f), "the fixture's Feud did not take")
        local sap = itemNamed(t.char, "ability_sap")
        withDice(function()
            assert(not Combat.rollsToHit(c, t, f, sap), "a Sap at the Feud asked the dice")
            assert(Combat.rollsToHit(c, t, o, sap), "a Sap at a foe who is not the Feud skipped the dice")
            assert(Combat.rollsToHit(c, t, f, sword(t)), "a plain sword blow at the Feud skipped the dice")
            assert(Combat.rollsToHit(c, p, f, itemNamed(p.char, "ability_sap")), "a goblin without the Purse skipped them")
        end)
    end },

    -- 8 ---------------------------------------------------------------------------------------- Never Alone
    { name = "Never Alone: a goblin beside its own hidden charge does not Cower", fn = function()
        local function cowers(items)
            local sapper = body("goblin", 2, 2, items)
            local kin = body("goblin", 9, 9, { "utility_blood_feud" })
            local c = board(body("human", 5, 9), { sapper, kin })
            local s = live(c, sapper)
            Trap.place(c, 3, 3, "blast_charge", s.side, { placer = s })
            Status.remove(c, s, "status_cowering")
            Trait.onAnyTurnEnd(c, live(c, kin))
            return Status.has(s, "status_cowering")
        end
        assert(cowers({ "utility_blood_feud" }), "the control goblin did not Cower alone, so the case measures nothing")
        assert(not cowers({ "utility_blood_feud", "utility_never_alone" }), "a goblin beside its own charge Cowered")
    end },

    -- 9 ----------------------------------------------------------------------------------------- Many Hands
    { name = "Many Hands: each of the bearer's traps beside the target counts as a kobold for Pack", fn = function()
        local function pack(items)
            local trapper = body("kobold", 4, 3, items)
            local foe = body("human", 4, 4)
            local c = board(trapper, foe)
            local t, f = live(c, trapper), live(c, foe)
            Trap.place(c, 3, 4, "spike_trap", t.side, { placer = t })
            Trap.place(c, 5, 4, "spike_trap", t.side, { placer = t })
            return Trait.outgoingDamageBonus(c, t, f, sword(t), { "physical" })
        end
        assert(pack({ "utility_underfoot", "weapon_iron_sword" }) == 0, "Pack counted traps without Many Hands")
        local n = pack({ "utility_underfoot", "weapon_iron_sword", "utility_many_hands" })
        assert(n == 4, "two traps beside the target should be +4 under Pack, got " .. tostring(n))
    end },

    -- 10 ---------------------------------------------------------------------------------------- Dragon-Kin
    { name = "Dragon-Kin: the bearer's summoned beast is a dragon on its side, and the Eye opens for it", fn = function()
        local function eye(items)
            local handler = body("kobold", 3, 3, items)
            local c = board(handler, body("human", 9, 9))
            local h = live(c, handler)
            local wolf = Summon.spawn(c, h, "character_wolf_grunt", 4, 3)
            return Devotion.isDragon(wolf), Trait.liveBonus(h, "damage")
        end
        local dragon0, bonus0 = eye({ "utility_underfoot" })
        assert(not dragon0 and bonus0 == 0, "a plain kobold's wolf is a dragon")
        local dragon, bonus = eye({ "utility_underfoot", "utility_dragon_kin" })
        assert(dragon, "a Dragon-Kin's wolf is not a dragon")
        assert(bonus == 2, "the Dragon's Eye should lend +2 Damage, got " .. tostring(bonus))
    end },

    -- 11 ----------------------------------------------------------------------------------------- Constrict
    { name = "Constrict: a blow on a Poisoned foe Roots it, and on a clean one does not", fn = function()
        local knight = body("naga", 2, 2, { "weapon_iron_sword", "utility_constrict" })
        local sick = body("human", 2, 3)
        local well = body("human", 3, 2)
        local c = board(knight, { sick, well })
        local k, s, w = live(c, knight), live(c, sick), live(c, well)
        Status.apply(c, s, "status_poison", { applier = k })
        Combat.dealDamage(c, k, s, sword(k))
        Combat.dealDamage(c, k, w, sword(k))
        assert(Status.has(s, "status_root"), "the Poisoned foe was not Rooted")
        assert(not Status.has(w, "status_root"), "a foe with no Poison was Rooted")
    end },

    -- 12 ----------------------------------------------------------------------------------------- Shed Skin
    { name = "Shed Skin: once a fight, below half, every status sheds and a fifth of health comes back", fn = function()
        local naga = body("naga", 2, 2, { "utility_shed_skin" }, { health = 100 })
        local foe = body("human", 2, 3)
        local c = board(naga, foe)
        local n, f = live(c, naga), live(c, foe)
        Status.apply(c, n, "status_poison", { applier = f })
        Status.apply(c, n, "status_blessing", { applier = n })
        Combat.dealFlatDamage(c, n, 40, { "physical" }, "test", f, { raw = true })
        assert(Status.has(n, "status_poison"), "the skin shed above half health")
        Combat.dealFlatDamage(c, n, 20, { "physical" }, "test", f, { raw = true })
        assert(#(n.statuses or {}) == 0, "a status survived the shed")
        assert(hp(n) == 60, "40 health plus a fifth of 100 should leave 60, got " .. hp(n))
        Status.apply(c, n, "status_poison", { applier = f })
        Combat.dealFlatDamage(c, n, 30, { "physical" }, "test", f, { raw = true })
        assert(Status.has(n, "status_poison"), "the skin shed a second time in one fight")
    end },

    -- 13 --------------------------------------------------------------------------------------- Horned Fist
    { name = "Horned Fist: Horn Out fills the chi bank", fn = function()
        local monk = body("oni", 2, 2, { "utility_horned_fist" })
        local plain = body("oni", 6, 6)
        local c = board({ monk, plain }, body("human", 9, 9))
        local m, p = live(c, monk), live(c, plain)
        assert(Combat.chi(m) == 0, "the bank started with chi in it")
        Status.apply(c, m, "status_horn_out", { applier = m })
        Status.apply(c, p, "status_horn_out", { applier = p })
        assert(Combat.chi(m) == Combat.CHI_MAX, "Horn Out left the bank at " .. Combat.chi(m))
        assert(Combat.chi(p) == 0, "an oni without the Fist banked chi from its horn")
    end },

    -- 14 ------------------------------------------------------------------------------------------ Red Mark
    { name = "Red Mark: a blink that finishes a foe sends the bearer Horn Out; a blink that does not, does not", fn = function()
        local function finish(foeHealth)
            local assassin = body("oni", 5, 5, { "ability_shadow_strike", "utility_red_mark" })
            local foe = body("human", 5, 6, nil, { health = foeHealth })
            local c = board(assassin, foe)
            local a, f = live(c, assassin), live(c, foe)
            c.turn = { unit = a, moved = true, moveCost = 0, startX = 2, startY = 2 }
            assert(Combat.useItem(c, a, itemNamed(a.char, "ability_shadow_strike"), f.x, f.y), "the strike was refused")
            assert(a.x == 2 and a.y == 2, "Shadow Strike did not blink home")
            return f.alive, Status.has(a, "status_horn_out")
        end
        local alive, horn = finish(1)
        assert(not alive and horn, "a blink that finished a foe did not bring the horn out")
        alive, horn = finish(999)
        assert(alive and not horn, "a blink that killed nothing brought the horn out")
    end },

    -- 15 -------------------------------------------------------------------------------------- Sworn Shield
    { name = "Sworn Shield: a blow the bearer's guard takes for an ally Blesses the ally", fn = function()
        local function guarded(items)
            local knight = body("human", 3, 3, items)
            local ward = body("human", 4, 3)
            local foe = body("orc", 5, 3, { "weapon_iron_sword" })
            local c = board({ knight, ward }, foe)
            local k, w, f = live(c, knight), live(c, ward), live(c, foe)
            local before = hp(k)
            Combat.dealDamage(c, f, w, sword(f))
            assert(hp(k) < before, "the guard did not take the blow, so the case measures nothing")
            return Status.has(w, "status_blessing")
        end
        assert(not guarded({ "armor_wardens_oath" }), "a guard without the Sworn Shield Blessed its ward")
        assert(guarded({ "armor_wardens_oath", "utility_sworn_shield" }), "the ally was not Blessed")
    end },

    -- 16 -------------------------------------------------------------------------------------- Well Stocked
    { name = "Well Stocked: the first use of each consumable in a fight leaves its stack alone", fn = function()
        local function uses(items)
            local alch = body("human", 2, 2, items)
            local c = board(alch, body("human", 9, 9))
            local a = live(c, alch)
            a.char.stats.health.current = 100
            local potion = itemNamed(a.char, "consumable_healing_potion")
            potion.quantity = 2
            Combat.quaff(c, a, potion)
            local afterFirst = potion.quantity
            Combat.quaff(c, a, potion)
            return afterFirst, potion.quantity
        end
        local a0, b0 = uses({ "consumable_healing_potion" })
        assert(a0 == 1 and b0 == 0, "the control flask spent " .. a0 .. "/" .. b0)
        local a1, b1 = uses({ "consumable_healing_potion", "utility_well_stocked" })
        assert(a1 == 2 and b1 == 1, string.format("Well Stocked left %d then %d, not 2 then 1", a1, b1))
    end },

    -- the shelf and the gate ---------------------------------------------------------------------------------
    { name = "every race item is a priceless rift find on its pairing's shelf at the class's own floor", fn = function()
        local n = 0
        for race, byClass in pairs(Adventurers.RACE_ITEMS) do
            for class, id in pairs(byClass) do
                n = n + 1
                local def = Item.defs[id]
                assert(def, "missing race item " .. id)
                assert(def.race == race and def.class == class, id .. " sits on the wrong shelf or race")
                assert(def.type == "utility" and def.price == nil and not def.unstocked, id .. " is not a passive find")
                assert(def.unlockLevel == Adventurers.floorOf(class),
                    string.format("%s opens at %s, %s's floor is %d", id, tostring(def.unlockLevel), class,
                        Adventurers.floorOf(class)))
                assert(#def.description <= 120 and def.flavor, id .. " breaks the text contract")
                for _, t in ipairs(def.traits or {}) do
                    assert(Trait.defs[t], id .. " names an unknown trait " .. t)
                end
            end
        end
        assert(n == 16, "expected 16 race items, found " .. n)
        -- Named here as strings so the coverage ratchet sees each one (tests/item_coverage_spec.lua).
        for _, id in ipairs({ "utility_mountains_root", "utility_hoardkeeper", "utility_flawless_shot",
            "utility_perfect_form", "utility_blood_tally", "utility_trophy_banner", "utility_grudge_purse",
            "utility_never_alone", "utility_many_hands", "utility_dragon_kin", "utility_constrict", "utility_shed_skin",
            "utility_horned_fist", "utility_red_mark", "utility_sworn_shield", "utility_well_stocked" }) do
            assert(Item.defs[id], id .. " is named here and does not exist")
        end
    end },

    { name = "each race item refuses a body of every other race, and its own race carries it", fn = function()
        for race, byClass in pairs(Adventurers.RACE_ITEMS) do
            for _, id in pairs(byClass) do
                for _, other in ipairs(Adventurers.RACES) do
                    local char = Character.instantiate("character_knight")
                    char.race = other
                    char.inventory = {}
                    local ok = Character.canCarry(char, Item.instantiate(id))
                    assert(ok == (other == race), string.format("%s on a %s: canCarry said %s", id, other, tostring(ok)))
                    assert(Character.addItem(char, Item.instantiate(id)) == (other == race),
                        string.format("addItem landed %s on a %s", id, other))
                end
            end
        end
    end },
}
