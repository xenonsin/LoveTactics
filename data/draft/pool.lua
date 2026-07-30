-- The draftable character pool for Draft mode, unlocked in waves as the run's rounds progress
-- (models/draft_run.lua reads this). Each entry is { round = N, ids = { ... } }: the ids become
-- draftable once the run reaches round N, and stay draftable for the rest of the run (the pool only
-- GROWS). Order does not matter -- DraftRun.pool accumulates every entry whose round has been reached.
--
-- The ids are the base discipline characters: the seven generic class templates first, then the
-- subclass exemplars, then the multiclass exemplars, so the early game is legible (the plain classes)
-- and later rounds open the specialized kits. An id that has no data file yet (a still-`pending`
-- exemplar) is simply skipped by DraftRun.pool via Save.known -- listing one here is harmless, so the
-- waves can name the whole intended roster ahead of the art/data landing.

return {
    -- Wave 1: the seven generic class templates -- one relic-free base per deadly-sin class.
    { round = 1, ids = {
        "character_fighter", "character_knight", "character_mage",
        "character_priest", "character_rogue", "character_alchemist", "character_archer",
    } },

    -- Wave 2: single-class subclass exemplars (the disciplines that specialize ONE class).
    { round = 2, ids = {
        "character_barbarian", "character_monk", "character_bulwark", "character_sentinel",
        "character_thief", "character_assassin", "character_poisoner",
    } },

    -- Wave 3: the rest of the subclasses -- the summon/trap/nature kits.
    { round = 3, ids = {
        "character_druid", "character_summoner", "character_necromancer",
        "character_trapper", "character_bombardier", "character_warlord",
    } },

    -- Wave 4: martial multiclass exemplars (two-class disciplines built on a fighter/knight spine).
    { round = 4, ids = {
        "character_champion", "character_paladin", "character_crusader", "character_duelist",
        "character_vanguard", "character_warden", "character_spellbreaker", "character_battlemage",
    } },

    -- Wave 5: the caster/alchemy multiclass exemplars -- the deepest, most specialized cuts.
    { round = 5, ids = {
        "character_inquisitor", "character_theurge", "character_shaman", "character_totemist",
        "character_herbalist", "character_poacher", "character_saboteur", "character_artificer",
        "character_warbrewer", "character_plague_knight",
    } },
}
