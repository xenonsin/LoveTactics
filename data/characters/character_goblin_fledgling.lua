-- THE GOBLIN FLEDGLING, rung 2: a goblin newly turned (Wrath's vampires, 2026-09-26). The human Fledgling's rules
-- (vampire, newly turned: Bloodlust at 2 Thirst), and still a GOBLIN -- race and class are kept, so it has Blood
-- Feud. In Bloodlust it bites the nearest body, and when that body is a goblin, the Fledgling becomes that
-- goblin's Feud (models/feud.lua lets kin be the Feud only then) and the warband turns on it. Bad Blood puts one in
-- a goblin warband on purpose.
local base = require("data.characters.character_fledgling")

local goblin = {}
for k, v in pairs(base) do goblin[k] = v end

goblin.name = "Goblin Fledgling"
goblin.race = "goblin"
goblin.sprite = "assets/chars/goblin_fledgling.png"
goblin.stats = {}
for k, v in pairs(base.stats) do goblin.stats[k] = v end
-- A goblin frame: lighter, and the race adds damage and speed on top.
goblin.stats.health = 40
goblin.stats.damage = 9
goblin.stats.speed = 4

return goblin
