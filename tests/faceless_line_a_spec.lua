-- Tests for THE FACELESS OF ENVY, SLICE A (2026-10-03, "Envy's Bestiary", round 2): the bodies that take faces
-- rather than being dealt them, and the four drops that lend the trick to a person.
--
--   Faceless            the line soldier: a hand of 3, in threes                       -> Borrowed Face (ninja)
--   Faceless Assassin   its hand is its kills; disguised until it strikes; first blow
--                       out of any face crits; a downed companion is worn at once and
--                       the save remembers it                                          -> Hall of Faces (assassin)
--   Skin-Thief          its hit Halts one of the company 2 turns and it wears that face
--                       for the same 2; the face comes back on expiry or its death     -> Flaying Knife (thief)
--   Faceless Champion   its hand is the rift's champions, each opened as it is worn    -> Mask of Champions (duelist)
--
-- The race underneath (A Thousand Faces, Reshape) is pinned in tests/faceless_race_spec.lua.

local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Character = require("models.character")
local Transform = require("models.transform")
local Trait = require("models.trait")
local Encounter = require("models.encounter")
local Faces = require("models.faces")
local SF = require("models.stolen_faces")
local Fixture = require("tests.support.fixture")

local unit = Fixture.unit

local function board() return Fixture.new(9, 9) end

