-- Clem's signature, and the counterplay to Aurea written as tempo (docs/story.md, "The Undercroft").
-- Time is money, and she gives it away. Where the general BUYS time -- every summon and action she pays
-- for out of her hoard -- Clem MINTS it and hands it to the party, keeping none.
--
-- A blade, like Saber's First Motion, so the killer's own tool sits at the grid's centre (never a
-- cleanse, which is the priest's verb, not the rogue's). Two parts, the way Rowan's Aegis and Kaya's
-- Horn are:
--
--   * THE MERCY-STROKE (always available): a coup on a wounded foe -- her name in a verb (clementia ->
--     coup de grace) -- that lands harder the closer the target is to the ground.
--   * THE JUBILEE (earned): collect three kills and the same stroke also QUICKENS the whole party
--     (status_hasted). Her lethality is everyone's tempo; she keeps none of the haste for herself.
--
-- A WEAPON ALWAYS SWINGS, which is why the three kills gate the HASTE and not the blade. This used to
-- carry an `unlock` (Combat.unlockMet / itemBlockReason) the way the Sworn Aegis, the Ledger and the
-- Wolfsong Horn do -- and it was the only weapon in the game that did. Those three are armor, a utility
-- and a utility: a greyed-out slot costs their bearer an option. A greyed-out WEAPON slot costs its
-- bearer the thing a weapon is for, for the whole opening of every fight, and again after every use
-- (the unlock was repeatable, so it re-locked on each swing). Saber's First Motion is the tell -- the
-- one other signature that lives in a weapon slot, and it carries no gate at all.
--
-- So the count became a READOUT rather than a purse: `counter` + `counterGates = false`, the same pair
-- weapon_long_count and weapon_reapers_due wear. The slot draws "Collected: n" and never greys, the
-- tooltip quotes it, and the effect below reads the same number to decide whether the jubilee fires.
-- Three collected are SPENT when it does (banked on the bearer via fx.bank, battle-scoped exactly as
-- the old unlock baseline was), and any surplus is kept rather than discarded -- a purse with change.
--
-- The base array is a full dagger's (compare weapon_iron_dagger's 5-15) rather than the marquee 12-27
-- it swung for while it was gated: a swing you no longer have to earn cannot be paid for as if you had.
-- The coup is upside on top of it and the jubilee is the payoff, so nothing about the blade is a
-- punishment -- it is simply an honest dagger until she has collected, and the party's tempo after.
-- The 8 stamina STAYS, and that is what keeps her authored loop intact: the kris is the cheap softener
-- at 5, this is the deliberate finisher, and the poison is still why you open with the other hand.
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. No `price`;
-- `class = "rogue"` still tallies rogue growth.
local Curve = require("models.curve")

-- Kills collected per jubilee. Spent, not reset: collect a fourth before spending and it carries.
local MERCY = 3

-- What she has collected since the last jubilee: her battle `kill` tally less what the last one spent.
-- Pure -- safe for the slot badge, the tooltip and the AI, all of which ask it every frame.
local function collected(unit)
    if not unit then return 0 end
    return math.max(0, require("models.combat").tallyCount(unit, "kill") - (unit.mercySpent or 0))
end

return {
    name = "Borrowed Time",
    description = "Increase damage by 0.6% per 1% of the foe's missing health. At three kills collected, grants the party Haste.",
    flavor = "Time is money, and she is the one debtor in the city who gives it away. She keeps none of it.",
    sprite = "assets/items/sig_borrowed_time.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee", "signature" },
    bound = true,
    class = "rogue",
    activeAbility = {
        description = "Increase damage by 0.6% per 1% of the foe's missing health. At three kills collected, grants the whole party Haste.",
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(5, 16),
        -- The count made visible, exactly as weapon_reapers_due wears its kill tally: the same number
        -- the effect below reads, drawn on the slot and quoted in the tooltip, so the player can see the
        -- jubilee coming instead of holding the total in their head.
        --
        -- `counterGates = false`: an empty count is an ordinary stroke, not a spent purse. The blade
        -- swings fine at zero -- that is the whole point of it no longer being an `unlock`.
        counter = function(unit) return collected(unit) end,
        counterGates = false,
        counterLabel = "Collected",
        effect = function(fx)
            -- Read BEFORE the blow lands, so the swing settles against the same number the badge showed
            -- when the player clicked it -- a kill taken by this very stroke counts toward the NEXT one.
            local banked = collected(fx.user)
            -- The coup: it lands harder the closer the foe is to the ground (the mercy-stroke finds the
            -- opening the party's poison already opened -- the inverse of Saber's front-load).
            local hp = fx.target and fx.target.char.stats.health
            local frac = (hp and hp.max and hp.max > 0) and ((hp.current or 0) / hp.max) or 1
            local coup = math.floor(fx.amount * 0.6 * (1 - frac))
            fx.damage(fx.target, { amount = fx.amount + coup })
            -- The jubilee: she spends the three on everyone, and keeps none of it. Banked through
            -- fx.bank rather than written onto fx.user, so the two damage previews replay this effect
            -- against an inert bank and a hover never spends her collection (models/combat.lua).
            if banked >= MERCY then
                fx.bank("mercySpent", (fx.user.mercySpent or 0) + MERCY)
                for _, u in ipairs(fx.combat.units) do
                    if u.alive and u.side == fx.user.side then fx.applyStatus(u, "status_hasted") end
                end
            end
        end,
    },
}
