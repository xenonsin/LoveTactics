-- WHAT A SIN PAYS FOR BEING PUT DOWN: models/descent.lua's DROPS, a queue per rank, headed by the piece
-- each body was built around -- a general's relic and a lieutenant's own piece.
--
-- THERE CAN NEVER BE CREATURE DROPS (2026-10-01). These fourteen were once `class = "creature"`: the
-- bucket that is on no shelf and is nobody's career, which was how "no house would claim it" got said.
-- That made the rarest things in the game the only drops a player could not find on any rack or read
-- about at any counter. Every one now sits on a real class's shelf as a TROPHY -- `unstocked`, unpriced,
-- shown and refused as a monster drop, the way every other body's own piece is (docs/drops.md) -- and
-- the body is still the only road to it.
--
-- AND A CIRCLE IS NOT A SET. This file used to assert that a lieutenant's piece reads the condition its
-- general's relic creates, making each circle a two-piece set. That rule is removed: each piece stands on
-- its own, and a lieutenant's need not be cut to fit anything. Whatever pairing a piece's own rule still
-- describes is that piece's business, pinned by the cases below as a rule rather than as a set.
--
-- The design was authored long before the wiring. data/items/armor/armor_mail_of_the_unappeased.lua has
-- always said it outright -- "kill a sin, wear it" -- while what a circle actually paid was a SHOP DOOR, a
-- patch applied when the Quest Board was retired and seven houses could no longer open. The door opens
-- on an errand now (tests/hub_spec.lua) and the body pays what it was carrying.
--
-- Every id here is named literally rather than walked out of the table, because tests/item_coverage_spec
-- reads test files as text: a table-walk exercises the items and covers none of them.

local Descent = require("models.descent")
local Item = require("models.item")
local Player = require("models.player")
local Character = require("models.character")

-- sin -> { general's relic, lieutenant's piece, the shelf each sits on }
local HEADS = {
    gluttony = { "utility_maw_of_the_unfed",     "utility_larder_hook",    "hunter",     "hunter" },
    lust     = { "utility_reliquary_unbidden",   "utility_beggars_bowl",   "rogue",      "inquisitor" },
    greed    = { "utility_gilded_belly",         "utility_tally_stick",    "mammonite",  "mammonite" },
    envy     = { "utility_pretenders_crown",     "utility_second_vessel",  "alchemist",  "alchemist" },
    wrath    = { "utility_the_broken_vow",       "utility_anvils_face",    "monk",       "fighter" },
    sloth    = { "weapon_forsworn_pike",         "utility_unblown_horn",   "knight",     "knight" },
    -- Pride's relic is Superbia's Morning Star; her lieutenant Sublimitas pays the Codex (2026-10-01).
    pride    = { "utility_the_morning_star",     "utility_codex_unanswered", "mage",   "mage" },
}

local function isCreature(def) return def.class == "creature" end

