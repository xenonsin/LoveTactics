-- Tests for the slime pair (data/characters/character_slime.lua, character_king_slime.lua) and the
-- three engine seams they are built on. Pure logic, headless.
--
-- What is actually under test is not "a slime exists" -- it is the three claims the body makes that
-- nothing else in the game made before it, each of which fails SILENTLY if it breaks:
--
--   1. AN ITEM CAN VOID A DAMAGE TYPE OUTRIGHT (`item.immune` -> Combat.applyUnitPassives ->
--      Status.immuneToDamage). Break the fold and the slime becomes an ordinary soft body with no
--      error anywhere: a sword lands, and the whole design of it is gone.
--   2. AN ELEMENT ANSWERS THAT IMMUNITY, and a status immunity is NOT answered by one. Those are two
--      different promises in one function, and the second belongs to three shipped Seal abilities
--      whose own headers say "every slash-tagged hit is voided to 0". A clause written for the slime
--      that quietly weakened the Seals would pass every slime case here.
--   3. A DEATH CAN PUT REAL BODIES ON THE BOARD. Summon.spawn's three `false` options are one
--      decision, and the default of any one of them deletes the King's second half: the pieces are
--      swept away by the same death that made them, or `killAll` resolves over their heads.
--
-- The adaptation's two halves are checked against each other rather than separately, because the
-- whole reason Combat.strikeElement reads the immunity instead of a second field is that they cannot
-- then disagree -- and a spec that asked each on its own would not notice if they did.

local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")
local Item = require("models.item")
local Encounter = require("models.encounter")
local Descent = require("models.descent")

local SWORD = { "sword", "slash", "physical", "melee" }
local MACE = { "mace", "impact", "physical", "melee" }
local ARROW = { "bow", "pierce", "physical", "ranged" }
local FIREBALL = { "spell", "fire", "magical" }
local ICEBOLT = { "spell", "ice", "magical" }
-- A blade under the Dawn Chrism, or a demon's claws: a physical blow with an element on it.
local BRAND = { "sword", "slash", "physical", "melee", "holy" }

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(id, x, y)
    return { char = Character.instantiate(id), x = x, y = y }
end

-- A fight with one body of `id` on the enemy line, and a bandit of ours to swing at it.
local function fightWith(id)
    local c = Combat.new(arena(10, 10), { unit("character_bandit", 1, 1) }, { unit(id, 5, 5) })
    return c, c.units[2], c.units[1]
end

local function itemNamed(char, id)
    for _, it in ipairs(Character.eachItem(char)) do
        if it.id == id then return it end
    end
    return nil
end

local function slimesOn(c)
    local n = 0
    for _, u in ipairs(c.units) do
        if u.alive and u.char.id == "character_slime" then n = n + 1 end
    end
    return n
end

