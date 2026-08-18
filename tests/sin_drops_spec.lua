-- WHAT A SIN PAYS FOR BEING PUT DOWN: the fourteen pieces of models/descent.lua's DROPS, and the rule
-- that makes each circle a two-piece SET rather than two unrelated objects.
--
-- THE SET RULE IS SYNERGY. A general's relic creates a condition -- rage on you, health above where the
-- fight left it, a foe drained empty, a stolen item in your grid, a copy standing beside you, an oath on
-- the whole enemy party, a spell in the air -- and her lieutenant's piece reads exactly that condition
-- and cashes it. Each also carries a baseline that works with its partner still underground, so nothing
-- here is dead weight in a stash.
--
-- The design was authored long before the wiring. data/items/armor/armor_mail_of_the_unappeased.lua has
-- always said it outright -- "the payment for a general, and the shape every one of the seven relics
-- takes -- kill a sin, wear it" -- while what a circle actually paid was a SHOP DOOR, a patch applied
-- when the Quest Board was retired and seven houses could no longer open. The door opens on an errand
-- now (tests/hub_spec.lua) and the body pays what it was carrying.
--
-- Every id here is named literally rather than walked out of the table, because tests/item_coverage_spec
-- reads test files as text: a table-walk exercises the items and covers none of them.

local Descent = require("models.descent")
local Item = require("models.item")
local Player = require("models.player")
local Trait = require("models.trait")

-- sin -> { general relic, lieutenant's mirror, the trait the mirror carries }
local SET = {
    gluttony = { "utility_maw_of_the_unfed",     "utility_larder_hook",    "trait_larder" },
    lust     = { "utility_reliquary_unbidden",   "utility_beggars_bowl",   "trait_beggars_due" },
    greed    = { "utility_bottomless_purse",     "utility_tally_stick",    "trait_assayers_tally" },
    envy     = { "utility_envious_glass",        "utility_second_vessel",  "trait_covetous_eye" },
    wrath    = { "armor_mail_of_the_unappeased", "utility_anvils_face",    "trait_anvil_face" },
    sloth    = { "weapon_forsworn_pike",         "utility_unblown_horn",   "trait_kept_watch" },
    pride    = { "utility_codex_unanswered",     "utility_marginal_gloss", "trait_glossed" },
}

return {
    {
        -- The table above IS the assertion: if a sin's payment is renamed or re-pointed, this file must
        -- be edited to match, which is the point of naming all fourteen by hand.
        name = "every circle pays a general's relic and its lieutenant's mirror, by name",
        fn = function()
            for _, sin in ipairs(Descent.SINS) do
                local want = SET[sin.id]
                assert(want, sin.id .. " has no expected drop set in this spec")
                local got = Descent.DROPS[sin.id]
                assert(got, sin.id .. " has no drop set in Descent.DROPS")
                assert(got.general[1] == want[1],
                    sin.id .. "'s general pays " .. tostring(got.general[1]) .. ", expected " .. want[1])
                assert(got.minor[1] == want[2],
                    sin.id .. "'s lieutenant pays " .. tostring(got.minor[1]) .. ", expected " .. want[2])
            end
        end,
    },
    {
        -- "No class and no price: no vendor stocks it, no shelf can replace it. There is one." A priced
        -- drop would put a sin's payment on a shelf, which is the one thing these fourteen are for not
        -- being. `noSteal` is the other half: you took it off the body, nothing takes it back.
        name = "a sin's payment is unpriced, classless and unstealable",
        fn = function()
            for _, set in pairs(SET) do
                for i = 1, 2 do
                    local id = set[i]
                    local def = Item.defs[id]
                    assert(def, id .. " does not exist")
                    assert(def.price == nil, id .. " is priced, so a shelf could sell it")
                    assert(def.class == nil, id .. " has a class, so a house's shelf would claim it")
                    assert(def.noSteal, id .. " can be stolen off the body that took it")
                    local relic = false
                    for _, tag in ipairs(def.tags or {}) do if tag == "relic" then relic = true end end
                    assert(relic, id .. " is not tagged as a relic")
                end
            end
        end,
    },
    {
        -- SYNERGY, NOT A SMALLER COPY. These began as cut-down versions of each general's rule -- a
        -- capped damage ramp beside an uncapped one -- which stack and never interact. Every mirror now
        -- reads a condition its general's relic CREATES and pays off when that relic fires, on top of a
        -- baseline that works with the partner still underground.
        name = "a lieutenant's mirror carries the trait that reads its general's rule",
        fn = function()
            for sinId, set in pairs(SET) do
                local def = Item.defs[set[2]]
                local carried = false
                for _, t in ipairs(def.traits or {}) do if t == set[3] then carried = true end end
                assert(carried, set[2] .. " does not carry " .. set[3] ..
                    ", so " .. sinId .. "'s lieutenant taught something its drop does not do")
                assert(Trait.defs[set[3]], set[3] .. " is not a real trait")
            end
        end,
    },
    {
        -- A mirror is a wearable sibling of a `natural` piece, and `natural` in this codebase means a
        -- body part. Handing the player the Gralloch Hook hands them an organ, which is why these seven
        -- exist at all -- so none of them may BE natural kit.
        name = "a mirror is equipment, never the body part it was cut from",
        fn = function()
            for _, set in pairs(SET) do
                for _, tag in ipairs(Item.defs[set[2]].tags or {}) do
                    assert(tag ~= "natural", set[2] .. " is natural kit; a player cannot wear a body part")
                end
            end
        end,
    },
    {
        -- C1's rule: a general never hands over something the company already has, so a second
        -- playthrough is paid in pieces that playthrough has not seen. Walked here rather than trusted,
        -- because "already owned" spans the stash AND every grid and either half going quiet would look
        -- exactly like a generous payout.
        name = "a body pays the first piece not already carried, and nothing once the set is spent",
        fn = function()
            local wrath
            for _, sin in ipairs(Descent.SINS) do if sin.id == "wrath" then wrath = sin end end

            local p = Player.new()
            assert(Descent.dropFor(p, wrath, true) == "armor_mail_of_the_unappeased",
                "Ira pays her mail, not the heart she fights with")
            assert(Descent.dropFor(p, wrath, false) == "utility_anvils_face",
                "the Anvil pays its face")

            -- Held in the STASH...
            Player.addToStash(p, Item.instantiate("armor_mail_of_the_unappeased"))
            assert(Descent.dropFor(p, wrath, true) == nil,
                "a general handed over a second copy of something in the stash")

            -- ...and held in a GRID, which is the half that is easy to forget: a relic worn by the
            -- knight is not a relic the company is missing.
            local q = Player.new()
            q.roster[1].inventory = { [5] = Item.instantiate("utility_anvils_face") }
            assert(Descent.dropFor(q, wrath, false) == nil,
                "a lieutenant handed over a second copy of something somebody is wearing")
        end,
    },
    {
        -- THE SYNERGY ACTUALLY FIRES, which is the case that matters. A trait that merely LOADS is a
        -- trait reading a ctx field nobody sets, quietly doing nothing forever -- and three of these
        -- were exactly that when first written (the sworn status is `status_sworn`, the bite is not a
        -- status application at all, and enemy bodies carry no coin: `combat.purse` is the PARTY's
        -- bank). Each case below drives the real hook through real combat.
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
                ") -- the synergy term is not reading status_wrath")
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
