-- Ansel's bound relic (Apothecary). He hands over whatever he has more of.
--
-- IT PAYS OFF WHAT HE ALREADY DOES rather than giving him a new verb. An earlier draft swapped the
-- party's stats for his wounds, which is a different character's trick entirely. This doubles his own:
-- for the rest of the fight every heal he casts also lends its number back as a ward, so a turn spent
-- mending is a turn spent armouring, permanently.
--
-- THE CENSUS IS THREE ALLIES CARRYING WHAT HE LENT, which makes his ordinary turn the gate. Transfusion
-- and The Shared Ledger are what put lent guard on three bodies in the first place; The Tithe copies
-- their buffs back onto him, so the better the party he keeps, the better the thing he has to lend.
--
-- Coveted Blood makes the party's hits bite while they carry it -- which is worth saying because it is
-- the envy half of an apothecary: everything here is somebody else's quality, borrowed.
return {
    name = "The Open Ward",
    description = "For the rest of the fight, every heal you cast also lends its number back as a ward.",
    flavor = "The ward is always open. It is the only thing about him that is.",
    sprite = "assets/items/sig_open_ward.png",
    type = "utility",
    tags = { "signature", "holy" },
    class = "priest",
    discipline = "apothecary",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "mana", amount = 10 },
        description = "Your heals also lend guard, and your side is warded now.",
        unlock = {
            field = { of = "unit", side = "ally", status = "status_lent_guard", count = 3 },
            text = "3 allies carrying what you lent",
        },
        effect = function(fx)
            -- The standing rule first: `lendsGuard` is the flag Combat's heal path already reads (see
            -- the note beside fx.heal), so from here on every mend he casts lends as well. Banked
            -- through fx.bank, which the damage preview replays inertly.
            fx.bank("lendsGuard", true)
            -- ...and the ward he owes them now, so the cast is not purely a promise about later turns.
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side == fx.user.side then
                    fx.applyStatus(u, "status_lent_guard", { applier = fx.user })
                end
            end
        end,
    },
}
