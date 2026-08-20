-- The Gilded Wound: Aurea's own art, and the purest statement of the purse (see docs/classes.md on the
-- money kit, and models/combat.lua Combat.spendPurse). It carries no strength of its own -- pay gold, and
-- the gold becomes the wound, ten coins to the point. A confirm-time slider (ui/panels/spend_chooser.lua)
-- pops up on the aimed tile so you dial exactly how much of your fortune to spend on this one blow, the
-- way a chargeable signature raises the wind-up ladder. No randomness: coin in, damage out.
--
-- AUREA ALSO HAS IT. The general of Greed fights by being owed, and this is the shape of that on the board
-- -- she does not swing, she PRICES you, drawing on her own coffer (an enemy spends unit.coffer, not your
-- bank -- Combat.purseAvailable is side-aware). The player buys the same art off the rogue's shelf; greed's
-- weapon is the same in the hoard's hand and the cutpurse's. Her AI pours what it can afford up to the cap
-- each cast (models/ai.lua prices the blow it intends to buy), so a rich Aurea simply hits harder.
--
-- WHY IT IS GREED'S, and why coin is not a keyword: the same argument Blood Money's header makes. The
-- rogue's shelf IS greed, and greed's purest expression is a wallet, not a technique. `guile` keeps the
-- shelf reading right; the purse is the header's business, said out loud as the contract asks.
--
-- The `damage` table is all zeroes on purpose: the blow has no base at all, so every point of it is bought.
-- The effect overrides the amount from what the purse actually paid, and the zero table only keeps the
-- magnitude/tooltip readers (Combat.abilityMagnitude) happy without promising a single free point.

return {
    name = "The Gilded Wound",
    description = "Pay gold to carve a wound. Ten gold per point of damage, dialed at the swing.",
    flavor = "She never lifted a blade. She simply named what it would cost you, and you paid.",
    sprite = "assets/items/ability_gilded_wound.png",
    type = "ability",
    tags = { "physical", "guile" }, -- guile: the rogue's own word; the purse is the header's business (as on Blood Money)
    class = "rogue",
    discipline = "mammonite", -- a spender: the gate opens the shelf, this half completes it at quest 9
    price = 610,
    -- Gated to the END of the greed line: on sale only once all ten Undercroft quests are cleared --
    -- which means Aurea herself is beaten (slot 10). You do not buy the art of paying in another's blood
    -- until you have taken it off the one who owned it. `Vendor.stock` unlocks at questsDone >= 10.
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 3, -- greed reaches: it prices you from across the room, it does not close
        speed = 5,
        cost = { stat = "stamina", amount = 4 }, -- a token effort; the purse is the true cost
        -- The confirm-time money slider. `perDamage` gold buys one point; `max` caps a single cast so a
        -- fat purse cannot dial an unbounded blow (Item.purchaseRate, ui/panels/spend_chooser.lua).
        purchase = { perDamage = 10, max = 25 },
        damage = 0, -- no base: every point is paid for (see header)
        description = "Spend up to 250 gold; each 10 gold carves one point of damage into the target.",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- Ten gold per point (matches purchase.perDamage). fx.spend is the gold the chooser dialed --
            -- or, for Aurea, the gold her AI decided to pour. spendPurse draws it (clamped to what is truly
            -- on hand) and hands back what it took, so the wound is exactly what was paid for, never a coin
            -- more. Routed through fx.spendPurse so the damage preview prices it without emptying the purse.
            local paid = fx.spendPurse(fx.spend)
            if paid > 0 then
                -- FLAT, so the wound is exactly the coin: ten gold to the point, with none of the caster's
                -- own Power folded in (fx.flatDamage, not fx.damage). "No strength of its own" made literal.
                fx.flatDamage(t, math.floor(paid / 10), { "physical" })
            end
        end,
    },
}
