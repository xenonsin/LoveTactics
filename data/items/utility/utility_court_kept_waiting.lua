-- Isa's bound relic (Summoner). A payoff for having summoned that is not "summon more".
--
-- THE COURT CLOSES RANKS. Every elemental she has fielded is braced and quickened at once, and each is
-- lent force by every other one still standing -- so three summons are worth considerably more than
-- three summons. What she is rewarded for is the thing she already spent the fight doing, rather than
-- being handed a fourth body to spend another turn placing.
--
-- THE CENSUS IS THREE STANDING, which is the honest reading of a court: the five Summon spells and the
-- Mana Wellspring that pays for them are the build, and losing one shuts the gate again. A summoner
-- whose court has been picked off has to rebuild it before she can call on it, which is the pressure a
-- tally could never have applied.
--
-- Deliberately the same two statuses the Beastmaster's relic uses on her pack, and that is a
-- similarity rather than a duplication: they are the two disciplines whose whole game is other bodies,
-- and the difference between them is what those bodies ARE -- one keeps a pack alive, the other keeps
-- a court fielded. The tell is the census clause: hers counts beasts, this counts everything summoned.
return {
    name = "The Court Kept Waiting",
    description = "Braces and hastens every summon you hold, each lent force by the others standing.",
    flavor = "They were never waiting to be called. They were waiting to be counted.",
    sprite = "assets/items/sig_court_kept_waiting.png",
    type = "utility",
    tags = { "signature", "arcane" },
    class = "mage",
    discipline = "summoner",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "mana", amount = 12 },
        description = "Your summons are braced, hastened, and strengthened by each other.",
        unlock = {
            field = { of = "unit", summoned = true, count = 3 },
            text = "3 summons standing",
        },
        effect = function(fx)
            local court = {}
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.summoner == fx.user then court[#court + 1] = u end
            end
            for _, summoned in ipairs(court) do
                fx.applyStatus(summoned, "status_defending")
                fx.applyStatus(summoned, "status_empowered", { magnitude = 3 * (#court - 1) })
                fx.hasten(summoned, 0.4)
            end
        end,
    },
    -- everything you hold is braced while it waits
    bonus = { magicDefense = 2 },
}
