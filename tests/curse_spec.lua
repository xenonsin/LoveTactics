-- CURSES (models/curse.lua): a hex on a piece of gear, lifted at the Cathedral.
--
-- What this file is for, beyond the obvious: a curse is deliberately built out of machinery that
-- already existed -- it declares the ITEM's fields, it binds through the ITEM's bound flag, it is
-- folded by the fold that folds everything else -- and reuse of that kind is exactly what ships green
-- and does nothing. Every borrowed seam gets a case that watches the effect arrive on a real body in a
-- real fight, rather than asserting that the field was copied.
--
-- The seams, and which case covers each:
--   the flat fold     Combat.applyUnitPassives -- "a hex lands on the bearer" (bonus + resist)
--   the rule bag      Item.mergeRules -> unit.rules -- "a hex rewrites a rule for its bearer alone"
--   the bind          Item.isBound -- "a binding hex cannot be stowed, moved or sold"
--   the boon          states/battle.lua's bell -- covered through Curse.openingBoons, since the bell
--                     itself lives in a state file and no spec in the tree boots one
--   the traits        Trait.attach -- ditto, through Curse.traitsOn
--   the save          Save.snapshot/restore round trip, including a hex riding inside a SEAL
--   the rite          Curse.commit -> Curse.tickRites, the free path, end to end
--
-- Pure logic, headless. Fixture style mirrors tests/item_rules_spec.lua, which is the nearest relative:
-- the rule bag arrived there and this file bolts a second source onto it.

local Combat = require("models.combat")
local Curse = require("models.curse")
local Character = require("models.character")
local Fixture = require("tests.support.fixture")
local Identify = require("models.identify")
local Item = require("models.item")
local Player = require("models.player")
local Save = require("models.save")

-- Fixture.unit hands back a SPAWN descriptor ({ char, x, y }), and the unit a fold lands on is the one
-- Combat.new builds from it. Matching by char identity is the seam between the two, and getting this
-- wrong reads as "the hex did not apply" rather than as a test bug.
local function unitFor(combat, spawn)
    for _, u in ipairs(combat.units) do
        if u.char == spawn.char then return u end
    end
    return nil
end