return {
    -- ----- 1. the body -----
    {
        name = "steel does nothing to a slime, whichever steel it is",
        fn = function()
            local c, slime = fightWith("character_slime")
            assert(slime.immune, "the Amorphous Body's immunity reached the unit's passive fold")

            for _, probe in ipairs({ { "a sword", SWORD }, { "a mace", MACE }, { "an arrow", ARROW } }) do
                assert(Combat.mitigatedDamage(slime, 500, probe[2]) == 0,
                    probe[1] .. " is previewed as landing on a slime")
                local dealt = Combat.dealFlatDamage(c, slime, 500, probe[2], "test")
                assert(dealt == 0, probe[1] .. " actually landed on a slime")
            end
            assert(slime.char.stats.health.current == slime.char.stats.health.max,
                "and after all three it has not been touched")
        end,
    },
    {
        name = "an element lands, and a branded blade counts as one",
        fn = function()
            local c, slime = fightWith("character_slime")
            assert(Combat.dealFlatDamage(c, slime, 20, FIREBALL, "test") > 0, "a spell reaches it")

            local fresh = select(2, fightWith("character_slime"))
            -- THE CLAUSE THE WHOLE BODY TURNS ON. `slash` is a tag it is immune to and `holy` is not,
            -- so the blow lands -- otherwise "put fire on your sword" would be the obvious answer
            -- that silently did nothing, which is a trap rather than a puzzle.
            assert(Combat.mitigatedDamage(fresh, 40, BRAND) > 0,
                "a physical blow carrying an element must get through a physical immunity")
        end,
    },
    {
        name = "a Seal is NOT answered by an element -- the status branch is the older promise",
        fn = function()
            -- data/items/ability/ability_seal_slash.lua promises "every slash-tagged hit is voided to
            -- 0", and it means every one. A body wearing the ward takes nothing from a branded blade,
            -- where the slime takes it in full -- two sources of immunity, two different rules, in one
            -- function. This is the case that keeps the slime's clause from leaking onto the Seals.
            local c, bandit = fightWith("character_bandit")
            Status.apply(c, bandit, "status_immune_slash")
            assert(Combat.mitigatedDamage(bandit, 40, BRAND) == 0,
                "a warded body still voids a slash, element or no element")
            assert(Combat.mitigatedDamage(bandit, 40, MACE) > 0, "...and only a slash")
        end,
    },

    -- ----- 2. the adaptation -----
    {
        name = "it takes the first element it is shown, and that element stops working",
        fn = function()
            local c, slime = fightWith("character_slime")
            local first = Combat.dealFlatDamage(c, slime, 20, FIREBALL, "test")
            assert(first > 0, "the first fire lands")
            assert(Status.has(slime, "status_immune_fire"), "and the body took it in")
            assert(Combat.dealFlatDamage(c, slime, 20, FIREBALL, "test") == 0,
                "so the second fire is a wasted turn")
            assert(Combat.dealFlatDamage(c, slime, 20, ICEBOLT, "test") > 0,
                "and the answer is a different element")
        end,
    },
    {
        name = "one element at a time: the new adaptation sheds the old one",
        fn = function()
            local c, slime = fightWith("character_slime")
            Combat.dealFlatDamage(c, slime, 20, FIREBALL, "test")
            Combat.dealFlatDamage(c, slime, 20, ICEBOLT, "test")
            assert(Status.has(slime, "status_immune_ice"), "it is wearing the cold now")
            assert(not Status.has(slime, "status_immune_fire"),
                "and it let the fire go -- stacking them is a body that becomes unkillable in the "
                .. "number of turns it takes to show the player all of its tricks")
            assert(Combat.dealFlatDamage(c, slime, 20, FIREBALL, "test") > 0, "so fire works again")
        end,
    },
    {
        name = "what it will not take, it hits you with -- and the preview says the same",
        fn = function()
            local c, slime, bandit = fightWith("character_slime")
            local pod = itemNamed(slime.char, "weapon_pseudopod")
            assert(pod, "the slime is carrying its own blow")

            -- A body proof against fire is the cleanest possible reader of "did the blow carry fire":
            -- it answers 0 or it answers a number, with no arithmetic in between.
            Status.apply(c, bandit, "status_immune_fire")
            assert(Combat.computeDamage(c, slime, bandit, pod) > 0,
                "an unadapted slime just leans on you, and a fire ward is no use against that")

            Combat.dealFlatDamage(c, slime, 20, FIREBALL, "test")
            assert(Combat.strikeElement(slime) == "fire", "it is wearing the fire it drank")
            -- THE PREVIEW AND THE BLOW, asked together on purpose. Combat.computeDamage folded no
            -- carried element at all until this pass, so the hover quoted a plain blow and the swing
            -- landed as an elemental one -- which under-promises against a coat and over-promises
            -- against a weakness. One reader now, called from both.
            assert(Combat.computeDamage(c, slime, bandit, pod) == 0,
                "an adapted slime strikes as fire, and the hover says so")
            assert(Combat.dealDamage(c, slime, bandit, pod) == 0,
                "...which is what the blow itself does")
        end,
    },

    -- ----- 3. the King -----
    {
        name = "the King comes apart into real bodies, and they outlive the death that made them",
        fn = function()
            local c = Combat.new(arena(12, 12),
                { unit("character_bandit", 1, 1) },
                { unit("character_king_slime", 6, 6) })
            local king = c.units[2]
            assert(slimesOn(c) == 0, "nothing else is on the board")

            -- Killed with an element, since steel would do nothing -- and a KILLING blow fires no
            -- onDamaged, so the King never adapts to the thing that felled it.
            Combat.dealFlatDamage(c, king, 9999, FIREBALL, "test")
            assert(not king.alive, "the King is down")

            local pieces = slimesOn(c)
            assert(pieces == 3, "three pieces stood up out of it, got " .. pieces)
            for _, u in ipairs(c.units) do
                if u.char.id == "character_slime" then
                    -- Each of the three `false` options, asserted by what it buys rather than by the
                    -- flag: a piece bound to its maker would already have been dismissed by the sweep
                    -- in killUnit that runs one loop after Trait.onDeath.
                    assert(u.alive, "a piece bound to the King would have been swept off with it")
                    assert(u.summoner == nil, "nothing sustains a piece")
                    assert(not u.summoned, "a piece is a combatant, not a conjuration")
                    assert(u.side == "enemy", "and it is on the King's side")
                end
            end
            assert(Combat.evaluate(c) == nil,
                "the fight is NOT over: a killAll has to put the pieces down too")
        end,
    },
    {
        name = "the pieces start unadapted, which is the last turn of the screw",
        fn = function()
            local c = Combat.new(arena(12, 12),
                { unit("character_bandit", 1, 1) },
                { unit("character_king_slime", 6, 6) })
            local king = c.units[2]
            Combat.dealFlatDamage(c, king, 40, FIREBALL, "test") -- it adapts to fire
            assert(Status.has(king, "status_immune_fire"), "the King is wearing fire")
            Combat.dealFlatDamage(c, king, 9999, ICEBOLT, "test")

            local checked = 0
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_slime" then
                    assert(not Status.has(u, "status_immune_fire"), "a piece inherits no memory")
                    assert(not Status.has(u, "status_immune_ice"), "of either element")
                    assert(Combat.dealFlatDamage(c, u, 5, FIREBALL, "test") > 0,
                        "so the element that won the fight is about to stop working, again")
                    checked = checked + 1
                end
            end
            -- Counted, because a loop over a set that turns out to be empty asserts nothing and
            -- passes -- which is exactly how this case read while the split was spawning corpses.
            assert(checked == 3, "all three pieces were checked, got " .. checked)
        end,
    },
    {
        name = "only the crowned body divides, or the board never empties",
        fn = function()
            local c, slime = fightWith("character_slime")
            local before = #c.units
            Combat.dealFlatDamage(c, slime, 9999, FIREBALL, "test")
            assert(not slime.alive, "the slime is down")
            assert(#c.units == before, "and it left nothing behind -- trait_split is the King's alone")
        end,
    },

    {
        name = "the two cores are one immunity and one difference, and the difference is the split",
        fn = function()
            -- A SHARED BLUEPRINT SPLITS RATHER THAN LIES, the weapon_demon_claws argument. Bolting
            -- trait_split onto the common body's core would be one fewer file and would hand the rule
            -- to every slime in the fen -- and the first thing a King does when it falls is make three
            -- of those. So there are two cores, and this is the pair of claims that keeps them honest:
            -- the immunity must be identical (a player who learned the rule off the common body is
            -- never surprised by the crowned one) and the split must not be.
            local common = Item.instantiate("utility_amorphous_body")
            local crowned = Item.instantiate("utility_sovereign_mass")
            for _, tag in ipairs({ "physical", "slash", "pierce", "impact" }) do
                assert(common.immune[tag], "the common core turns aside " .. tag)
                assert(crowned.immune[tag], "and so does the crowned one, identically")
            end
            for tag in pairs(crowned.immune) do
                assert(common.immune[tag], "the King is no harder to cut than a slime: " .. tag)
            end

            local function has(item, trait)
                for _, t in ipairs(item.traits or {}) do if t == trait then return true end end
                return false
            end
            assert(has(common, "trait_adaptive") and has(crowned, "trait_adaptive"),
                "both bodies adapt -- that is the species, not the crown")
            assert(has(crowned, "trait_split"), "the crown is the split")
            assert(not has(common, "trait_split"),
                "a common slime that divided would be an infinite board: the King makes three of them")
        end,
    },

    {
        name = "what it is known for is reachable at the depths it is met at",
        fn = function()
            -- docs/drops.md, Step 2: a body pays off its own list only at a rank the list HAS
            -- something at. A list authored against `unlockLevel` rather than against
            -- `Spoils.depthOf` is the silent failure here -- depthOf lifts a discipline's stock
            -- above its own tier, so a list that looks well spread on the blueprints can land
            -- three entries on one rank and pay nothing at the others.
            local Spoils = require("models.spoils")
            local function depths(id)
                local out = {}
                for _, itemId in ipairs(Character.defs[id].drops or {}) do
                    local def = Item.defs[itemId]
                    assert(def, id .. " names " .. itemId .. ", which is not an item")
                    -- Every rule the pool applies before it will look at an entry (Spoils' `add`).
                    assert(not def.bound, itemId .. " is bound and can never drop")
                    assert(not def.noSteal, itemId .. " is noSteal -- a body part is never on a list")
                    assert(def.type ~= "consumable", itemId .. " is supply, which never takes a rank slot")
                    out[Spoils.depthOf(def)] = true
                end
                return out
            end

            -- DERIVED FROM THE BANDS, NOT LISTED. These were the literals { 2, 4, 6 } -- rungs read
            -- off the eight-rung ladder the finds were banded along before the fold widened it to
            -- fifteen (tools/ladder_fold). A list of rung numbers is a list that silently means
            -- different floors the moment the ladder is re-cut, and this one did: it went on asserting
            -- rank 4 while rank 4 had moved two floors shallower.
            --
            -- What the case is actually about is whether a body can pay SOMETHING on the floors it is
            -- met on, so it asks the floors and lets Spoils.rankBand say which rungs those are.
            local slime = depths("character_slime")
            local function paysOn(set, floor, who)
                -- A FLOOR NUMBER IS NOT A FLOOR LEVEL, and this passed one as the other. It was
                -- invisible while the two were equal; the ladder runs to the cap now and floor six
                -- carries level eighteen, so the case was reading the band of floor two.
                                local lo, hi = Spoils.rankBand({ floorLevel = Descent.floorLevel({ floor = floor }) })
                for r = lo, hi do if set[r] then return end end
                assert(false, string.format(
                    "%s has nothing to pay on floor %d, whose band is %d-%d", who, floor, lo, hi))
            end
            -- Shallow, middle and deep ground, which is what the literals { 2, 4, 6 } were reaching
            -- for on the old ladder: those rungs are bands 1, 3 and 5, and the fold puts them on
            -- rungs {1,2}, {5,6} and {9,10} -- the bands floors 3, 6 and 10 deal.
            for _, floor in ipairs({ 3, 6, 10 }) do paysOn(slime, floor, "a slime") end
            -- The King is an elite met on the middle and deep ground. Its literals were { 4, 5, 6, 7 }
            -- -- bands 3 to 6 on the old ladder, which the fold spreads over rungs 5 to 12 -- so the
            -- floors are the ones whose bands deal those, asked the same way as the common body's.
            local king = depths("character_king_slime")
            for _, floor in ipairs({ 6, 8, 10, 12 }) do paysOn(king, floor, "the King") end

            -- A body part is never on a list, and both cores are the bodies themselves.
            for _, id in ipairs({ "character_slime", "character_king_slime" }) do
                for _, itemId in ipairs(Character.defs[id].drops or {}) do
                    assert(itemId ~= "weapon_pseudopod" and itemId ~= "utility_amorphous_body"
                        and itemId ~= "utility_sovereign_mass", id .. " offers its own body as loot")
                end
            end
        end,
    },
    {
        name = "a slime pays its own list rather than falling through to the band",
        fn = function()
            -- The failure this is really about: the slime's whole grid is `class = "creature"`, which
            -- Spoils refuses, and a creature has no house stock either -- so before a list was authored
            -- a board of nothing but slimes produced an EMPTY candidate pool at every rank and fell
            -- through to `anyAtRank`. It paid out, so nothing looked broken; it was just never the
            -- slime paying.
            local Spoils = require("models.spoils")
            local board = { { char = Character.instantiate("character_slime") } }
            local wanted = {}
            for _, id in ipairs(Character.defs.character_slime.drops) do wanted[id] = true end

            -- Rolled rather than reasoned about, because the thing that broke here is not the list --
            -- it is whether the list is CONSULTED, and only the real draw can answer that. Day 24 is
            -- where the combat band (4-5) overlaps the list, so the pool has something of its own.
            local seen, mine = 0, 0
            for _ = 1, 400 do
                local paid = Spoils.roll({ floorLevel = Descent.floorLevel({ floor = 10 }), kind = "combat", enemyUnits = board })
                for _, id in ipairs((paid or {}).loot or {}) do
                    seen = seen + 1
                    if wanted[id] then mine = mine + 1 end
                end
            end
            assert(seen > 0, "400 fights against a slime paid nothing at all")
            assert(mine > 0, "not one of " .. seen .. " drops off a slime was anything a slime is "
                .. "known for -- the pool is falling through to the band")
        end,
    },

    -- ----- 4. what it takes off you, and the four ways out -----
    {
        name = "corroding eats one piece a turn, and never destroys one",
        fn = function()
            local Status = require("models.status")
            local Item = require("models.item")
            local c, _, bandit = fightWith("character_slime")
            local sword = itemNamed(bandit.char, "weapon_iron_sword")
                or Character.eachItem(bandit.char)[1]
            assert(sword and sword.durability, "the target is carrying something that wears")
            local max = Item.durabilityMax(sword)

            -- Driven through Status.tick with a turn's worth of ticks, which is what Combat.rebase
            -- hands it off the clock -- the same call and the same unit tests/status_spec.lua uses.
            Status.apply(c, bandit, "status_corroding")
            Status.tick(c, Status.TICKS_PER_TURN)
            assert(sword.durability < max, "a turn of Corroding took nothing off the kit")

            -- AND IT STOPS AT NOUGHT. Item.wear's own law -- "deleting gear out from under a player
            -- is the one thing this system must never do" -- so run it far past the piece's whole
            -- durability and check what is left is a broken piece, still in the grid, still mendable.
            for _ = 1, 40 do
                Status.apply(c, bandit, "status_corroding")
                Status.tick(c, Status.TICKS_PER_TURN)
            end
            assert(itemNamed(bandit.char, sword.id) == sword, "the piece is still in the grid")
            assert(sword.durability == 0, "worn out, not deleted: got " .. tostring(sword.durability))
            assert(require("models.forge").mendCost(sword), "and the forge can still quote a mend")
        end,
    },
    {
        name = "a body part cannot corrode, so a slime cannot eat a slime",
        fn = function()
            -- Item.durabilityMax is nil for anything noSteal or bound, which is the whole of this
            -- rule -- the status names neither flag. Worth pinning anyway: the slime's own kit is the
            -- case, and a fen full of them casting at each other is the board it protects.
            local Item = require("models.item")
            local Status = require("models.status")
            local c = Combat.new(arena(10, 10),
                { unit("character_bandit", 1, 1) },
                { unit("character_slime", 5, 5), unit("character_slime", 6, 5) })
            local victim = c.units[3]
            for _, it in ipairs(Character.eachItem(victim.char)) do
                assert(Item.durabilityMax(it) == nil, it.id .. " on a slime can be corroded")
            end
            Status.apply(c, victim, "status_corroding")
            Status.tick(c, Status.TICKS_PER_TURN * 4)
            assert(victim.alive, "and nothing about that hurt it")
        end,
    },
    {
        name = "both of the slimes' casts are answerable: reach, telegraph, and a Cure",
        fn = function()
            -- The three gates the abilities' headers promise, asserted off the blueprints rather than
            -- off the prose -- a counterplay that is only written down is not counterplay
            -- (docs/item-text.md is not a rules engine).
            for _, id in ipairs({ "ability_corrosive_touch", "ability_engulf" }) do
                local ab = Item.defs[id].activeAbility
                assert(ab.range == 1, id .. " must be answerable by walking away")
                assert((ab.windup or 0) >= 1, id .. " must be telegraphed, so a stun or shove denies it")
                assert(ab.damage == nil, id .. " is control, not a blow -- it must deal nothing")
                assert(Item.defs[id].class == "creature" and Item.defs[id].noSteal,
                    id .. " is what the thing IS; it may never reach a shelf or a drop pool")
            end
            -- ...and the statuses they deliver come off with a Cure.
            for _, id in ipairs({ "status_corroding", "status_disarmed" }) do
                assert(require("models.status").defs[id].debuff,
                    id .. " must be a debuff, or Cure and Panacea are no answer to it")
            end
        end,
    },

    -- ----- 5. the King's own pieces -----
    {
        name = "the King's unique pieces are its own rules, and no counter will ever deal one",
        fn = function()
            local Vendor = require("models.vendor")
            for _, id in ipairs({ "utility_unbroken_surface", "armor_quicksilver_mantle" }) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                -- NOT PURCHASABLE, IN EITHER DIRECTION. `unstocked` is answered at Vendor.foundPrice,
                -- which Vendor.sellValue reads too -- so a piece that exists only where it fell has no
                -- market price coming or going. A `price` would reopen the counter behind the flag.
                assert(def.unstocked, id .. " must be rift-only")
                assert(def.price == nil, id .. " carries a price, so a shelf would stock it")
                assert(Vendor.foundPrice(Item.instantiate(id)) == nil,
                    id .. " still quotes a price at a counter")
                assert(not def.bound, id .. " must be the player's to move, forge and break down")
            end

            -- The Mantle is the King's rule at the King's own scale minus one number, which is what
            -- traitParams is for -- and the number is the whole difference between a body that walls
            -- an element for a fight and a coat that answers one blow.
            local mantle = Item.instantiate("armor_quicksilver_mantle")
            assert(mantle.traitParams and mantle.traitParams.duration == 8,
                "the mantle must hold its adaptation for one turn, not the King's eight")
            local Trait = require("models.trait")
            assert(Trait.defs.trait_adaptive.duration > mantle.traitParams.duration,
                "...and the body's own window must be the longer one")

            -- The Surface is the other rule, bounded to an opening. All three physical words, because
            -- the engine keys immunity per tag and a piece that turned a sword and not a fist would be
            -- a hole nobody could see.
            local surface = Item.instantiate("utility_unbroken_surface")
            local named = {}
            for _, b in ipairs(require("models.curse").openingBoons(surface)) do named[b.id] = true end
            for _, tag in ipairs({ "slash", "pierce", "impact" }) do
                assert(named["status_immune_" .. tag],
                    "the Surface does not open proof against " .. tag)
            end
        end,
    },

    -- ----- 6. the wiring -----
    {
        name = "both bodies are actually fielded somewhere",
        fn = function()
            -- A blueprint no encounter composes is a body that reaches no floor, whatever its own file
            -- says about it. Asked of the composition functions rather than of a list, so a condition
            -- that stops naming them fails here.
            -- Deep enough for both gates: the ooze opens at day 6 and the King at 14, and a ctx
            -- shallower than either would pass this case by simply never asking about the body.
            -- The KEEP since the 2026-09-25 swap: Greed came up out of the fen and brought its slimes.
            local ctx = { day = 20, biome = "castle", prestige = 4 }
            local seen = {}
            for _, def in pairs(Encounter.defs) do
                if def.condition == nil or def.condition(ctx) then
                    local comp = def.composition
                    if type(comp) == "function" then comp = comp(ctx) end
                    for _, id in ipairs(comp or {}) do seen[id] = true end
                end
            end
            assert(seen.character_slime, "nothing in Greed's keep fields a slime")
            assert(seen.character_king_slime, "nothing in Greed's keep fields the King")
        end,
    },
    {
        name = "the King is a boss the fight does not end on",
        fn = function()
            local def = Character.defs.character_king_slime
            assert(def.boss, "boss = true: an execute that skipped the split would delete half the fight")
            assert(def.tier == 4, "and the rung the split's health budget is spread across")
            -- The one thing that would silently switch the second half of the fight off. An
            -- `assassinate` on this body ends the battle the moment it falls, which is the moment the
            -- pieces arrive.
            for id, quest in pairs(require("models.quest").defs) do
                local obj = quest.map and quest.map.objective
                if obj and obj.type == "assassinate" then
                    assert(obj.target ~= "character_king_slime", id
                        .. " marks the King for assassination, which ends the fight on the beat the "
                        .. "split begins it. Field it under killAll.")
                end
            end
        end,
    },

    -- ----- 3. the wood's slimes: the same question, asked softly on the floor a descent opens on -----
    {
        name = "a moss slime RESISTS steel rather than voiding it, and an element still lands whole",
        fn = function()
            -- The opening stair cannot be walked past, so a pair with no element must be able to hurt
            -- what stands on it -- slowly. Both relics resist steel and neither voids it.
            for _, rid in ipairs({ "utility_mossy_body", "utility_moss_crown" }) do
                local r = Item.defs[rid]
                assert(r and r.bound and not r.immune, rid .. " must resist, never void")
                assert((r.resist.slash or 0) > 0 and (r.resist.impact or 0) > 0, rid .. " resists steel")
            end
            for _, id in ipairs({ "character_moss_slime", "character_moss_king_slime" }) do
                local c, slime = fightWith(id)
                assert(not (slime.immune and (slime.immune.slash or slime.immune.impact)),
                    id .. " is immune to steel, which walls the opening stair")
                -- 25 is about what a floor-one blow weighs before mitigation (Rowan's iron mace).
                for _, probe in ipairs({ { "a sword", SWORD }, { "a mace", MACE }, { "an arrow", ARROW } }) do
                    assert(Combat.mitigatedDamage(slime, 25, probe[2]) > 1, probe[1] .. " cannot hurt " .. id)
                end
                local steel = Combat.mitigatedDamage(slime, 25, MACE)
                local fire = Combat.mitigatedDamage(slime, 25, FIREBALL)
                assert(steel <= fire * 0.6, id .. ": steel must land for well under what an element does ("
                    .. steel .. " vs " .. fire .. ")")
                Combat.dealFlatDamage(c, slime, 20, FIREBALL, "test")
                assert(Status.has(slime, "status_immune_fire"), id .. " still adapts to what it is shown")
            end
        end,
    },
    {
        name = "the Moss King comes apart into MOSS slimes, never fen ones",
        fn = function()
            local c = Combat.new(arena(12, 12),
                { unit("character_bandit", 1, 1) },
                { unit("character_moss_king_slime", 6, 6) })
            Combat.dealFlatDamage(c, c.units[2], 9999, FIREBALL, "test")
            local moss, fen = 0, 0
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_moss_slime" then moss = moss + 1 end
                if u.alive and u.char.id == "character_slime" then fen = fen + 1 end
            end
            assert(moss == 3 and fen == 0, "split into " .. moss .. " moss and " .. fen .. " fen slimes")
            assert(Combat.evaluate(c) == nil, "a killAll still has to put the pieces down")
        end,
    },
    {
        name = "the Moss King is an elite on the wood's first floor, and the moss slimes roll on both",
        fn = function()
            local king = Encounter.defs.encounter_the_moss_king
            assert(king and king.kind == "elite" and king.rung == 1, "an elite, runged onto the approach")
            assert(king.condition({ biome = "forest" }) and not king.condition({ biome = "swamp" }),
                "in the wood only")
            local comp = king.composition({ depth = 1 })
            assert(comp[1] == "character_moss_king_slime", "he leads it")
            assert(#comp >= 3, "with at least two of his court to eat")
            local gluttony
            for _, s in ipairs(Descent.SINS) do if s.id == "gluttony" then gluttony = s end end
            assert(gluttony.minor.lead ~= "character_moss_king_slime", "he does not hold the stair")
            local seen = false
            for _, id in ipairs(gluttony.elites.spares) do seen = seen or id == "encounter_the_moss_king" end
            assert(seen, "Gluttony bills him among its rung-1 spares")
            local def = Encounter.defs.encounter_the_moss_slimes
            assert(def and def.rung == nil, "the moss slimes stand on both of the wood's floors")
            assert(def.condition({ biome = "forest" }) and not def.condition({ biome = "swamp" }),
                "and only in the wood; the fen keeps its own")
        end,
    },

    -- ----- 4. Gluttony's slime rule: Coalesce -----
    {
        name = "Coalesce: a moss slime swallows its kin and takes all of its health into itself",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_bandit", 10, 10) },
                { unit("character_moss_slime", 4, 4), unit("character_moss_slime", 5, 4) })
            local eater, meal = c.units[2], c.units[3]
            local hp = eater.char.stats.health
            local maxBefore, mealHp = hp.max, 20
            meal.char.stats.health.current = mealHp
            Combat.useItem(c, eater, itemNamed(eater.char, "ability_coalesce"), eater.x, eater.y)
            assert(not meal.alive and meal.devoured, "the kin is eaten, not killed")
            assert(not meal.corpse, "and leaves nothing lying there")
            assert(hp.max == maxBefore + mealHp, "its ceiling grows by what the meal had left: "
                .. hp.max .. " vs " .. (maxBefore + mealHp))
            assert(hp.current == hp.max, "and it is full")
            assert(Status.has(eater, "status_gorged"), "a slime that has just eaten is Gorged")
        end,
    },
    {
        name = "Coalesce eats only moss slimes: never a foe, never another beast, never the King",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_bandit", 5, 5) },
                { unit("character_moss_slime", 4, 5), unit("character_wolf_grunt", 3, 5),
                  unit("character_moss_king_slime", 4, 4) })
            local eater = c.units[2]
            local maxBefore = eater.char.stats.health.max
            Combat.useItem(c, eater, itemNamed(eater.char, "ability_coalesce"), eater.x, eater.y)
            for _, u in ipairs(c.units) do assert(u.alive, u.char.id .. " was eaten") end
            assert(eater.char.stats.health.max == maxBefore, "nothing edible, nothing gained")
        end,
    },
    {
        name = "the planner coalesces: with its kin beside it and no foe near, a moss slime eats",
        fn = function()
            local c = Combat.new(arena(12, 9),
                { unit("character_bandit", 12, 9) },
                { unit("character_moss_slime", 2, 2), unit("character_moss_slime", 3, 2) })
            local plan = Combat.planEnemyAction(c, c.units[2])
            assert(plan and plan.item and plan.item.id == "ability_coalesce",
                "it plans to eat: " .. tostring(plan and (plan.reason or (plan.item and plan.item.id))))
        end,
    },
    {
        name = "gather: a moss slime walks toward its kin, not toward the fight",
        fn = function()
            local AI = require("models.ai")
            assert(AI.POSTURES.gather and AI.POSTURES.gather.move == "gather", "the posture exists")
            assert(Character.defs.character_moss_slime.archetype == "gather", "the moss slime wears it")
            assert(Character.defs.character_moss_king_slime.archetype == "gather", "and so does its King")
            -- Foe off to the left, kin off to the right: it goes right.
            local c = Combat.new(arena(16, 5),
                { unit("character_bandit", 1, 3) },
                { unit("character_moss_slime", 8, 3), unit("character_moss_slime", 15, 3) })
            local me = c.units[2]
            local plan = Combat.planEnemyAction(c, me)
            local dest = plan and (plan.move or plan.dest)
            assert(dest and dest.x > me.x, "it walks toward its kin: " .. tostring(dest and dest.x))
        end,
    },

    -- ----- 5. the drops: what came apart comes back together, worn -----
    {
        name = "each moss body drops its own pieces, and only its own",
        fn = function()
            local slime = Character.defs.character_moss_slime.drops
            assert(#slime == 1 and slime[1] == "armor_mosswrap", "the moss slime drops the Mosswrap")
            local king = Character.defs.character_moss_king_slime.drops
            assert(#king == 2 and king[1] == "utility_crown_of_the_court" and king[2] == "utility_moss_heart",
                "the Moss King drops his Crown and his Heart")
            for _, id in ipairs({ "armor_mosswrap", "utility_crown_of_the_court", "utility_moss_heart" }) do
                assert(Item.defs[id].unstocked, id .. " is the body's own, never sold")
            end
        end,
    },
    {
        name = "Rejoin: a sloughling beside its maker gives its health back, never past the ceiling",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_bandit", 3, 3) }, { unit("character_bandit", 9, 9) })
            local me = c.units[1]
            local Summon = require("models.summon")
            local piece = Summon.spawn(c, me, "character_moss_sloughling", 4, 3, { stats = { health = 10 } })
            assert(piece and piece.summoner == me, "the piece knows whose it is")
            local hp = me.char.stats.health
            hp.current = hp.max - 6
            Combat.useItem(c, piece, itemNamed(piece.char, "ability_rejoin"), piece.x, piece.y)
            assert(not piece.alive and piece.devoured, "it goes home and is gone")
            assert(hp.current == hp.max, "its 10 health heals the 6 missing and no more")
        end,
    },
    {
        name = "Slough: the Mosswrap sheds one sloughling, once, when struck below half",
        fn = function()
            local worn = Character.instantiate("character_bandit")
            Character.addItem(worn, Item.instantiate("armor_mosswrap"))
            local c = Combat.new(arena(10, 10),
                { { char = worn, x = 3, y = 3 } }, { unit("character_bandit", 9, 9) })
            local me = c.units[1]
            local function pieces()
                local n = 0
                for _, u in ipairs(c.units) do
                    if u.alive and u.char.id == "character_moss_sloughling" then n = n + 1 end
                end
                return n
            end
            local hp = me.char.stats.health
            Combat.dealFlatDamage(c, me, 1, {}, "test")
            assert(pieces() == 0, "a scratch above half sheds nothing")
            hp.current = math.floor(hp.max * 0.4) -- defence would eat a measured blow; set it, then scratch
            Combat.dealFlatDamage(c, me, 1, {}, "test")
            assert(pieces() == 1, "struck below half: one piece sloughs off, got " .. pieces())
            Combat.dealFlatDamage(c, me, 1, {}, "test")
            assert(pieces() == 1, "and only once a battle")
        end,
    },
    {
        name = "the Crown of the Court calls two sloughlings that are the wearer's own",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_bandit", 3, 3) }, { unit("character_bandit", 9, 9) })
            local me = c.units[1]
            local crown = Item.instantiate("utility_crown_of_the_court")
            Character.addItem(me.char, crown)
            me.char.stats.stamina.current = me.char.stats.stamina.max
            Combat.useItem(c, me, crown, me.x, me.y)
            local n = 0
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_moss_sloughling" then
                    n = n + 1
                    assert(u.summoner == me and u.side == me.side, "the court is the wearer's")
                end
            end
            assert(n == 2, "two stand up, got " .. n)
        end,
    },
    {
        name = "Come Apart: the Moss Heart turns a felling blow into 1 health and three pieces, once",
        fn = function()
            local worn = Character.instantiate("character_bandit")
            Character.addItem(worn, Item.instantiate("utility_moss_heart"))
            local c = Combat.new(arena(10, 10),
                { { char = worn, x = 5, y = 5 } }, { unit("character_bandit", 9, 9) })
            local me = c.units[1]
            Combat.dealFlatDamage(c, me, 99999, {}, "test")
            assert(me.alive and me.char.stats.health.current == 1, "it is standing, at 1")
            local n = 0
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_moss_sloughling" and u.summoner == me then n = n + 1 end
            end
            assert(n == 3, "three pieces spilled out, got " .. n)
            Combat.dealFlatDamage(c, me, 99999, {}, "test")
            assert(not me.alive or me.incapacitated, "the second felling blow fells it")
        end,
    },
    {
        name = "the Moss King's pieces are moss slimes, so they can eat each other back together",
        fn = function()
            local c = Combat.new(arena(12, 12),
                { unit("character_bandit", 1, 1) },
                { unit("character_moss_king_slime", 6, 6) })
            Combat.dealFlatDamage(c, c.units[2], 9999, FIREBALL, "test")
            local pieces = {}
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_moss_slime" then pieces[#pieces + 1] = u end
            end
            local a, b = pieces[1], pieces[2]
            assert(a and b and itemNamed(a.char, "ability_coalesce"), "the pieces carry Coalesce")
            -- Where the split drops them is Combat.openTileNear's business; stand them side by side.
            a.x, a.y, b.x, b.y = 10, 10, 11, 10
            local before = a.char.stats.health.max
            Combat.useItem(c, a, itemNamed(a.char, "ability_coalesce"), a.x, a.y)
            assert(not b.alive and b.devoured, "a piece swallows a piece")
            assert(a.char.stats.health.max > before, "and grows by it")
        end,
    },
    -- ----- 6. Greed's slime rule: Interest -----
    {
        name = "Interest: a swamp slime gains Damage each of its turns, and banks a purse it pays on death",
        fn = function()
            local c, slime = fightWith("character_slime")
            local st = Status.get(slime, "status_interest")
            assert(st, "the account is open at the bell")
            local base = slime.char.stats.damage + Status.statBonus(slime, "damage")
            Status.onTurnStart(c, slime)
            Status.onTurnStart(c, slime)
            assert(Status.statBonus(slime, "damage") >= 4, "two turns, +2 each")
            assert(st.purse == 8, "and 4 gold a turn in the purse, got " .. tostring(st.purse))
            for _ = 1, 10 do Status.onTurnStart(c, slime) end
            assert(st.turns == 6, "it stops compounding at its cap")
            local before = c.bounty or 0
            Combat.dealFlatDamage(c, slime, 9999, FIREBALL, "test")
            assert((c.bounty or 0) - before == st.purse, "its death banks the purse on the fight")
            assert(base, "fixture")
        end,
    },
    {
        name = "the King Slime compounds double, and his pieces inherit his account instead of paying it",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_bandit", 1, 1) },
                { unit("character_king_slime", 6, 6) })
            local king = c.units[2]
            local st = Status.get(king, "status_interest")
            Status.onTurnStart(c, king)
            Status.onTurnStart(c, king)
            assert(st.purse == 16, "8 gold a turn, got " .. tostring(st.purse))
            Combat.dealFlatDamage(c, king, 9999, FIREBALL, "test")
            assert((c.bounty or 0) == 0, "his own death pays nothing -- the account went to the pieces")
            local owed = 0
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_slime" then
                    owed = owed + (Status.get(u, "status_interest").purse or 0)
                end
            end
            assert(owed == 16, "the pieces carry all 16 between them, got " .. owed)
        end,
    },
    {
        name = "Greed's drops: the Ledger Coin grows, the Purse pays each turn, the Scale writes a debt",
        fn = function()
            assert(itemNamed({ inventory = {} }, "x") == nil, "fixture")
            local slimeDrops, kingDrops = {}, {}
            for _, id in ipairs(Character.defs.character_slime.drops) do slimeDrops[id] = true end
            for _, id in ipairs(Character.defs.character_king_slime.drops) do kingDrops[id] = true end
            assert(slimeDrops.utility_ledger_coin, "the slime drops the Ledger Coin")
            assert(kingDrops.utility_compound_purse and kingDrops.utility_usurers_scale, "the King his two")

            local worn = Character.instantiate("character_bandit")
            Character.addItem(worn, Item.instantiate("utility_ledger_coin"))
            Character.addItem(worn, Item.instantiate("utility_usurers_scale"))
            local purse = Character.instantiate("character_bandit")
            Character.addItem(purse, Item.instantiate("utility_compound_purse"))
            local c = Combat.new(arena(10, 10),
                { { char = worn, x = 4, y = 4 }, { char = purse, x = 1, y = 1 } },
                { unit("character_knight", 5, 4) })
            local me, banker, foe = c.units[1], c.units[2], c.units[3]
            for _ = 1, 8 do Status.onTurnStart(c, me) end
            assert(Status.statBonus(me, "damage") == 6, "the coin: +1 a turn, capped at +6")
            Status.onTurnStart(c, banker)
            Status.onTurnStart(c, banker)
            assert((c.bounty or 0) == 6, "the purse banks 3 a turn on the fight, got " .. tostring(c.bounty))
            local sword = itemNamed(me.char, "weapon_iron_sword")
            Combat.useItem(c, me, sword, foe.x, foe.y)
            local owed = Status.get(foe, "status_owed")
            assert(owed and owed.magnitude == 1, "a landed hit writes one stack of Owed")
            -- One action a turn, so the second hit is the trait's own re-application.
            for _ = 1, 8 do Status.apply(c, foe, "status_owed", { magnitude = 1 }) end
            assert(owed.magnitude == 6, "each hit adds a stack, up to six: " .. owed.magnitude)
        end,
    },
}
