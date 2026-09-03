-- The PURSE: the player's campaign gold made spendable inside a fight, and the greed (rogue) money kit
-- built on it -- Blood Money (coin into damage) and Grease Palms (coin into a haste whose length you
-- buy). The invariants worth pinning (docs/classes.md on why a spend routes through fx; models/combat.lua
-- on the injected accessor):
--   * no purse injected (a duel, a draft run) -> the ability is inert: it spends nothing and lands its
--     authored floor
--   * a spend draws the real bank down by exactly what it poured, clamped to what is on hand
--   * the payoff scales with the coin actually spent
--   * a PREVIEW (Combat.previewAbility) reports the coin-boosted outcome WITHOUT draining the purse --
--     the one invariant a money ability shares with chi, the charge pools and the coatings

local Combat = require("models.combat")
local Status = require("models.status")
local Item = require("models.item")
local Discipline = require("models.discipline")
local Player = require("models.player")
local Fixture = require("tests.support.fixture")

-- THE MONEY KIT, named. Every ware that spends or banks campaign gold as a combat resource, and the one
-- shelf they all belong to (data/disciplines/mammonite.lua). Held as an explicit roster rather than
-- derived, because there is nothing in an item's DATA that says "this one touches the purse" -- the tell
-- is inside its effect body, which no sweep can read. So a new money item that forgets its tag cannot be
-- caught automatically; what this list catches is the other half of the same mistake, an existing one
-- quietly losing the tag. Adding to the kit means adding a line here on purpose.
local MONEY_KIT = {
    -- The spenders: gold out, as a resource (Combat.spendPurse).
    "ability_blood_money", "ability_gilded_wound", "ability_grease_palms", "ability_open_account",
    -- The earners: gold in (Combat.bounty and kin).
    "ability_ledgers_due", "ability_price_on_the_head", "utility_skimmers_cut", "armor_cutpurse_coat",
}

-- Inject a purse over a local gold cell, the way states/battle.lua injects one over Player.active.
-- Returns a reader so a case can assert what is left.
local function givePurse(combat, gold)
    local g = gold
    combat.purse = {
        get = function() return g end,
        spend = function(n) g = g - n end,
    }
    return function() return g end
end

-- One Blood Money strike into a defenceless dummy. `gold` nil means no purse at all. Returns the
-- damage dealt and (when a purse was given) its reader.
local function bloodMoney(gold)
    local map = Fixture.new(8, 8)
    local hero = Fixture.unit("character_saber", 2, 2,
        { isolate = "bare", items = { "ability_blood_money" }, stats = { stamina = 99 } })
    local foe = Fixture.unit("character_bandit", 2, 3,
        { isolate = "bare", stats = { defense = 0, health = 900 } })
    local combat = Fixture.combat(map, hero, foe)
    local h, f = combat.units[1], combat.units[2]
    local purse = gold and givePurse(combat, gold) or nil
    local hp = f.char.stats.health.current
    assert(Fixture.strike(combat, h, f, "ability_blood_money"), "Blood Money lands")
    return hp - f.char.stats.health.current, purse
end

