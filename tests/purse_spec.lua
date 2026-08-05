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
local Fixture = require("tests.support.fixture")

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
}
