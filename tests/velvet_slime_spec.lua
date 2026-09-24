-- Tests for Lust's slime line: the velvet slime and its Queen (data/characters/character_velvet_slime.lua,
-- character_velvet_queen.lua), the STRIP loan they are built on (Combat.strip), and their three drops.
--
-- The claim that matters most is the one a player can never see fail: NOTHING A SLIME STRIPS IS EVER
-- LOST. A strip is a loan the fight takes out, and it has four nets -- the holder's death, finishBattle
-- (Combat.returnStripped), the next Combat.new and every save (Character.restoreStripped). Each of the
-- last two is asserted here on a combat that was simply dropped, which is what a crash or an unforeseen
-- exit looks like from the model's side.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Encounter = require("models.encounter")
local Descent = require("models.descent")

local FIREBALL = { "spell", "fire", "magical" }
local SWORD = { "sword", "slash", "physical", "melee" }

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

local function unit(id, x, y)
    return { char = Character.instantiate(id), x = x, y = y }
end

local function itemNamed(char, id)
    for _, it in ipairs(Character.eachItem(char)) do
        if it.id == id then return it end
    end
    return nil
end

local function holds(char, id) return itemNamed(char, id) ~= nil end

-- A knight (spear, sword, chainmail, buckler, potion) beside one velvet body of `id`.
local function undressing(id)
    local c = Combat.new(arena(10, 10), { unit("character_knight", 4, 4) }, { unit(id, 5, 4) })
    return c, c.units[1], c.units[2]
end

local function swing(c, slime, knight)
    Combat.useItem(c, slime, itemNamed(slime.char, "weapon_pseudopod"), knight.x, knight.y)
end

