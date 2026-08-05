-- Flurry: three bare-handed blows in the time most people throw one. The Monk shelf's FIRST active --
-- until this, the discipline was four passive fist charms (Iron, Shadow, Swift, Drunken) stacking
-- `unarmedBonus` and nothing to spend it on, which is why it was the one shelf a player could not
-- actually *press a button* on.
--
-- It strikes with the bearer's own fists rather than rolling its own damage, and that is the whole
-- design: every sub-strike runs the hidden unarmed weapon (Combat.strikeWith), so the fist charms in
-- the grid are folded into all three of them. A monk who has bought the charms punches three times as
-- hard here as one who has not, without this file knowing anything about them.
--
-- CHI (Combat.chi) is the gate: three banked unarmed blows opens it, and casting spends three. The
-- flurry's own blows bank chi BACK as they land, which is deliberate rather than an oversight -- Flurry
-- is the monk's rhythm, roughly chi-neutral and limited by stamina and the turn, while the Asura Strike
-- (data/items/ability/ability_asura_strike.lua) is the dump that ends it. One keeps the cycle turning;
-- the other cashes it out.
--
-- The gate is a pure `when` predicate rather than a counted unlock on purpose: a counted one keeps a
-- PER-ITEM baseline (Combat.unlockSpend), which would give Flurry and Asura Strike separate charges and
-- make "your chi" mean a different pool in each file. A `when` gate reads the shared pool and re-locks
-- nothing, leaving the spend to the effect where it belongs.
return {
    name = "Flurry",
    description = "Throws three bare-handed strikes in one motion. Consume 3 chi.",
    flavor = "The Cathedral counts prayers. The ascetic counts knuckles, and arrives at the same number.",
    sprite = "assets/items/ability_flurry.png",
    type = "ability",
    tags = { "fist", "physical" },
    class = "priest",
    discipline = "monk", -- deeper cut of the shelf: buyable only once the monk gate is cleared
    price = 300,
    unlockQuests = 7,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 6 },
        -- Names the pool it spends so the slot and the tooltip quote the monk's chi (Combat.itemChargeKey).
        -- A pool-spender normally declares the pool with `charge`, but chi's source is the BODY rather
        -- than anything you can buy (Combat.CHARGE_DEFS), so there is nothing here to declare -- only to
        -- read. Without this the ability asks you to decide about a number you cannot see.
        spendsCharge = "chi",
        unlock = {
            when = function(unit) return require("models.combat").chi(unit) >= 3 end,
            text = "Gather 3 chi",
        },
        description = "Consume 3 chi to throw three bare-handed strikes, each scaled by your fist charms.",
        effect = function(fx)
            fx.spendChi(3)
            local fists = fx.user.char and fx.user.char.unarmed
            if not fists then return end -- a body with no hands to throw is not a case, but cost nothing
            for _ = 1, 3 do fx.strikeWith(fists) end
        end,
    },
}