local function sides(c)
    local party, enemy = {}, {}
    for _, u in ipairs(c.units) do
        if u.side == "enemy" then enemy[#enemy + 1] = u else party[#party + 1] = u end
    end
    return party, enemy
end

local function hasItem(char, id)
    for _, item in ipairs(Character.eachItem(char)) do if item.id == id then return item end end
    return nil
end

-- A plain company body for a Faceless to stand against.
local function companion(x, y, hp)
    return unit("character_archer", x, y, { isolate = "bare", items = { "weapon_iron_dagger" },
        stats = { health = hp or 100 } })
end

-- Run `fn` with Player.active standing in for a save whose roster is `roster`, and put the real one back.
local function withRoster(roster, fn)
    local Player = require("models.player")
    local was = Player.active
    Player.active = { roster = roster }
    local ok, err = pcall(fn, Player.active)
    Player.active = was
    if not ok then error(err, 0) end
end

local BODIES = {
    character_faceless = { tier = 2, drop = "ability_borrowed_face", class = "ninja", type = "ability" },
    character_faceless_assassin = { tier = 3, drop = "utility_hall_of_faces", class = "assassin", type = "utility" },
    character_skin_thief = { tier = 3, drop = "weapon_flaying_knife", class = "thief", type = "weapon" },
    character_faceless_champion = { tier = 3, drop = "utility_mask_of_champions", class = "duelist", type = "utility" },
}

local FIGHTS = {
    encounter_envy_three_strangers = true,
    encounter_envy_the_one_who_has_not_acted = true,
    encounter_envy_your_own_face = true,
}

return {
    {
        name = "the four bodies are Faceless of the seat, and each drops its approved piece off a real shelf",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.race == Faces.RACE and def.kind == "humanoid", id .. " is a Faceless")
                assert(def.tier == want.tier, id .. " is tier " .. want.tier)
                assert(def.drops and def.drops[1] == want.drop, id .. " drops " .. want.drop)
                local drop = Item.defs[want.drop]
                assert(drop and drop.class == want.class and drop.type == want.type,
                    want.drop .. " is a " .. want.class .. " " .. want.type)
                assert(drop.unstocked and drop.unlockLevel == 12, want.drop .. " is an unstocked trophy on the seat's rung")
            end
            assert(Character.defs.character_faceless.faceHandSize == 3, "the line soldier carries a hand of 3")
            local knife = Item.defs.weapon_flaying_knife
            local tags = {}
            for _, t in ipairs(knife.tags) do tags[t] = true end
            assert(tags.dagger and knife.activeAbility.speed <= 2, "the Flaying Knife is a quick dagger")
        end,
    },
    {
        name = "three ordinary fights on the seat's rung, each its own set of bodies, the soldiers in threes",
        fn = function()
            for id in pairs(FIGHTS) do
                local def = Encounter.defs[id]
                assert(def, id .. " exists")
                assert(def.kind == "combat" and def.rung == 2, id .. " is ordinary traffic on the seat")
                assert(def.weight >= 2 and def.weight <= 5, id .. " weighs 2-5")
                assert(def.condition({ biome = "desert" }) and not def.condition({ biome = "volcanic" }),
                    id .. " stands on Envy's ground only")
            end
            local list = Encounter.defs.encounter_envy_three_strangers.composition({ depth = 12, rung = 2 })
            local n = 0
            for _, id in ipairs(list) do if id == "character_faceless" then n = n + 1 end end
            assert(n >= 3, "the squad comes in threes")
        end,
    },
    {
        name = "the line soldier opens wearing one of the three faces it was dealt",
        fn = function()
            local c = Fixture.combat(board(), companion(4, 6), { unit("character_faceless", 4, 4) })
            local _, enemy = sides(c)
            local f = enemy[1]
            assert(#f.faceHand == 3, "a hand of three")
            assert(Transform.isTransformed(f), "and is already wearing one")
        end,
    },
    {
        name = "the Assassin walks in wearing a common face, held in it, its hand only its kills",
        fn = function()
            withRoster({}, function()
                local c = Fixture.combat(board(), companion(4, 7), { unit("character_faceless_assassin", 4, 4) })
                local _, enemy = sides(c)
                local a = enemy[1]
                assert(#a.faceHand == 0, "nothing killed, nothing remembered: an empty hand")
                assert(a.faceWorn == "character_glass_mote", "it wears a glass-thing, got " .. tostring(a.faceWorn))
                assert(a.faceLocked, "and stands in it among the pack until it strikes")
                assert(hasItem(a.char, "utility_a_face_for_every_kill"), "its rule rides into the disguise")
                Faces.reshape(c, a)
                assert(a.faceWorn == "character_glass_mote", "its own read does not take the disguise off")
            end)
        end,
    },
    {
        name = "the Assassin's first blow out of any face is a critical, and a landed blow spends it for that face",
        fn = function()
            withRoster({}, function()
                local c = Fixture.combat(board(), companion(4, 5, 400), { unit("character_faceless_assassin", 4, 4) })
                local party, enemy = sides(c)
                local a, p = enemy[1], party[1]
                Fixture.openTurn(c, a)
                local weapon = Combat.defaultAction(a.char, a)
                assert(Combat.forcesCrit(c, a, p, weapon), "the first blow out of the disguise is certain")
                Fixture.strike(c, a, p, weapon)
                assert(not a.faceLocked, "struck: it has shown itself")
                Fixture.openTurn(c, a)
                assert(not Combat.forcesCrit(c, a, p, Combat.defaultAction(a.char, a)),
                    "the same face does not crit twice")
                a.faceHand = { "character_glass_eater" }
                Faces.wear(c, a, "character_glass_eater")
                Fixture.openTurn(c, a)
                assert(Combat.forcesCrit(c, a, p, Combat.defaultAction(a.char, a)), "a new face is a new critical")
            end)
        end,
    },
    {
        name = "one of the company downed by the Assassin is worn at once, kit and all, and the save remembers it",
        fn = function()
            local victimChar = Character.instantiate("character_archer")
            victimChar.name = "Saber"
            withRoster({ victimChar }, function(player)
                local c = Fixture.combat(board(), unit(victimChar, 4, 5, { stats = { health = 20 } }),
                    { unit("character_faceless_assassin", 4, 4) })
                local party, enemy = sides(c)
                local a, p = enemy[1], party[1]
                Combat.dealFlatDamage(c, p, 999, { "physical" }, nil, a)
                assert(not p.alive, "the companion is down")
                assert(a.char.name == "Saber", "and the Assassin is wearing her, got " .. tostring(a.char.name))
                for _, it in ipairs(Character.eachItem(victimChar)) do
                    assert(it.noCopy or hasItem(a.char, it.id), "her kit came with the face: " .. it.id)
                end
                assert(type(a.faceHand[1]) == "table", "her face is in its hand")
                local keeper = "character_faceless_assassin"
                assert(player.facesTaken and player.facesTaken[keeper][1] == victimChar.id,
                    "the save holds her roster id under the Assassin's blueprint")

                -- THE NEXT TRIP: a fresh Assassin holds her face before it has killed anybody.
                local c2 = Fixture.combat(board(), companion(4, 7), { unit("character_faceless_assassin", 4, 4) })
                local _, enemy2 = sides(c2)
                local a2 = enemy2[1]
                assert(#a2.faceHand == 1 and a2.faceHand[1].name == "Saber", "a companion it downed is still in its hand")
            end)
        end,
    },
    {
        name = "what the Assassin remembers survives a save and a load",
        fn = function()
            local Save = require("models.save")
            local Player = require("models.player")
            local p = Player.new()
            p.facesTaken = { character_faceless_assassin = { "character_avatar" } }
            local back = Save.restore(Save.snapshot(p))
            assert(back.facesTaken and back.facesTaken.character_faceless_assassin[1] == "character_avatar",
                "the ledger round-trips")
            local bare = Save.restore(Save.snapshot(Player.new()))
            assert(bare.facesTaken == nil, "an untouched save carries nothing")
        end,
    },
    {
        name = "the Skin-Thief's hit Halts its victim 2 turns and it wears that face for exactly as long",
        fn = function()
            local c = Fixture.combat(board(), companion(4, 5), { unit("character_skin_thief", 4, 4) })
            local party, enemy = sides(c)
            local t, p = enemy[1], party[1]
            p.char.name = "Kaya"
            Combat.dealFlatDamage(c, p, 5, { "physical" }, nil, t)
            local halt = Status.get(p, "status_halted")
            local face = Status.get(t, SF.STATUS)
            assert(halt, "the victim is Halted")
            assert(halt.remaining <= 2 * Status.TICKS_PER_TURN, "for up to 2 turns")
            assert(face and face.remaining == halt.remaining, "the stolen face lasts exactly as long as the Halt")
            assert(t.char.name == "Kaya", "the thief wears her face")
            assert(hasItem(t.char, "weapon_iron_dagger"), "and her kit")
            assert(hasItem(t.char, "utility_the_flaying"), "and is still the Skin-Thief underneath")
            Combat.dealFlatDamage(c, p, 5, { "physical" }, nil, t)
            assert(Status.get(t, SF.STATUS) == face, "one face at a time")
            Status.remove(c, t, SF.STATUS)
            assert(t.char.name ~= "Kaya", "the time ends: the face comes back")
            assert(not Status.has(p, "status_halted"), "and the victim may act again")
        end,
    },
    {
        name = "the Skin-Thief's death gives the face back",
        fn = function()
            local c = Fixture.combat(board(), companion(4, 5), { unit("character_skin_thief", 4, 4) })
            local party, enemy = sides(c)
            local t, p = enemy[1], party[1]
            Combat.dealFlatDamage(c, p, 5, { "physical" }, nil, t)
            assert(Status.has(p, "status_halted"), "flayed")
            Combat.dealFlatDamage(c, t, 9999, { "physical" }, nil, p)
            assert(not t.alive, "the thief is dead")
            assert(not Status.has(p, "status_halted"), "and the victim's Halt lifts with it")
        end,
    },
    {
        name = "the Champion's hand is the rift's champions that may be faces, the human-raced Duelist excepted",
        fn = function()
            local c = Fixture.combat(board(), companion(4, 6), { unit("character_faceless_champion", 4, 4) })
            local _, enemy = sides(c)
            local ch = enemy[1]
            local want = {
                character_elf_bladedancer = true, character_orc_pit_fighter = true,
                character_oni_swordmaster = true, character_asura_adept = true,
            }
            assert(#ch.faceHand == 4, "four champions, got " .. #ch.faceHand)
            for _, id in ipairs(ch.faceHand) do assert(want[id], id .. " is one of the rift's champions") end
            assert(not Faces.isEligible("character_vampire_duelist"), "the Vampire Duelist is human-raced: never a face")
            assert(want[ch.faceWorn], "it opens wearing one of them")
        end,
    },
    {
        name = "a champion's face is worn with its signature rule, and opens as it would have at the bell",
        fn = function()
            local c = Fixture.combat(board(), companion(4, 6), { unit("character_faceless_champion", 4, 4) })
            local _, enemy = sides(c)
            local ch = enemy[1]
            Faces.wear(c, ch, "character_orc_pit_fighter")
            assert(hasItem(ch.char, "utility_the_blood_ring"), "the Pit-Fighter's Challenge rides its face")
            Faces.wear(c, ch, "character_elf_bladedancer")
            assert(Trait.flag(ch, "untouchable"), "the Bladedancer's face carries Untouchable")
            assert(Status.has(ch, "status_unblemished"), "and is Unblemished as it is put on")
            Faces.wear(c, ch, "character_oni_swordmaster")
            assert(not Status.has(ch, "status_unblemished"), "what the last face opened comes off with it")
            assert(hasItem(ch.char, "utility_the_rifts_champions"), "and its own rule rides every face")
        end,
    },
    {
        name = "Borrowed Face: refused with nothing killed, then once a fight the last foe killed, for 3 turns",
        fn = function()
            local hero = unit("character_archer", 4, 4, { isolate = "bare",
                items = { "weapon_iron_dagger", "ability_borrowed_face" }, stats = { health = 77 } })
            local f1 = unit("character_glass_eater", 4, 5, { stats = { health = 5 } })
            local f2 = unit("character_glass_mote", 6, 6, { stats = { health = 50 } })
            local c = Fixture.combat(board(), hero, { f1, f2 })
            local party, enemy = sides(c)
            local h = party[1]
            local item = Fixture.itemNamed(h.char, "ability_borrowed_face")
            local block = Combat.itemBlockReason(h, item)
            assert(block and block.kind == "empty", "nothing killed: nothing to wear")
            local eater
            for _, e in ipairs(enemy) do if e.char.id == "character_glass_eater" then eater = e end end
            Combat.dealFlatDamage(c, eater, 999, { "physical" }, nil, h)
            assert(Combat.itemBlockReason(h, item) == nil, "a kill banks a face")
            local pool = h.char.stats.health
            Fixture.openTurn(c, h)
            Combat.useItem(c, h, item, h.x, h.y)
            assert(h.char.id == "character_glass_eater", "it becomes the last foe it killed")
            local st = Status.get(h, SF.STATUS)
            assert(st and st.remaining == 3 * Status.TICKS_PER_TURN, "for 3 turns")
            assert(h.char.stats.health == pool, "its health stays its own")
            Status.remove(c, h, SF.STATUS)
            assert(hasItem(h.char, "ability_borrowed_face"), "the face comes off")
            local again = Combat.itemBlockReason(h, item)
            assert(again and again.kind == "cooldown", "once a fight")
        end,
    },
    {
        name = "Hall of Faces: every kill is a face, and each one consumed is 2 turns in that body",
        fn = function()
            local hero = unit("character_archer", 4, 4, { isolate = "bare",
                items = { "weapon_iron_dagger", "utility_hall_of_faces" }, stats = { health = 77 } })
            local f1 = unit("character_glass_eater", 4, 5, { stats = { health = 5 } })
            local f2 = unit("character_glass_mote", 6, 6, { stats = { health = 5 } })
            local f3 = unit("character_glass_mote", 7, 7, { stats = { health = 50 } })
            local c = Fixture.combat(board(), hero, { f1, f2, f3 })
            local party, enemy = sides(c)
            local h = party[1]
            local item = Fixture.itemNamed(h.char, "utility_hall_of_faces")
            assert(SF.hallCount(h) == 0, "an empty hall")
            Combat.dealFlatDamage(c, enemy[1], 999, { "physical" }, nil, h)
            Combat.dealFlatDamage(c, enemy[2], 999, { "physical" }, nil, h)
            assert(SF.hallCount(h) == 2, "two kills, two faces")
            Fixture.openTurn(c, h)
            Combat.useItem(c, h, item, h.x, h.y)
            assert(h.char.id == enemy[2].char.id, "it wears the newest face")
            local st = Status.get(h, SF.STATUS)
            assert(st and st.remaining == 2 * Status.TICKS_PER_TURN, "for 2 turns")
            assert(SF.hallCount(h) == 1, "and that face is consumed")
        end,
    },
    {
        name = "Flaying Knife: a hit inflicts Bleed and Halts 1 turn, and lends one of the target's abilities this turn",
        fn = function()
            local hero = unit("character_archer", 4, 4, { isolate = "bare",
                items = { "weapon_flaying_knife" }, stats = { health = 77, stamina = 50 } })
            local foe = unit("character_oni_shadow", 4, 5, { stats = { health = 300 } })
            local c = Fixture.combat(board(), hero, { foe })
            local party, enemy = sides(c)
            local h, e = party[1], enemy[1]
            Fixture.strike(c, h, e, "weapon_flaying_knife")
            assert(Status.has(e, "status_bleed"), "daggers bleed")
            local halt = Status.get(e, "status_halted")
            assert(halt and halt.remaining <= Status.TICKS_PER_TURN, "Halted for up to 1 turn")
            local loan
            for _, it in ipairs(Character.eachItem(h.char)) do if it.flayed then loan = it end end
            assert(loan and loan.onLoan and loan.type == "ability", "one of its abilities, on loan")
            assert(c.turn and c.turn.unit == h, "and the turn is still open to cast it")
            Trait.onAnyTurnEnd(c, h)
            for _, it in ipairs(Character.eachItem(h.char)) do assert(not it.flayed, "the loan goes back at turn's end") end
        end,
    },
    {
        name = "Mask of Champions: it opens Untouchable, and the swap walks the Challenge and Answers Every Blow",
        fn = function()
            local hero = unit("character_archer", 4, 4, { isolate = "bare",
                items = { "weapon_iron_dagger", "utility_mask_of_champions" }, stats = { health = 77 } })
            local small = unit("character_glass_mote", 4, 5, { stats = { health = 20 } })
            local big = unit("character_glass_eater", 6, 6, { stats = { health = 200 } })
            local c = Fixture.combat(board(), hero, { small, big })
            local party, enemy = sides(c)
            local h = party[1]
            local mote = enemy[1].char.id == "character_glass_mote" and enemy[1] or enemy[2]
            local eater = mote == enemy[1] and enemy[2] or enemy[1]
            assert(Status.has(h, "status_untouchable"), "it opens wearing Untouchable")
            Combat.FORCE_HIT = false
            local w = Combat.defaultAction(mote.char, mote)
            assert(Combat.rollsToHit(c, mote, h, w), "the mote's blow asks the dice")
            assert(Combat.hitChance(c, mote, h, w) == 0, "an attack that rolls to hit is evaded")
            Combat.FORCE_HIT = true
            local item = Fixture.itemNamed(h.char, "utility_mask_of_champions")
            Fixture.openTurn(c, h)
            Combat.useItem(c, h, item, h.x, h.y)
            local ch = Status.get(h, "status_the_challenge")
            assert(ch and not Status.has(h, "status_untouchable"), "the swap puts on the Challenge")
            assert(ch.exempt == eater, "the challenger is the foe with the most health")
            local spent = Combat.itemBlockReason(h, item)
            assert(spent and spent.kind == "spent", "once a turn")
            h.freeActionsUsed = nil -- a new turn
            Fixture.openTurn(c, h)
            Combat.useItem(c, h, item, h.x, h.y)
            assert(Status.has(h, "status_answers_every_blow") and not Status.has(h, "status_the_challenge"),
                "and then Answers Every Blow")
            local before = mote.char.stats.health.current
            Combat.dealFlatDamage(c, h, 5, { "physical" }, nil, mote)
            assert(mote.char.stats.health.current < before, "a melee blow is answered")
            h.untouchableMarred = true
            h.freeActionsUsed = nil
            Fixture.openTurn(c, h)
            Combat.useItem(c, h, item, h.x, h.y)
            assert(Status.has(h, "status_the_challenge"), "a marred Untouchable is skipped")
        end,
    },
}
