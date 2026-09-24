-- SATED: being full, as generosity. While you are at full health, a heal meant for you goes to the most
-- hurt ally beside you instead (Combat.applyHeal reads `passesHeals`). A Paladin charm, from the Sated's
-- drops; approved on review (2026-09-23).
--
-- It turns a wasted heal -- a potion splash, a regeneration tick, a blessing landing on a body that is
-- already whole -- into one that lands. Standing beside nobody hurt, it is simply a heal on you.
return {
    name = "Sated",
    description = "At full health, heals meant for you go to the most hurt ally beside you.",
    passesHeals = true,
}