return {
    {
        -- The table above IS the assertion: if a sin's payment is renamed or re-pointed, this file must
        -- be edited to match, which is the point of naming all fourteen by hand. ENTRY #1 NEVER MOVES:
        -- the relic is what the fight was built to hand over.
        name = "every circle's lists are headed by its general's relic and its lieutenant's piece, by name",
        fn = function()
            for _, sin in ipairs(Descent.SINS) do
                local want = HEADS[sin.id]
                assert(want, sin.id .. " has no expected heads in this spec")
                local got = Descent.DROPS[sin.id]
                assert(got, sin.id .. " has no drop lists in Descent.DROPS")
                assert(got.general[1] == want[1],
                    sin.id .. "'s general pays " .. tostring(got.general[1]) .. ", expected " .. want[1])
                assert(got.minor[1] == want[2],
                    sin.id .. "'s lieutenant pays " .. tostring(got.minor[1]) .. ", expected " .. want[2])
            end
        end,
    },
    {
        -- THE RULE, OVER EVERY ENTRY rather than the fourteen heads: a queued piece is paid by the same
        -- body, so a creature anywhere in a list is a creature drop. Walked here, because a list is
        -- appended to by hand and the next append is the one nobody checks.
        name = "nothing a sin pays is creature kit, and nothing it pays is priced",
        fn = function()
            local bad = {}
            for sinId, set in pairs(Descent.DROPS) do
                for _, rank in ipairs({ "general", "minor" }) do
                    for _, id in ipairs(set[rank] or {}) do
                        local def = Item.defs[id]
                        if not def then
                            bad[#bad + 1] = sinId .. "." .. rank .. ": " .. id .. " does not exist"
                        elseif isCreature(def) or not def.class then
                            bad[#bad + 1] = sinId .. "." .. rank .. ": " .. id .. " is on no real shelf ("
                                .. tostring(def.class) .. ")"
                        elseif def.price ~= nil then
                            bad[#bad + 1] = sinId .. "." .. rank .. ": " .. id .. " is priced"
                        end
                    end
                end
            end
            table.sort(bad)
            assert(#bad == 0, "a sin pays a creature's piece or a priced one:\n  " .. table.concat(bad, "\n  "))
        end,
    },
    {
        -- A TROPHY, NOT A WARE. The head of each list is the piece the body is known for, so it sits on
        -- its class's rack greyed as a monster drop and is never sold or bought back; `noSteal` is the other
        -- half -- you took it off the body, nothing takes it back. The queue behind it is ordinary found
        -- stock and is held to the rule above, not to this one.
        name = "a general's relic and a lieutenant's piece are unstocked trophies on their shelf",
        fn = function()
            for sinId, want in pairs(HEADS) do
                for i = 1, 2 do
                    local id, class = want[i], want[i + 2]
                    local def = Item.defs[id]
                    assert(def, id .. " does not exist")
                    if class then
                        assert(def.class == class, id .. " sits on " .. tostring(def.class) .. ", not "
                            .. class .. " (" .. sinId .. ")")
                        assert(def.unstocked, id .. " is not `unstocked`, so a counter would deal it")
                        assert(def.unlockLevel, id .. " has no depth, so its rack cannot show it")
                    end
                    assert(def.price == nil, id .. " is priced, so a shelf could sell it")
                    assert(def.noSteal, id .. " can be stolen off the body that took it")
                    local relic = false
                    for _, tag in ipairs(def.tags or {}) do if tag == "relic" then relic = true end end
                    assert(relic, id .. " is not tagged as a relic")
                end
            end
        end,
    },
    {
        -- THERE CAN NEVER BE CREATURE DROPS, asked of every body's own list too: Descent.DROPS is one of
        -- three routes a piece leaves a fight by (docs/drops.md), and the rule is about the drop, not the
        -- route. A creature that wants to fight with one of these wears a creature COPY and drops the
        -- real piece (the Marid's Flood beside the Marid's Tide).
        --
        -- A `bound` entry is skipped, and only because it is not a drop at all: a bound piece is sealed
        -- to its body and the payout refuses it (tests/boar_drops_spec.lua), so it is a dead row rather
        -- than a creature handed over. character_barrow_lord lists its own bound Turned Year that way.
        name = "no body's drop list names creature kit",
        fn = function()
            local bad = {}
            for id, def in pairs(Character.defs) do
                for _, entry in ipairs(def.drops or {}) do
                    local itemId = type(entry) == "table" and (entry.id or entry[1]) or entry
                    local item = itemId and Item.defs[itemId]
                    if item and isCreature(item) and not item.bound then bad[#bad + 1] = id .. " drops " .. itemId end
                end
            end
            table.sort(bad)
            assert(#bad == 0, "a body drops a creature's piece:\n  " .. table.concat(bad, "\n  "))
        end,
    },
    {
        -- A lieutenant's piece is a wearable sibling of a `natural` piece, and `natural` in this codebase
        -- means a body part. Handing the player the Gralloch Hook hands them an organ, which is why these
        -- exist at all -- so none of them may BE natural kit.
        name = "a lieutenant's piece is equipment, never the body part it was cut from",
        fn = function()
            for _, want in pairs(HEADS) do
                for _, tag in ipairs(Item.defs[want[2]].tags or {}) do
                    assert(tag ~= "natural", want[2] .. " is natural kit; a player cannot wear a body part")
                end
            end
        end,
    },
    {
        -- C1's rule: a general never hands over something the company already has, so a second
        -- playthrough is paid in pieces that playthrough has not seen. Walked here rather than trusted,
        -- because "already owned" spans the stash AND every grid and either half going quiet would look
        -- exactly like a generous payout.
        name = "a body pays the first piece not already carried, and nothing once the list is spent",
        fn = function()
            local wrath
            for _, sin in ipairs(Descent.SINS) do if sin.id == "wrath" then wrath = sin end end

            local p = Player.new()
            assert(Descent.dropFor(p, wrath, true) == "utility_the_broken_vow",
                "Furor pays his vow, not the blood he fights with")
            assert(Descent.dropFor(p, wrath, false) == "utility_anvils_face",
                "the Anvil pays its face")

            -- Held in the STASH... and what comes back is the NEXT unowned piece, not nothing. The list
            -- was one entry long when this case was written; the retired board's quest-only stock moved
            -- onto these bodies and made "the list is spent" a claim about a dozen pieces rather than one.
            Player.addToStash(p, Item.instantiate("utility_the_broken_vow"))
            local second = Descent.dropFor(p, wrath, true)
            assert(second and second ~= "utility_the_broken_vow",
                "a general handed over a second copy of something in the stash")
            assert(second == Descent.DROPS.wrath.general[2],
                "the walk skipped past the next piece in the list rather than paying it")

            -- ...and held in a GRID, which is the half that is easy to forget: a relic worn by the
            -- knight is not a relic the company is missing.
            local q = Player.new()
            q.roster[1].inventory = { [5] = Item.instantiate("utility_anvils_face") }
            assert(Descent.dropFor(q, wrath, false) == nil,
                "a lieutenant handed over a second copy of something somebody is wearing")
        end,
    },
    {
        -- EACH PIECE'S OWN RULE FIRES, which is the case that matters. A trait that merely LOADS is a
        -- trait reading a ctx field nobody sets, quietly doing nothing forever -- and three of these
        -- were exactly that when first written (the sworn status is `status_sworn`, the bite is not a
        -- status application at all, and enemy bodies carry no coin: `combat.purse` is the PARTY's
        -- bank). Each case below drives the real hook through real combat. Moving a piece onto a shelf
        -- changed none of its rules, and these are what say so.
        --
        -- Read back off `combat.units`, never off the spawn table: Combat.new builds its own units, so a
        -- spec holding the table it passed in watches a body that is not in the fight.
        name = "the Anvil's Face hardens on its own, and faster while the Mail is rising",
        fn = function()
            local Fixture = require("tests.support.fixture")
            local Combat = require("models.combat")

            local function armourAfter(blows, withMail)
                local items = { "utility_anvils_face" }
                if withMail then items[#items + 1] = "armor_mail_of_the_unappeased" end
                local combat = Fixture.combat(Fixture.new(8, 8),
                    { Fixture.unit("character_rowan", 2, 2,
                        { isolate = "bare", items = items, stats = { health = 400, defense = 0 } }) },
                    { Fixture.unit("character_bandit", 6, 6, {}) })
                local hero = combat.units[1]
                for _ = 1, blows do Combat.dealFlatDamage(combat, hero, 20, nil, "spec") end
                return (hero.bonus and hero.bonus.defense) or 0
            end

            local alone = armourAfter(4, false)
            assert(alone > 0, "the Face gives nothing on its own -- the baseline is dead")
            assert(alone <= 6, "the bare plate should stop at its cap, got " .. alone)

            local paired = armourAfter(4, true)
            assert(paired > alone,
                "the Mail's rage bought no extra armour (" .. paired .. " vs " .. alone ..
                ") -- the Face's own clause is not reading status_wrath")
        end,
    },
    {
        name = "the Unblown Horn hardens when its bearer binds a foe, and never for its own side",
        fn = function()
            local Fixture = require("tests.support.fixture")
            local Status = require("models.status")

            local combat = Fixture.combat(Fixture.new(8, 8),
                { Fixture.unit("character_rowan", 2, 2,
                    { isolate = "bare", items = { "utility_unblown_horn" } }),
                  Fixture.unit("character_rowan", 2, 3, { isolate = "bare" }) },
                { Fixture.unit("character_bandit", 3, 2, {}) })
            local hero, ally = combat.units[1], combat.units[2]
            local foe
            for _, u in ipairs(combat.units) do if u.side ~= hero.side then foe = u end end
            assert(foe, "the fixture put nobody on the other side")

            local before = (hero.bonus and hero.bonus.defense) or 0
            Status.apply(combat, foe, "status_poison", { applier = hero })
            local after = (hero.bonus and hero.bonus.defense) or 0
            assert(after > before,
                "binding a foe gave the watch nothing -- it is reading the wrong side of onStatusApplied")

            -- ...and never for its own party being cursed, which is the guard that makes it a reward
            -- rather than a consolation.
            Status.apply(combat, ally, "status_poison", { applier = hero })
            assert(((hero.bonus and hero.bonus.defense) or 0) == after,
                "the watch hardened for its own side being afflicted")
        end,
    },
    {
        name = "the Marginal Gloss returns mana when somebody else works a spell, and not for a swing",
        fn = function()
            local Fixture = require("tests.support.fixture")
            local Trait = require("models.trait")

            local combat = Fixture.combat(Fixture.new(8, 8),
                { Fixture.unit("character_mage", 2, 2,
                    { isolate = "bare", items = { "utility_marginal_gloss" } }) },
                { Fixture.unit("character_bandit", 5, 5, {}) })
            local hero, foe = combat.units[1], combat.units[2]

            local mana = hero.char.stats.mana
            assert(mana and (mana.max or 0) > 0, "this case needs a body with a mana pool")
            mana.current = 0
            Trait.onAnyCast(combat, foe, { item = {}, ability = { name = "spec spell" } })
            assert((mana.current or 0) > 0,
                "a spell worked nearby returned no mana -- onAnyCast is not reaching the gloss")

            -- A weapon swing is not a working, or this would be a flat per-turn refill.
            mana.current = 0
            Trait.onAnyCast(combat, foe, { item = {} })
            assert((mana.current or 0) == 0, "an ordinary swing paid the gloss")
        end,
    },
}
