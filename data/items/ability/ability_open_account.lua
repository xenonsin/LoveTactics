-- The Open Account: greed's defensive face, and the one shape the money kit did not have. The other
-- five all spend coin to make something HAPPEN -- Blood Money buys damage, The Gilded Wound buys a
-- wound outright, Grease Palms buys tempo, Skimmer's Cut and The Ledger's Due take rather than pay.
-- This one buys the only thing greed actually wants, which is not to be touched: while the account
-- stands, every wound
-- that gets past armor is settled out of the purse instead of the flesh, five coins to the point
-- (Combat.soakIntoPurse, via data/status/status_open_account.lua).
--
-- A TOGGLE, which is the whole design and not a convenience. Cast it and the account opens; cast it
-- again and it closes. It is the only shape the ability could have had: an account with a duration is a
-- ward you buy for a while, and the decision the item wants to put in front of the player is not "is
-- now the moment" but "how long am I willing to keep paying" -- a question you have to be able to
-- ANSWER, mid-fight, when the bank is thinner than you thought. So the closing cast is the real
-- mechanic, and the opening one is just how you get there. Compare data/items/ability/ability_blink.lua,
-- the game's other toggle, whose `Toggle:` description lead this borrows.
--
-- It flips at the cost of a cast (a self-target action, cheap in stamina and near-free in tempo at
-- speed 2, the same pricing Reckless Stance uses), NOT free like Blink's flip. Deliberate: Blink's
-- toggle spends its mana per jump, so an idle flip costs nothing and a free flip is honest. This one
-- would otherwise let you open the account the instant a blow is telegraphed and shut it the instant it
-- lands, which is a way to pay for nothing but the hits you were going to take anyway. Paying a turn on
-- each end is what makes leaving it open a commitment.
--
-- WHY IT IS THE ROGUE'S, and specifically the MAMMONITE's. The purse kit is the greed shelf's, and it is
-- the whole of the rogue's money subclass (data/disciplines/mammonite.lua) -- eight wares on one resource
-- nothing else in the game touches. It was this ability that tipped the kit over: an earlier call had it
-- stay base stock (docs/disciplines-plan.md, "the greed identity itself, not a deeper cut of it"), which
-- was right about the identity and wrong about the shelf. Gated at the end of the greed line like the
-- rest of the spending half -- on sale once all ten Undercroft quests are clear, which means Aurea is
-- beaten, two tiers past the discipline's own gate. This one is the most literally lifted of them all:
-- the gold ward IS her
-- fight (docs/story.md, "The gold, in numbers" -- damage dealt into her gold, not her flesh, and only a
-- purse at zero exposes the little behind it). You take the art off her body and then it is yours, with
-- the difference that her purse is a hoard and yours is the company's payroll.
--
-- WHAT FORGING BUYS, and it is not a discount. The rate is FLAT at five gold a point -- the shelf prices
-- a point of harm at five coins whichever direction it travels, which is exactly Blood Money's rate read
-- backwards, and a ward that got cheaper with the forge would end the game as a purse-shaped invincible.
-- What climbs is the CAP: how much of any single blow the account will cover. So a forged account
-- reaches further into each wound and therefore further into your bank -- a bigger appetite, not a
-- better price, the same thing Blood Money's forge buys. Anything past the cap lands on the flesh, so
-- this never protects against one enormous hit and always protects against twenty ordinary ones.
--
-- The cap is computed off `fx.level` in the effect rather than authored as a curve, the same way Blood
-- Money's pour and Grease Palms's are: it is not the ability's headline magnitude (the ability HAS no
-- damage and no heal to head its tooltip), so it has no tooltip row to feed, and the ability's own
-- `description` is where the player reads it. One point of coverage a level, which is the forge span
-- rule met exactly -- ten covered at base, twenty fully forged.
--
-- THE COUNTERPLAY IS THE BANK, and it needs no new rule to exist: the account is only as deep as your
-- gold, it pays for every blow whether or not the blow mattered, and it does not know the difference
-- between a boss and a rat chewing on you. Leave it open through a long fight and you will win the
-- fight and lose the shop. Outside the campaign there is no purse at all (a duel, a draft run --
-- states/battle.lua), so the toggle opens an account with nothing in it and covers nothing: inert, and
-- honest about it, exactly as the rest of the kit is.
return {
    name = "The Open Account",
    description = "Toggle: wounds are paid out of your purse at 5 gold a point, up to a cap per blow.",
    flavor = "She was never brave. She was solvent, which had always worked out to the same thing.",
    sprite = "assets/items/ability_open_account.png",
    type = "ability",
    tags = { "guile" }, -- the rogue's own word, so the shelf reads right; the purse is the header's business
    class = "rogue",
    discipline = "mammonite", -- deeper cut of the shelf: buyable only once the mammonite gate is cleared
    price = 340,
    -- Gated to the END of the greed line: on sale only once all ten Undercroft quests are cleared -- i.e.
    -- Aurea is beaten (slot 10). Her gold ward is the one piece of her fight this is a straight copy of.
    unlockQuests = 9,
    activeAbility = {
        target = "self", -- nobody else's account is yours to open, and nobody else's to close
        range = 0,
        speed = 2,      -- near-free in tempo, like Reckless Stance: the cost of this ability is what it does to your gold
        support = true, -- it lands no damage: it reads green, and the AI treats it as friendly
        cost = { stat = "stamina", amount = 3 },
        description = "Opens or closes the account: 5 gold covers 1 point of each wound, up to 10 points a blow.",
        effect = function(fx)
            -- The toggle. `hasStatus` is a truthful read even in a dry run (Combat.previewAbility's inert
            -- fx answers it against the real unit), so the hover panel shows the flip this cast would
            -- actually perform rather than always the opening one. Both branches mutate only through fx,
            -- so a preview neither opens nor closes anything -- the rule every effect keeps.
            if fx.hasStatus(fx.user, "status_open_account") then
                fx.clearStatus(fx.user, "status_open_account")
                -- Status.remove is the silent mechanism (only a natural expiry announces itself), and a
                -- toggle whose OFF state left no line in the log would be a rule the player had to
                -- remember having used. So the closing cast narrates itself.
                fx.log("status", string.format("%s closes the account.",
                    (fx.user.char and fx.user.char.name) or "Unit"), fx.user)
            else
                -- Ten points of coverage at base, one more a forge level (see the header). Status.apply
                -- writes the opening line for this branch, so only the close above needs narrating.
                fx.applyStatus(fx.user, "status_open_account", { magnitude = 10 + fx.level })
            end
        end,
    },
}
