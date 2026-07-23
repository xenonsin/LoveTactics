-- Warbrewer -- fighter x alchemist multiclass discipline.
-- Signature mechanic: Combat draught -- chug a self-buff elixir as a FREE action mid-swing, fuelling
-- a rampage.
-- Exemplar: a berserker-draught brawler (character_warbrewer, NEW -- pending), met as a BOSS.
-- Gate: earned advancement -- requires a fighter subclass AND an alchemist subclass unlocked, which
-- opens the_fighting_cellar (pending). See docs/disciplines-plan.md.
return {
    name    = "Warbrewer",
    classes = { "fighter", "alchemist" },
    exemplar = "character_warbrewer", -- NEW, pending
    requiredQuests = { "the_fighting_cellar" }, -- pending
}