return {
    -- ----- the body -----
    {
        name = "a velvet slime is proof against steel, and adapts like the fen's",
        fn = function()
            for _, rid in ipairs({ "utility_velvet_body", "utility_velvet_train" }) do
                local r = Item.defs[rid]
                assert(r.bound and r.immune and r.immune.slash, rid .. " is a bound body, proof against steel")
            end
            local c, _, slime = undressing("character_velvet_slime")
            assert(Combat.mitigatedDamage(slime, 50, SWORD) == 0, "steel does nothing")
            assert(Combat.dealFlatDamage(c, slime, 20, FIREBALL, "test") > 0, "an element lands")
            assert(require("models.status").has(slime, "status_immune_fire"), "and it adapts")
        end,
    },
    {
        name = "Strip: its blow takes the ARMOUR first, and it wears what it took",
        fn = function()
            local c, knight, slime = undressing("character_velvet_slime")
            local mail = itemNamed(knight.char, "armor_chainmail")
            swing(c, slime, knight)
            assert(not holds(knight.char, "armor_chainmail") or not holds(knight.char, "armor_buckler"),
                "a piece of armour came off")
            local taken = holds(slime.char, "armor_chainmail") and "armor_chainmail" or "armor_buckler"
            assert(holds(slime.char, taken), "and the slime is wearing it")
            assert(holds(knight.char, "weapon_iron_sword"), "armour before weapons")
            assert(knight.char.stripped and #knight.char.stripped == 1, "the owner's ledger records the loan")
            assert(mail, "fixture")
        end,
    },
    {
        name = "kill the slime and what it took goes back into the cell it came out of",
        fn = function()
            local c, knight, slime = undressing("character_velvet_slime")
            local before = {}
            for i = 1, Character.MAX_INVENTORY do before[i] = knight.char.inventory[i] end
            swing(c, slime, knight)
            swing(c, slime, knight)
            Combat.dealFlatDamage(c, slime, 9999, FIREBALL, "test")
            assert(not slime.alive, "the slime is down")
            for i = 1, Character.MAX_INVENTORY do
                assert(knight.char.inventory[i] == before[i], "cell " .. i .. " is back as it was")
            end
            assert(knight.char.stripped == nil, "and the ledger is clear")
        end,
    },
    {
        name = "a lost fight gives everything back at finishBattle (Combat.returnStripped)",
        fn = function()
            local c, knight, slime = undressing("character_velvet_slime")
            swing(c, slime, knight)
            assert(slime.alive, "the slime is still standing, wearing the piece")
            Combat.returnStripped(c)
            assert(holds(knight.char, "armor_chainmail") and holds(knight.char, "armor_buckler"),
                "both pieces are home")
            assert(knight.char.stripped == nil, "and nothing is still out")
        end,
    },
    {
        name = "THE NET: a fight simply dropped mid-strip is undone by the next Combat.new",
        fn = function()
            local c, knight, slime = undressing("character_velvet_slime")
            swing(c, slime, knight)
            swing(c, slime, knight)
            -- No returnStripped: this is a crash, a quit, an exit nobody wired.
            local char = knight.char
            Combat.new(arena(6, 6), { { char = char, x = 1, y = 1 } }, { unit("character_bandit", 6, 6) })
            assert(holds(char, "armor_chainmail") and holds(char, "armor_buckler"),
                "the next fight starts with the knight dressed")
            assert(char.stripped == nil, "and the ledger is clear")
            for _, it in ipairs(Character.eachItem(char)) do
                assert(not it.onLoan, it.id .. " is still marked as on loan in its own owner's grid")
            end
        end,
    },
    {
        name = "a Jealous Resin (and so the Silk Lining) refuses a strip outright",
        fn = function()
            local worn = Character.instantiate("character_knight")
            Character.addItem(worn, Item.instantiate("armor_silk_lining"))
            local c = Combat.new(arena(10, 10), { { char = worn, x = 4, y = 4 } },
                { unit("character_velvet_slime", 5, 4) })
            local knight, slime = c.units[1], c.units[2]
            swing(c, slime, knight)
            assert(holds(knight.char, "armor_chainmail") and holds(knight.char, "armor_silk_lining"),
                "nothing came off")
            assert(Item.defs.armor_silk_lining.statusImmunity[1] == "status_disarmed", "and no disarm lands")
        end,
    },

    -- ----- the Queen -----
    {
        name = "the Queen takes two pieces a blow, and divides with her wardrobe shared among the pieces",
        fn = function()
            local c = Combat.new(arena(12, 12), { unit("character_knight", 5, 6) },
                { unit("character_velvet_queen", 6, 6) })
            local knight, queen = c.units[1], c.units[2]
            swing(c, queen, knight)
            assert(#(knight.char.stripped or {}) == 2, "two pieces in one blow")
            Combat.dealFlatDamage(c, queen, 99999, FIREBALL, "test")
            local pieces, worn = {}, 0
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_velvet_slime" then
                    pieces[#pieces + 1] = u
                    for _, it in ipairs(Character.eachItem(u.char)) do if it.onLoan then worn = worn + 1 end end
                end
            end
            assert(#pieces == 3, "three pieces")
            assert(worn == 2, "and they walked off wearing both pieces between them, got " .. worn)
            for _, p in ipairs(pieces) do Combat.dealFlatDamage(c, p, 99999, FIREBALL, "test") end
            assert(holds(knight.char, "armor_chainmail") and holds(knight.char, "armor_buckler"),
                "every piece put down, everything home")
        end,
    },

    -- ----- the drops -----
    {
        name = "each velvet body drops its own pieces, and only its own",
        fn = function()
            local s = Character.defs.character_velvet_slime.drops
            assert(#s == 1 and s[1] == "utility_velvet_glove", "the slime drops the Glove")
            local q = Character.defs.character_velvet_queen.drops
            assert(#q == 3 and q[1] == "utility_kept_suitors" and q[2] == "utility_loosened_laces"
                and q[3] == "armor_silk_lining", "the Queen drops the Suitors, the Laces and the Lining")
            for _, id in ipairs({ "utility_velvet_glove", "utility_kept_suitors", "utility_loosened_laces",
                                  "armor_silk_lining" }) do
                assert(Item.defs[id].unstocked and Item.defs[id].class == "priest",
                    id .. " is the Cathedral's, and never sold")
            end
        end,
    },
    {
        name = "the Velvet Glove strips the first foe's armour off, once a battle, and keeps nothing",
        fn = function()
            local worn = Character.instantiate("character_bandit")
            Character.addItem(worn, Item.instantiate("utility_velvet_glove"))
            local c = Combat.new(arena(10, 10), { { char = worn, x = 4, y = 4 } },
                { unit("character_knight", 5, 4) })
            local me, foe = c.units[1], c.units[2]
            local sword = itemNamed(me.char, "weapon_iron_sword")
            Combat.useItem(c, me, sword, foe.x, foe.y)
            local armour = 0
            for _, it in ipairs(Character.eachItem(foe.char)) do if it.type == "armor" then armour = armour + 1 end end
            assert(armour == 1, "one piece of its armour is off, got " .. armour .. " left")
            assert(not holds(me.char, "armor_chainmail") and not holds(me.char, "armor_buckler"),
                "and nobody is wearing it")
            Combat.useItem(c, me, sword, foe.x, foe.y)
            armour = 0
            for _, it in ipairs(Character.eachItem(foe.char)) do if it.type == "armor" then armour = armour + 1 end end
            assert(armour == 1, "only the first hit of the battle")
        end,
    },
    {
        name = "Kept Suitors: a foe Charmed by you lends you its armour's Defense, only while it holds",
        fn = function()
            local Status = require("models.status")
            local worn = Character.instantiate("character_bandit")
            Character.addItem(worn, Item.instantiate("utility_kept_suitors"))
            local c = Combat.new(arena(10, 10), { { char = worn, x = 4, y = 4 } },
                { unit("character_knight", 8, 8) })
            local me, foe = c.units[1], c.units[2]
            local function def() return Combat.computeStat and Combat.computeStat(me, "defense")
                or (me.char.stats.defense + (me.bonus.defense or 0) + require("models.trait").liveBonus(me, "defense")) end
            local before = def()
            Status.apply(c, foe, "status_charm", { applier = me })
            local charm = Status.get(foe, "status_charm")
            assert(charm, "the knight is charmed")
            charm.charmer = me
            local lent = 0
            for _, it in ipairs(Character.eachItem(foe.char)) do
                if it.type == "armor" and type(it.bonus and it.bonus.defense) == "number" then lent = lent + it.bonus.defense end
            end
            assert(lent > 0, "fixture: the knight wears armour")
            assert(def() == before + lent, "the bearer wears its Defense: " .. def() .. " vs " .. (before + lent))
            Status.remove(c, foe, "status_charm")
            assert(def() == before, "and loses it the moment the charm ends")
        end,
    },
    {
        name = "Loosened Laces: every foe within two tiles has -2 Defense, and nobody further out",
        fn = function()
            local Trait = require("models.trait")
            local worn = Character.instantiate("character_bandit")
            Character.addItem(worn, Item.instantiate("utility_loosened_laces"))
            local c = Combat.new(arena(12, 12), { { char = worn, x = 4, y = 4 } },
                { unit("character_knight", 5, 4), unit("character_knight", 11, 11) })
            local me, near, far = c.units[1], c.units[2], c.units[3]
            assert(Trait.liveBonus(near, "defense") == -2, "a foe beside the bearer is loosened")
            assert(Trait.liveBonus(far, "defense") == 0, "one across the board is not")
            assert(Trait.liveBonus(me, "defense") == 0, "and the bearer's own side is untouched")
        end,
    },

    -- ----- placement -----
    {
        name = "the velvet slimes stand on Lust's approach and their Queen on its seat, in the keep only",
        fn = function()
            local slimes = Encounter.defs.encounter_the_velvet_slimes
            local queen = Encounter.defs.encounter_the_velvet_queen
            assert(slimes.kind == "elite" and slimes.rung == 1, "the slimes are the approach's elite")
            assert(queen.kind == "elite" and queen.rung == 2, "the Queen is the seat's")
            for _, e in ipairs({ slimes, queen }) do
                assert(e.condition({ biome = "castle" }) and not e.condition({ biome = "swamp" }), "the keep only")
            end
            local lust
            for _, s in ipairs(Descent.SINS) do if s.id == "lust" then lust = s end end
            local billed = {}
            for _, id in ipairs(lust.elites.spares) do billed[id] = true end
            assert(billed.encounter_the_velvet_slimes and billed.encounter_the_velvet_queen,
                "Lust bills both among its spares")
        end,
    },
}
