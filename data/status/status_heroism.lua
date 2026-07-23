-- Heroism: borrowed nerve. Raises BOTH defenses for a long window, and -- unlike its two siblings on
-- the elixir shelf -- it also keeps its drinker on their feet: while it stands, the drinker cannot be
-- Halted (data/status/status_halted.lua).
--
-- That immunity is the elixir's whole claim to being worth more than a stat line. The other two
-- elixirs sell a number; this sells a refusal, and it is aimed squarely at the one status in the game
-- that takes a turn away without touching the body. A party that knows it is walking into the Bastion
-- drinks this first. Envy again: the Crucible cannot give you resolve, so it bottles the appearance
-- of it and charges accordingly.
--
-- `grantsImmunity` names the status refused outright, BEFORE the resistance curve (Status.isImmune) --
-- so a heroic unit does not resist the order, it simply does not receive it. Same set an item's
-- `statusImmunity` feeds, with a window instead of a grid slot: an item's immunity is a permanent
-- decision and a buff's is a turn somebody spent.
--
-- A BUFF, so Cure leaves it be.
return {
    name = "Heroism",
    abbr = "Hro",
    description = "Borrowed nerve: raised defenses, and cannot be Halted.",
    color = { 0.92, 0.72, 0.30 }, -- badge tint (brass and courage)
    duration = 45, -- ~9 turns at Status.TICKS_PER_TURN, matching the rest of the shelf
    statBonus = { defense = 8, magicDefense = 8 },
    grantsImmunity = { "status_halted" }, -- a nerve you drank is still a nerve: no order lands on it
}