return {
    {
        name = "no purse: Blood Money lands its floor and spends nothing (inert outside the campaign)",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_blood_money" }, stats = { stamina = 99 } })
            local foe = Fixture.unit("character_bandit", 2, 3,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            assert(Combat.purseAvailable(combat) == 0, "an uninjected combat has no purse")
            local hp = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, "ability_blood_money"), "the swing still lands")
            assert(hp - f.char.stats.health.current > 0, "for its floor, with no coin to add")
        end,
    },
    {
        name = "a purse turns coin into damage, and draws the bank down by what it poured",
        fn = function()
            local floor = bloodMoney(nil)
            local rich, purse = bloodMoney(100)
            assert(rich > floor, "the coin lands on top of the floor")
            assert(rich - floor == 20, "100g at 5g per point is +20 damage")
            assert(purse() == 0, "and the 100g is gone from the bank")
        end,
    },
    {
        name = "a thin wallet pours only what it holds, and no more",
        fn = function()
            local floor = bloodMoney(nil)
            local dmg, purse = bloodMoney(12)
            assert(purse() == 0, "all twelve coppers are spent")
            assert(dmg - floor == 2, "12g at 5g per point is +2 -- what little there was")
        end,
    },
    {
        name = "a preview reports the coin-boosted blow WITHOUT draining the purse",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_blood_money" }, stats = { stamina = 99 } })
            local foe = Fixture.unit("character_bandit", 2, 3,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            local item = Fixture.itemNamed(h.char, "ability_blood_money")
            local purse = givePurse(combat, 100)

            local preview = Combat.previewAbility(combat, h, item, f.x, f.y)
            assert(preview and preview.entries[f], "the dry run resolves a hit on the foe")
            local shown = preview.entries[f].damage
            assert(purse() == 100, "and it did NOT spend a single coin under the cursor")

            -- The number it showed is the one the live cast then lands: preview == reality.
            local hp = f.char.stats.health.current
            assert(Fixture.strike(combat, h, f, item), "the live cast lands")
            assert(hp - f.char.stats.health.current == shown, "for exactly what the preview promised")
            assert(purse() == 0, "and only NOW is the purse drawn down")
        end,
    },
    {
        name = "Grease Palms buys a longer haste the more coin it spends",
        fn = function()
            local function haste(gold)
                local map = Fixture.new(8, 8)
                local hero = Fixture.unit("character_saber", 2, 2,
                    { isolate = "bare", items = { "ability_grease_palms" }, stats = { stamina = 99 } })
                local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare" })
                local combat = Fixture.combat(map, hero, foe)
                local h = combat.units[1]
                local purse = gold and givePurse(combat, gold) or nil
                assert(Fixture.strike(combat, h, h, "ability_grease_palms"), "Grease Palms is cast on self")
                assert(Status.has(h, "status_hasted"), "and Hastes the payer")
                return Status.get(h, "status_hasted").remaining, purse
            end

            -- Read AFTER the cast, which has already elapsed a few ticks off the fresh haste -- the same
            -- few in both runs, since spending coin changes the damage/duration bought, never the tempo of
            -- the cast itself. So the absolute remaining is not the thing to pin; the DIFFERENCE is, and it
            -- is exactly the ticks the coin bought.
            local poor = haste(nil)          -- no purse: the floor, less the cast's own elapse
            local rich, purse = haste(60)    -- +60/3 = +20 ticks over the floor, same elapse
            assert(rich > poor, "coin is what lengthens the haste")
            assert(rich - poor == 20, "60g at 3g per tick buys exactly twenty more ticks of it")
            assert(purse() == 0, "and the 60g is spent to do it")
        end,
    },

    -- THE GILDED WOUND: the chooser-driven, flat pay-to-damage ability (Aurea's, and the rogue's) --------
    {
        name = "The Gilded Wound is purchasable at ten gold a point, capped at twenty-five",
        fn = function()
            local ab = Item.instantiate("ability_gilded_wound").activeAbility
            assert(Item.isPurchasable(ab), "it declares a purchase")
            local rate, cap = Item.purchaseRate(ab)
            assert(rate == 10 and cap == 25, "ten gold a point, twenty-five points a cast")
        end,
    },
    {
        name = "The Gilded Wound spends the party purse for exactly paid/10 FLAT damage",
        fn = function()
            local map = Fixture.new(8, 8)
            -- A big Power stat and a defended target, to prove NEITHER moves the number: it is pure coin.
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_gilded_wound" }, stats = { stamina = 99, damage = 50 } })
            local foe = Fixture.unit("character_bandit", 2, 3,
                { isolate = "bare", stats = { defense = 20, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            local item = Fixture.itemNamed(h.char, "ability_gilded_wound")
            local purse = givePurse(combat, 300)
            local hp = f.char.stats.health.current
            Fixture.openTurn(combat, h)
            assert(Combat.useItem(combat, h, item, f.x, f.y, nil, nil, 200), "the wound is paid for")
            assert(purse() == 100, "200g is drawn from the party bank")
            assert(hp - f.char.stats.health.current == 20,
                "exactly twenty points -- bought, not swung: the 50 Power and 20 defense both stay out of it")
        end,
    },
    {
        name = "an enemy caster (Aurea) spends its OWN coffer, and leaves the party's purse alone",
        fn = function()
            local map = Fixture.new(8, 8)
            local victim = Fixture.unit("character_saber", 2, 2, { isolate = "bare", stats = { health = 900, defense = 5 } })
            local aurea = Fixture.unit("character_bandit", 2, 3,
                { isolate = "bare", items = { "ability_gilded_wound" }, stats = { stamina = 99 } })
            aurea.char.coffer = 200 -- a walking treasury: Combat.addUnit reads char.coffer onto the unit
            local combat = Fixture.combat(map, victim, aurea)
            local v, a = combat.units[1], combat.units[2]
            local partyPurse = givePurse(combat, 500)
            local item = Fixture.itemNamed(a.char, "ability_gilded_wound")
            local hp = v.char.stats.health.current
            Fixture.openTurn(combat, a)
            assert(Combat.useItem(combat, a, item, v.x, v.y, nil, nil, 150), "Aurea prices the victim")
            assert(a.coffer == 50, "she spends her own coffer (200 - 150)")
            assert(partyPurse() == 500, "and the party's bank is untouched")
            assert(hp - v.char.stats.health.current == 15, "150g at 10g/point is 15 flat damage")
        end,
    },
    -- THE OPEN ACCOUNT: the kit's defensive face -- coin spent to NOT be touched --------------------
    {
        name = "The Open Account is a toggle: one cast opens the account, the next closes it",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_open_account" }, stats = { stamina = 99 } })
            local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            assert(Fixture.strike(combat, h, h, "ability_open_account"), "the account opens")
            assert(Status.has(h, "status_open_account"), "and the bearer is on account")
            -- Ten points of a single blow at base, one more a forge level -- the cap the granter tunes,
            -- against the rate the rule owns (data/status/status_open_account.lua).
            assert(Status.get(h, "status_open_account").magnitude == 10, "ten points of cover at level 0")

            assert(Fixture.strike(combat, h, h, "ability_open_account"), "the second cast is accepted")
            assert(not Status.has(h, "status_open_account"),
                "and it CLOSES the account -- the closing cast is the real mechanic, not a re-open")
        end,
    },
    {
        name = "an open account settles the wound out of the purse at five gold a point",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_open_account" }, stats = { stamina = 99, defense = 0 } })
            local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            local purse = givePurse(combat, 500)
            assert(Fixture.strike(combat, h, h, "ability_open_account"), "the account opens")

            local hp = Fixture.hp(h)
            local dealt = Combat.dealFlatDamage(combat, h, 8, { "physical" }, "test", f)
            assert(dealt == 0, "nothing reached the body -- the blow was paid for, not survived")
            assert(Fixture.hp(h) == hp, "the flesh is untouched")
            assert(purse() == 460, "and eight points cost forty gold, at five a point")
        end,
    },
    {
        name = "the cap is per BLOW: the overflow lands on the flesh, so no purse buys off one huge hit",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_open_account" }, stats = { stamina = 99, defense = 0 } })
            local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            local purse = givePurse(combat, 9999)
            assert(Fixture.strike(combat, h, h, "ability_open_account"), "the account opens")

            -- 30 points against a cap of 10: the account covers its ten and no more, however fat the bank.
            local dealt = Combat.dealFlatDamage(combat, h, 30, { "physical" }, "test", f)
            assert(dealt == 20, "twenty points past the cap land as an ordinary wound")
            assert(purse() == 9999 - 50, "and only the covered ten were billed")
        end,
    },
    {
        name = "no purse (a duel, a draft run): the account is inert and the blow lands whole",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_open_account" }, stats = { stamina = 99, defense = 0 } })
            local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            assert(Fixture.strike(combat, h, h, "ability_open_account"), "the account still opens")
            assert(Combat.purseAvailable(combat, h) == 0, "but there is no bank behind it")
            assert(Combat.dealFlatDamage(combat, h, 8, { "physical" }, "test", f) == 8,
                "so the blow lands whole -- inert, and honest about it")
        end,
    },
    {
        name = "a thin bank covers what it can afford and no more -- you do not beat the account, you empty it",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_open_account" }, stats = { stamina = 99, defense = 0 } })
            local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            local purse = givePurse(combat, 22) -- four points' worth, with two coppers over
            assert(Fixture.strike(combat, h, h, "ability_open_account"), "the account opens")

            assert(Combat.dealFlatDamage(combat, h, 8, { "physical" }, "test", f) == 4,
                "four points bought, four points felt -- the dregs round DOWN, never a free half-point")
            assert(purse() == 2, "the two coppers that could not buy a point stay in the bank")
            assert(Combat.dealFlatDamage(combat, h, 8, { "physical" }, "test", f) == 8,
                "and an emptied account covers nothing at all")
        end,
    },
    {
        name = "an enemy on account settles out of its OWN coffer, never the party's bank",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2, { isolate = "bare" })
            local aurea = Fixture.unit("character_bandit", 2, 3,
                { isolate = "bare", items = { "ability_open_account" },
                  stats = { stamina = 99, defense = 0, health = 900 } })
            aurea.char.coffer = 200
            local combat = Fixture.combat(map, hero, aurea)
            local h, a = combat.units[1], combat.units[2]
            local partyPurse = givePurse(combat, 500)
            assert(Fixture.strike(combat, a, a, "ability_open_account"), "she opens her own account")

            assert(Combat.dealFlatDamage(combat, a, 6, { "physical" }, "test", h) == 0, "the blow is billed")
            assert(a.coffer == 170, "to her coffer (200 - 30)")
            assert(partyPurse() == 500, "and the party's bank is untouched")
        end,
    },
    {
        name = "a preview prices a purchasable blow at the intended spend, without paying a coin",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_gilded_wound" }, stats = { stamina = 99 } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare", stats = { defense = 0, health = 900 } })
            local combat = Fixture.combat(map, hero, foe)
            local h, f = combat.units[1], combat.units[2]
            local item = Fixture.itemNamed(h.char, "ability_gilded_wound")
            local purse = givePurse(combat, 300)

            -- No spend named (a bare player hover): the board buys nothing, so there is no hit to record.
            local plain = Combat.previewAbility(combat, h, item, f.x, f.y)
            assert(not plain.entries[f] or (plain.entries[f].damage or 0) == 0, "an un-priced hover buys nothing")
            -- Priced at 120g (what the AI would pass): 12 damage shown, and the purse untouched.
            local priced = Combat.previewAbility(combat, h, item, f.x, f.y, nil, nil, 120)
            assert(priced.entries[f].damage == 12, "priced at 120g the preview shows twelve")
            assert(purse() == 300, "and previewing spent not a coin")
        end,
    },

    -- THE OPEN ACCOUNT: the toggle that pays wounds out of the purse instead of the flesh -------------
    {
        name = "The Open Account is a TOGGLE: one cast opens it, the next closes it",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", items = { "ability_open_account" }, stats = { stamina = 99 } })
            local foe = Fixture.unit("character_bandit", 6, 6, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]

            assert(Fixture.strike(combat, h, h, "ability_open_account"), "the account opens")
            assert(Status.has(h, "status_open_account"), "and the bearer carries it")
            assert(Fixture.strike(combat, h, h, "ability_open_account"), "the same cast again")
            assert(not Status.has(h, "status_open_account"), "closes it -- a toggle, not a refresh")
        end,
    },
    {
        name = "an open account settles the wound out of the purse at 5 gold a point, and spares the body",
        fn = function()
            local map = Fixture.new(8, 8)
            local victim = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, victim, foe)
            local v = combat.units[1]
            local purse = givePurse(combat, 500)
            -- Applied directly (rather than cast) so the case pins the RULE, not the ability that flips it.
            Status.apply(combat, v, "status_open_account", { magnitude = 10 })

            local hp = v.char.stats.health.current
            assert(Combat.dealFlatDamage(combat, v, 8, { "physical" }) == 0,
                "a blow inside the cap draws no blood at all")
            assert(v.char.stats.health.current == hp, "the flesh is untouched")
            assert(purse() == 460, "and the eight points cost forty gold")
        end,
    },
    {
        name = "the cap is per blow: what the account will not cover lands on the flesh",
        fn = function()
            local map = Fixture.new(8, 8)
            local victim = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, victim, foe)
            local v = combat.units[1]
            local purse = givePurse(combat, 500)
            Status.apply(combat, v, "status_open_account", { magnitude = 10 })

            local hp = v.char.stats.health.current
            local dealt = Combat.dealFlatDamage(combat, v, 30, { "physical" })
            assert(dealt == 20, "ten of the thirty are bought off; the other twenty land, got " .. dealt)
            assert(hp - v.char.stats.health.current == 20, "and that is what the body actually takes")
            assert(purse() == 450, "ten points billed at 5g is fifty gold -- never more than the cap")
        end,
    },
    {
        name = "an empty bank wards nothing -- you do not beat an account, you bankrupt it",
        fn = function()
            local map = Fixture.new(8, 8)
            local victim = Fixture.unit("character_saber", 2, 2,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, victim, foe)
            local v = combat.units[1]
            Status.apply(combat, v, "status_open_account", { magnitude = 10 })

            -- No purse at all (a duel, a draft run): the toggle is inert and the blow simply lands.
            assert(Combat.soakIntoPurse(combat, v, 8) == 0, "no purse covers nothing")

            -- A bank with 12g in it covers two whole points and not the third: the dregs round DOWN.
            local purse = givePurse(combat, 12)
            assert(Combat.soakIntoPurse(combat, v, 8) == 2, "12g at 5g a point buys exactly two")
            assert(purse() == 2, "and leaves the two coppers that could not buy a third")
            assert(Combat.soakIntoPurse(combat, v, 8) == 0, "broke, it covers nothing further")
        end,
    },
    {
        name = "an enemy's account draws on its OWN coffer, and leaves the party's bank alone",
        fn = function()
            local map = Fixture.new(8, 8)
            local hero = Fixture.unit("character_saber", 2, 2, { isolate = "bare" })
            local aurea = Fixture.unit("character_bandit", 2, 3,
                { isolate = "bare", stats = { defense = 0, health = 900 } })
            aurea.char.coffer = 200 -- a walking treasury, as in the Gilded Wound case above
            local combat = Fixture.combat(map, hero, aurea)
            local a = combat.units[2]
            local partyPurse = givePurse(combat, 500)
            Status.apply(combat, a, "status_open_account", { magnitude = 10 })

            local hp = a.char.stats.health.current
            assert(Combat.dealFlatDamage(combat, a, 6, { "physical" }) == 0, "her gold takes the blow")
            assert(a.char.stats.health.current == hp, "not her flesh")
            assert(a.coffer == 170, "six points off her own coffer at 5g")
            assert(partyPurse() == 500, "and the party's bank is untouched")
        end,
    },
    {
        name = "the mana shield is spent before the purse is billed",
        fn = function()
            local map = Fixture.new(8, 8)
            -- Both wards at once: the Mana Shield (item) and an open account (status).
            local knight = Fixture.unit("character_knight", 2, 2,
                { isolate = "bare", items = { "utility_mana_shield" },
                  stats = { defense = 0, health = 900, mana = 5 } })
            local foe = Fixture.unit("character_bandit", 2, 3, { isolate = "bare" })
            local combat = Fixture.combat(map, knight, foe)
            local k = combat.units[1]
            k.char.stats.mana.current = 5
            local purse = givePurse(combat, 500)
            Status.apply(combat, k, "status_open_account", { magnitude = 10 })

            local hp = k.char.stats.health.current
            assert(Combat.dealFlatDamage(combat, k, 8, { "physical" }) == 0, "between them the blow is covered")
            assert(k.char.stats.health.current == hp, "and nothing reaches the body")
            assert(k.char.stats.mana.current == 0, "the renewable pool goes first, all five points of it")
            assert(purse() == 485, "and only the remaining three are billed -- 15g, not 40g")
        end,
    },

    -- THE MAMMONITE: the shelf the whole kit lives on ------------------------------------------------
    {
        name = "every money item is on the Mammonite shelf, and the Mammonite is a rogue subclass",
        fn = function()
            for _, id in ipairs(MONEY_KIT) do
                local def = Item.defs[id]
                assert(def, id .. " is named in the money kit but does not exist")
                assert(def.class == "rogue", id .. " left the rogue shelf")
                assert(def.discipline == "mammonite",
                    id .. " spends or banks the purse but is not tagged mammonite -- the money kit is one"
                        .. " shelf (data/disciplines/mammonite.lua), not eight loose wares")
            end

            -- One parent, so a subclass rather than a multiclass -- which is what makes its gate a single
            -- quest in its own line rather than earned advancement across two.
            assert(Discipline.arity("mammonite") == 1, "the Mammonite is a subclass (one parent)")
            assert(Discipline.parents("mammonite")[1] == "rogue", "and its parent is the rogue")
        end,
    },
    {
        -- THE GATE IS A ROGUE LEVEL NOW, and the shape of the claim is unchanged.
        --
        -- It used to be Quarter-End, the Undercroft's sixth job, chosen because it sat BETWEEN the two
        -- halves of the Mammonite's kit: the earners already on sale by then, the spenders still two
        -- rungs off. Nobody runs a house's line any more (models/errand.lua), so the gate is the rogue
        -- level the discipline is authored against -- and what is pinned is still the ORDERING, read off
        -- the blueprint rather than typed, so retuning either half stays free.
        name = "the Mammonite's earners are on sale at its gate, and its spenders wait past it",
        fn = function()
            local p = Player.new()
            for _, c in ipairs(p.roster) do c.technique = {} end
            assert(not Discipline.isUnlocked(p, "mammonite"), "a fresh company has not earned it")

            local rung = Discipline.defs.mammonite.requiredLevel.rogue
            assert(rung, "the Mammonite gates on a rogue level")

            -- One body standing at that rung opens it, which is the per-body rule: a crossing is
            -- somebody who went that way, not a company that between them did.
            p.roster[1].technique = { rogue = Discipline.classLevelCost(rung) }
            assert(Discipline.isUnlocked(p, "mammonite"), "rogue " .. rung .. " is the gate")

            local function gate(id) return Item.defs[id].unlockQuests or 0 end
            for _, id in ipairs({ "ability_ledgers_due", "ability_price_on_the_head" }) do
                assert(gate(id) <= rung, id .. " is an earner: it must already be buyable at the gate")
            end
            for _, id in ipairs({ "ability_blood_money", "ability_gilded_wound",
                                  "ability_grease_palms", "ability_open_account" }) do
                assert(gate(id) > rung, id .. " spends the purse: it is Aurea's art, and waits for her")
            end
        end,
    },
}
