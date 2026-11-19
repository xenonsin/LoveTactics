-- Charnel Tithe: every corpse the bearer's Corpse Burst consumes is worth 3 more to the blast (the
-- `corpseWorth` flag, read by ability_corpse_burst). The Necromancer's engine multiplier (docs/engines.md,
-- the leaf audit of 2026-11-18): the build-up was the kills, the payoff was the burst, and nothing in
-- between made a body worth more.
return {
    name = "Charnel Tithe",
    description = "Each corpse your Corpse Burst consumes adds 3 more damage.",
    corpseWorth = 3,
}