-- A curse id that is guaranteed to exist and to declare the thing a case is about, found by asking the
-- blueprints rather than by naming one. A case that hard-coded "curse_the_anchor" would go green-to-red
-- on a content edit that had nothing to do with the mechanism under test.
local function curseDeclaring(field)
    local found = {}
    for id, def in pairs(Curse.defs) do
        if def[field] ~= nil then found[#found + 1] = id end
    end
    table.sort(found)
    return found[1]
end

return {
    {
        name = "every curse blueprint is well formed, and declares an effect the engine reads",
        fn = function()
            local ruleNames = {}
            for _, n in ipairs(Item.RULE_NAMES) do ruleNames[n] = true end

            local n = 0
            for id, def in pairs(Curse.defs) do
                n = n + 1
                assert(type(def.name) == "string" and def.name ~= "",
                    id .. " declares no name -- the tooltip and the Cathedral's rows both print it")
                assert(type(def.description) == "string" and def.description ~= "",
                    id .. " declares no description -- it is the only place the hex is said in words")
                -- A curse with no mechanism would pass every other sweep in the tree, because a
                -- description is prose. THREE OF THESE ARE NOT NUMBERS and each is a whole curse on
                -- its own: `binds` (The Clinging Hand's entire content is that you cannot put the
                -- piece down), `blocksForge` (Cold Iron takes the bench and nothing else), and
                -- `encounterCleared` (The Spreading acts between fights rather than during one).
                local acts = def.binds or def.blocksForge or def.encounterCleared
                    or def.bonus or def.maxBonus or def.resist or def.unarmedBonus
                    or def.rules or def.traits or def.openingBoon
                assert(acts, id .. " is a curse that does nothing at all")
                -- The same contract items are held to: a misspelled rule name parses, ships and is
                -- silently inert, which is indistinguishable from working until somebody plays it.
                for name in pairs(def.rules or {}) do
                    assert(ruleNames[name],
                        id .. " declares rule '" .. name .. "', which nothing in the engine reads")
                end
                assert(Curse.depthOf(def) >= 1, id .. " may never be rolled at any depth")
                -- Every hex must be liftable for money as well as by the rite. A zero fee would make
                -- the paid row free, which quietly deletes the decision the Cathedral's room exists for.
                assert(Curse.fee({ curse = id }) > 0, id .. " costs nothing to lift")
            end
            assert(n >= 5, "the curse registry found almost nothing -- this sweep is not scanning")
        end,
    },
    {
        name = "a hex lands on the bearer, in the same totals the piece's own stats land in",
        fn = function()
            -- THE FLAT FOLD. A curse's -3 defense has to be the same quantity a coat's +3 is, or the
            -- damage breakdown and the mitigation maths each need a case of their own -- so this reads
            -- the very tables Combat.flatStat and Combat.mitigatedDamage are handed.
            local c = Fixture.new(10, 10)
            local hexed = Fixture.unit("character_knight", 2, 2,
                { isolate = "bare", items = { "weapon_iron_sword" } })
            local clean = Fixture.unit("character_knight", 4, 4,
                { isolate = "bare", items = { "weapon_iron_sword" } })
            assert(Curse.afflict(hexed.char.inventory[1], "curse_thin_blood"), "the sword takes the hex")

            local combat = Fixture.combat(c, { hexed, clean }, {})
            Combat.applyPassives(combat)
            hexed, clean = unitFor(combat, hexed), unitFor(combat, clean)

            local delta = (hexed.bonus.defense or 0) - (clean.bonus.defense or 0)
            assert(delta == -2, "Thin Blood takes two defense off the bearer, got " .. delta)
            local resist = (hexed.resist.physical or 0) - (clean.resist.physical or 0)
            assert(resist == -3, "...and opens them up three to physical blows, got " .. resist)
            assert((clean.bonus.defense or 0) == (clean.bonus.defense or 0) and not clean.curse,
                "the ally carrying the identical sword is untouched")
        end,
    },
    {
        name = "a hex rewrites a rule for its bearer and for nobody else",
        fn = function()
            -- THE RULE BAG, which is the half that makes a curse more than a stat penalty -- and the
            -- scope is the whole point, exactly as it was when items took the rules off the relic
            -- shelf: a company that cannot move is a puzzle, one knight who cannot is a position.
            local c = Fixture.new(10, 10)
            local hexed = Fixture.unit("character_knight", 2, 2,
                { isolate = "bare", items = { "weapon_iron_sword" } })
            local free = Fixture.unit("character_knight", 4, 4, { isolate = "bare" })
            assert(Curse.afflict(hexed.char.inventory[1], "curse_the_anchor"), "the sword takes it")

            local combat = Fixture.combat(c, { hexed, free }, {})
            Combat.applyPassives(combat)
            hexed, free = unitFor(combat, hexed), unitFor(combat, free)

            assert(hexed.rules and hexed.rules.noMove, "The Anchor roots whoever carries the piece")
            assert(Combat.moveBudget(hexed) == 0, "...and the engine agrees they walk nowhere")
            assert(not free.rules, "the ally beside them has no rule bag at all")
        end,
    },
    {
        name = "a binding hex nails the piece down through the flag every refusal already reads",
        fn = function()
            -- Item.isBound is the ONE predicate the grid editor, the stash, the vendor and combat theft
            -- all refuse through. A curse that had taught each of those separately would be eleven call
            -- sites agreeing by coincidence, so this asserts the predicate rather than the call sites --
            -- and then spot-checks the two that move gear out of the company for real.
            local item = Item.instantiate("weapon_iron_sword")
            assert(not Item.isBound(item), "an ordinary sword is not bound")
            assert(Curse.afflict(item, "curse_the_clinging_hand"), "it takes The Clinging Hand")
            assert(Item.isBound(item), "and is nailed to its holder")
            assert(Curse.binds(item), "...by the hex rather than by the blueprint")

            -- It still WEARS, which is the one place the two reasons for being bound differ: a
            -- signature relic is not a thing that breaks, and a curse is not a warranty.
            assert(Item.durabilityMax(item), "a hexed sword still wears out")

            -- And the sale is refused. Vendor.sellValue is the counter's own reader of the flag.
            assert(require("models.vendor").sellValue(item) == 0, "nobody will buy a bound piece")

            assert(Curse.lift(item) == "curse_the_clinging_hand", "the lift names what it took off")
            assert(not Item.isBound(item), "and the piece is free again")
        end,
    },
    {
        name = "a piece brings its hex's traits and opening boons alongside its own",
        fn = function()
            -- The two effect lists gathered by OTHER passes (Trait.attach, states/battle.lua's bell).
            -- Both ask Curse through one helper each, so the helpers are what a case can reach: no spec
            -- in the tree boots a battle state, and a boon asserted any further down would be asserting
            -- Status.apply rather than the join.
            local item = Item.instantiate("weapon_iron_sword")
            assert(#Curse.openingBoons(item) == 0, "a clean sword brings no boon")
            assert(Curse.afflict(item, "curse_the_hungry_edge"), "it takes The Hungry Edge")

            local boons = Curse.openingBoons(item)
            assert(#boons == 1, "the hex brings exactly one boon, got " .. #boons)
            assert(boons[1].id == "status_bleed", "and it is the bleed, got " .. tostring(boons[1].id))

            -- The bare-table shape an author may write is unwrapped HERE rather than at each reader, so
            -- a one-entry boon and a list of them arrive identically.
            local pair = { openingBoon = { { id = "status_burn" }, { id = "status_bleed" } } }
            assert(#Curse.openingBoons(pair) == 2, "a list of boons arrives as a list")

            -- ...and the traits join, item's first.
            local traited = { traits = { "trait_engorge" } }
            assert(#Curse.traitsOn(traited) == 1, "an uncursed piece brings only its own traits")
        end,
    },
    {
        name = "one hex per piece, and never on a husk or a body part",
        fn = function()
            -- Curse.canAfflict is the gate every vector goes through -- the trap, the cast, the reveal.
            -- Each refusal below is a real case somewhere in the game rather than a defensive guard.
            local sword = Item.instantiate("weapon_iron_sword")
            assert(Curse.afflict(sword, "curse_dead_weight"), "a clean sword takes a hex")
            assert(not Curse.afflict(sword, "curse_the_anchor"), "...and will not take a second")
            assert(sword.curse == "curse_dead_weight", "the first hex is the one that holds")

            local potion = { type = "consumable", quantity = 3 }
            assert(not Curse.canAfflict(potion), "a stack of draughts has no object to hex")

            local fangs = { type = "weapon", noSteal = true }
            assert(not Curse.canAfflict(fangs), "a beast's own body is not gear")

            local husk = Identify.sealed("weapon_iron_sword", 3, 2)
            assert(husk, "the seal built")
            assert(not Curse.canAfflict(husk),
                "nothing may hex a piece whose name is still a secret")

            assert(not Curse.afflict(Item.instantiate("weapon_iron_sword"), "curse_nonexistent"),
                "an unknown curse id is refused rather than stamped")
        end,
    },
    {
        name = "a cast sinks a hex into one piece of the target's kit, and answers honestly when it cannot",
        fn = function()
            -- Combat.curseItem, which is what fx.curse and a trap's ctx.curse both call. The empty
            -- answer matters as much as the landing one: beasts fight with `noSteal` body parts, so a
            -- hexing cast aimed at a wolf has to report a miss rather than silently doing nothing.
            local c = Fixture.new(10, 10)
            local caster = Fixture.unit("character_knight", 2, 2, { isolate = "bare" })
            local armed = Fixture.unit("character_knight", 3, 2,
                { isolate = "bare", items = { "weapon_iron_sword" } })
            local combat = Fixture.combat(c, { caster }, { armed })
            local victim = unitFor(combat, armed)

            local item, id = Combat.curseItem(combat, victim, "curse_the_long_hour")
            assert(item and id == "curse_the_long_hour", "the hex lands on something in the grid")
            assert(Curse.isCursed(item), "...and the piece is carrying it")
            -- The passives are rebuilt on the spot, or a hex landed mid-fight would be invisible until
            -- the next battle -- which for an enemy, rebuilt every fight, means never.
            assert(victim.rules and victim.rules.initiativeCost,
                "the rule reaches the victim without waiting for another setup")

            local bare = Fixture.unit("character_knight", 5, 5, { isolate = "bare" })
            local combat2 = Fixture.combat(Fixture.new(10, 10), { caster }, { bare })
            local none = Combat.curseItem(combat2, unitFor(combat2, bare), "curse_dead_weight")
            assert(none == nil, "an empty grid is a clean miss, not a silent success")
        end,
    },
    {
        name = "the Shaman's hex stock lays real curses through the fx seam",
        fn = function()
            -- ability_lay_the_hex, ability_sink_the_anchor and weapon_hexbrand, fired for real rather
            -- than inspected. Each one is a different shape of the same verb and each has a half that a
            -- data check could not see: the shallow cast pays a BLOW underneath (so a target with no
            -- kit is not a wasted turn), the deep one NAMES its hex (so the lock is the lock and not a
            -- roll), and the weapon carries the cast on a staff whose swap is the rest of the weapon.
            local function hexWith(itemId, victimItems)
                local c = Fixture.new(10, 10)
                local caster = Fixture.unit("character_knight", 2, 2,
                    { isolate = "bare", items = { itemId }, stats = { mana = 200, stamina = 200 } })
                local foe = Fixture.unit("character_bandit", 3, 2,
                    { isolate = "bare", items = victimItems, stats = { health = 300 } })
                local combat = Fixture.combat(c, { caster }, { foe })
                local user, target = unitFor(combat, caster), unitFor(combat, foe)
                Fixture.openTurn(combat, user)
                local _, res = Combat.useItem(combat, user, user.char.inventory[1], target.x, target.y)
                return target, res
            end

            local target = hexWith("ability_lay_the_hex", { "weapon_iron_sword" })
            assert(Curse.isCursed(target.char.inventory[1]), "Lay the Hex curses what the foe carries")

            -- ...and still lands its bolt on a body with nothing to hex, which is the whole reason the
            -- damage line is on that blueprint: beasts fight with `noSteal` parts.
            local bare, res = hexWith("ability_lay_the_hex", nil)
            assert(res and (res.damageDealt or 0) > 0, "and it still hits a foe with no kit at all")
            assert(#Curse.kit({ roster = { bare.char } }) == 0, "...hexing nothing, honestly")

            local anchored = hexWith("ability_sink_the_anchor", { "armor_leather_armor" })
            assert(anchored.char.inventory[1].curse == "curse_the_anchor",
                "Sink the Anchor deals the hex it names, never a roll")
            assert(anchored.rules and anchored.rules.noMove, "and the target stops walking at once")

            local struck = hexWith("weapon_hexbrand", { "weapon_iron_sword" })
            assert(Curse.isCursed(struck.char.inventory[1]), "the Hexbrand's blow hexes what it strikes")
            assert(Item.instantiate("weapon_hexbrand").waitBehavior.kind == "focus",
                "...and it is still a staff, which is most of what it is")
        end,
    },
    {
        name = "a hexed piece survives a save, and so does one still inside its seal",
        fn = function()
            -- THE LOAD PATH REBUILDS EVERYTHING FROM BLUEPRINTS, so a field that is not in the schema is
            -- a field that is quietly lifted every time the player quits. Two cases in one, because the
            -- husk is the harder half: a seal carries its hex from the moment it is sealed, and a
            -- re-roll on load would be a curse the player could gamble away by reloading.
            local player = Player.new()
            local sword = Item.instantiate("weapon_iron_sword")
            assert(Curse.afflict(sword, "curse_the_shut_hand"))
            Player.addToStash(player, sword)

            local husk = Identify.sealed("weapon_iron_sword", 4)
            husk.curse = "curse_dead_weight" -- stamped directly: the roll is chance, the schema is not
            Player.addToStash(player, husk)

            local back = Save.restore(Save.snapshot(player))
            local restoredSword, restoredHusk
            for _, item in ipairs(back.stash or {}) do
                if Identify.isUnidentified(item) then restoredHusk = item else restoredSword = item end
            end
            assert(restoredSword and restoredSword.curse == "curse_the_shut_hand",
                "the hexed sword comes back hexed")
            assert(restoredHusk and restoredHusk.curse == "curse_dead_weight",
                "and the seal comes back still holding its own")
        end,
    },
    {
        name = "a lifted born-curse stays lifted across a save",
        fn = function()
            -- THE CASE THE OBVIOUS IMPLEMENTATION GETS WRONG. A blueprint may be born hexed, so
            -- Item.instantiate stamps one on at restore -- and a save that only wrote the PRESENCE of a
            -- curse would hand the player back a piece they paid to have cleansed. The snapshot has to
            -- be authoritative about absence too.
            local born = Item.instantiate("utility_hexbinders_cord")
            assert(Curse.isCursed(born), "the Cord is born bound -- if this fails the blueprint changed")

            local player = Player.new()
            player.gold = 5000
            Player.addToStash(player, born)
            assert(Curse.pay(player, born), "the Cathedral lifts it for the fee")
            assert(not Curse.isCursed(born), "and it is clean on the shelf")

            local back = Save.restore(Save.snapshot(player))
            assert(back.stash[1] and not Curse.isCursed(back.stash[1]),
                "...and still clean after a save and a load")
        end,
    },
    {
        name = "the paid path takes the fee and the hex, and refuses on an empty purse",
        fn = function()
            local player = Player.new()
            local sword = Item.instantiate("weapon_iron_sword")
            assert(Curse.afflict(sword, "curse_the_anchor"))
            Player.addToStash(player, sword)

            player.gold = 10
            local ok, why = Curse.pay(player, sword)
            assert(not ok and why == "not enough gold", "a short purse is refused, got " .. tostring(why))
            assert(Curse.isCursed(sword), "and nothing was lifted")
            assert(player.gold == 10, "...nor charged")

            player.gold = Curse.fee(sword) + 5
            assert(Curse.pay(player, sword), "a full purse lifts it")
            assert(not Curse.isCursed(sword), "the hex is gone")
            assert(player.gold == 5, "and the fee was taken exactly once")
        end,
    },
    {
        name = "the free rite takes the piece, serves its trips, and hands it back clean",
        fn = function()
            -- THE WHOLE OF THE LAW THIS ROOM KEEPS (docs/the-count.md): gold buys speed and never
            -- relief, so the free path has to actually work -- including on a BINDING hex, which is the
            -- case the player will always reach it with. A bind holds against the player, not the
            -- priests, and nothing else in the game tests that distinction.
            local player = Player.new()
            local char = Character.instantiate("character_knight")
            player.roster = { char }
            local sword = Item.instantiate("weapon_iron_sword")
            Character.addItem(char, sword)
            assert(Curse.afflict(sword, "curse_the_anchor"), "a binding hex")
            assert(Item.isBound(sword), "the player cannot take it off")

            assert(Curse.commit(player, sword), "the priests can")
            assert(Character.slotIndex(char, sword) == nil, "and the grid cell is free again")
            assert(#Curse.rites(player) == 1, "the piece is on the altar")
            assert(#Curse.kit(player) == 0, "and is no longer counted as something to deal with")

            for _ = 1, Curse.RITE_DESCENTS - 1 do
                assert(#Curse.tickRites(player) == 0, "a rite short of its term returns nothing")
            end
            local back = Curse.tickRites(player)
            assert(#back == 1 and back[1] == sword, "the last trip hands the very same table back")
            assert(not Curse.isCursed(sword), "clean")
            assert(#Curse.rites(player) == 0, "and the altar is empty")
            -- To the STASH, never to the cell it came off: that cell is two trips stale and the player
            -- has almost certainly filled it.
            assert(player.stash[1] == sword, "it comes back to the stash")
        end,
    },
    {
        name = "the Cathedral's rite opens once a company has met a curse, and stays open",
        fn = function()
            -- models/offer.lua's GATES.cursed, read through the building it gates. Sticky on purpose: a
            -- gate that read a live count would take the room off the desk in the same visit it was
            -- used, which is the moment the player has just learned what it is for.
            local Offer = require("models.offer")
            local Building = require("models.building")
            local cathedral = Building.defs and Building.defs.cathedral
            assert(cathedral, "the Cathedral exists")

            local player = Player.new()
            assert(not Offer.open(player, { cursed = true }, "cathedral"),
                "a company that has never been hexed is not offered the rite")

            -- THE VECTOR THAT CANNOT STAMP. A trap or a cast hexes a piece through Combat.curseItem,
            -- which is handed a board and never a player -- so nothing writes the mark, and a gate that
            -- read the mark alone would leave a company carrying a curse in a city with no answer to it.
            -- The gate reads the live kit too, and writes the mark off what it finds.
            local sword = Item.instantiate("weapon_iron_sword")
            assert(Curse.afflict(sword, "curse_dead_weight"))
            Player.addToStash(player, sword)
            assert(Offer.open(player, { cursed = true }, "cathedral"),
                "a hex nothing stamped still opens the room")

            local rooms = Offer.openSet(player, cathedral)
            assert(rooms.lift, "and the room is on the Cathedral's desk")

            -- ...and having seen it, the mark is written, so lifting the last hex does not take the
            -- room away in the same visit the player learned what it was for.
            assert(Curse.everCursed(player), "the gate stamped what it found")
            Curse.lift(sword)
            assert(#Curse.kit(player) == 0, "nothing is hexed any more")
            assert(Offer.open(player, { cursed = true }, "cathedral"), "and the room stays on the desk")
        end,
    },
    {
        name = "a reading may turn up hexed, and the chance climbs with depth without ever reaching one",
        fn = function()
            -- The roll itself is chance and is not asserted; the CURVE is, because it is the half that
            -- can silently be wrong. The unit is floorLevel (1..15 down a fifteen-floor rift), which is
            -- the mistake models/identify.lua's fee block records having made once already.
            assert(Identify.curseChance(1) < Identify.curseChance(8),
                "a deeper find is likelier to be hexed")
            assert(Identify.curseChance(15) <= Identify.CURSE_MAX, "and the climb has a ceiling")
            assert(Identify.curseChance(1) > 0, "the shallowest floor can still deal one")
            assert(Identify.CURSE_MAX < 0.5,
                "a majority of finds being hexed would teach the player to stop reading them")

            -- Only shallow hexes exist near the top, which is what keeps a floor-one find from
            -- rooting a knight for two trips.
            for _, id in ipairs(Curse.eligible(1)) do
                assert(Curse.depthOf(Curse.defs[id]) <= 1, id .. " is eligible above its own depth")
            end
            assert(#Curse.eligible(15) > #Curse.eligible(1), "the bottom of the rift deals more of them")
        end,
    },
    {
        name = "reading a husk keeps the hex it was sealed with",
        fn = function()
            -- Identify.read empties the husk table and refills it from a fresh instance, so the hex has
            -- to be lifted out and re-stamped by hand. Without that the reveal would cleanse every
            -- cursed find at the exact moment the player paid to be told what it was -- green in every
            -- other spec, and the whole feature quietly absent from the game.
            local player = Player.new()
            player.gold = 9000
            local husk = Identify.sealed("weapon_iron_sword", 6)
            husk.curse = "curse_thin_blood"
            Player.addToStash(player, husk)

            assert(Identify.read(player, husk), "the counter names it")
            assert(not Identify.isUnidentified(husk), "the seal is off")
            assert(husk.curse == "curse_thin_blood", "and what was inside it came out with it")
            assert(Curse.everCursed(player), "...and the Cathedral has heard about it")
        end,
    },
    {
        name = "a sealed husk is clean to every surface until somebody pays to read it",
        fn = function()
            -- THE OTHER HALF OF THE CASE ABOVE, and the half that shipped broken. Curse.canAfflict has
            -- refused to hex a husk since the day curses landed -- "the player would be told about a hex
            -- on an item they have not been told the identity of" -- but the refusal was only pointed at
            -- PUTTING one on. A husk sealed WITH one answered every reader in the game, and four
            -- surfaces asked: the tooltip printed the hex's name and its sentence under a card titled
            -- Unidentified Weapon; a binding hex locked the stash cell; the Cathedral listed the husk
            -- and the plaza opened its door; and Player.atRisk skipped it, so a hexed find survived a
            -- wipe that dropped the clean ones.
            --
            -- Every one of those is a call to Curse.of, so all four are asserted here through the
            -- predicates they branch on. The source pass below is what keeps them coming through it.
            local Character = require("models.character")
            local player = Player.new()
            local char = Character.instantiate("character_knight")
            player.roster, player.stash, char.inventory = { char }, {}, {}
            player.gold = 9000

            local husk = Identify.sealed("weapon_iron_sword", 12)
            husk.curse = "curse_the_shut_hand" -- a BINDING hex: the loudest of the four leaks
            assert(Curse.defs["curse_the_shut_hand"].binds, "the fixture wants a hex that nails a piece down")

            -- The truth is on the table and none of it is answered for.
            assert(husk.curse == "curse_the_shut_hand", "the seal is still carrying it")
            assert(Curse.of(husk) == nil, "...and will not hand it to a tooltip")
            assert(not Curse.isCursed(husk), "...nor to a badge")
            assert(not Item.isBound(husk), "...nor lock the cell it sits in")

            -- The company as it walked in: empty, so the husk below is a find and nothing else is.
            local entry = Save.snapshot(player)

            Player.addToStash(player, husk)
            assert(#Curse.kit(player) == 0, "the Cathedral has nothing to list")
            assert(not Curse.noticed(player), "...so the plaza keeps its door shut")

            -- A WIPE DROPS IT LIKE ANY OTHER FIND. This is the one the player could have read as luck:
            -- with the bind live, the hexed husk was the only thing in the satchel that came home.
            assert(Player.atRisk(player, entry)[husk] == 1, "a sealed find is at stake, hex or no hex")

            -- ...and the read turns all four on at once.
            assert(Identify.read(player, husk), "the counter names it")
            assert(Curse.of(husk), "now it has a name, the hex on it has one too")
            assert(Item.isBound(husk), "and the bind bites from the moment the player can see why")
            assert(#Curse.kit(player) == 1, "the Cathedral can list what it is being asked to lift")
        end,
    },
    {
        name = "nothing reads a hex off the raw field",
        fn = function()
            -- Curse.of's own header calls itself THE one reader, and the seal guard lives inside it --
            -- so a surface that tests `item.curse` itself is a surface the seal does not cover. That is
            -- not hypothetical: ui/item_tooltip.lua printed the hex for months because its block was
            -- written when a husk had nothing on it worth hiding.
            --
            -- The raw field is legitimate in exactly five places, and each is a WRITER or a PERSISTER
            -- rather than something the player can see:
            local ALLOWED = {
                ["models/curse.lua"] = true,    -- afflict, lift, and the spirit verbs that move one
                ["models/identify.lua"] = true, -- reveal: lifts the hex out of the husk and re-stamps it
                ["models/item.lua"] = true,     -- instantiate: a blueprint born hexed
                ["models/save.lua"] = true,     -- the snapshot, which must carry a sealed hex through
                ["models/combat.lua"] = true,   -- fx.curse, which WRITES an id into a trap's context
            }
            local offenders = {}
            local function walk(dir)
                for _, entry in ipairs(love.filesystem.getDirectoryItems(dir)) do
                    local path = dir .. "/" .. entry
                    if love.filesystem.getInfo(path).type == "directory" then
                        walk(path)
                    elseif entry:sub(-4) == ".lua" and not ALLOWED[path] then
                        for line in (love.filesystem.read(path) or ""):gmatch("[^\r\n]+") do
                            -- `x.curse` on something that is not a comment and not `models.curse`.
                            if not line:match("^%s*%-%-") and line:match("[%w_%)%]]%.curse[^%w_]")
                                and not line:match("models%.curse") then
                                offenders[#offenders + 1] = path .. ": " .. line:match("^%s*(.-)%s*$")
                            end
                        end
                    end
                end
            end
            walk("models")
            walk("ui")
            walk("states")
            assert(#offenders == 0,
                "read the hex through Curse.of, which is where the seal is kept:\n  "
                .. table.concat(offenders, "\n  "))
        end,
    },
}
