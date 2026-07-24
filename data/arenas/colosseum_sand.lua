-- The Colosseum floor: the board the debut bout is fought on (data/quests/arena_debut.lua's
-- objective.layout). Bound by name and `fixed = true`, exactly like the Demon Champion's arena
-- (data/arenas/demon_champion.lua) -- addressable only when the quest names it, never rolled into an
-- ordinary castle fight's pool.
--
-- Before this, the prologue's climax was fought on a randomly GENERATED castle field: open ground with
-- escape tiles in every direction, which is precisely why Saber's telegraphed swing could be strolled
-- out of. Every cell here answers that, and the board is read as a bowl the house rigged against the
-- newcomer:
--
--   * THE FUNNEL (obstacle at x1/x8 on y4-5, plus shoulder pillars at the corners of the mid-field).
--     The flanks are walled, so there is no open ground to drift a line out of sideways -- the killing
--     floor is the central columns, and a body dodging Saber's swing is pushed toward the walls rather
--     than away into space. This is the load-bearing fix: fewer lanes, not unavoidable blows. The
--     pillars double as knockback walls, as the Demon Champion's neck does.
--   * THE RIGGED EDGES (hidden snare_stake at the two funnel-mouth tiles, x2/x7). The house set the
--     sand. A player funneled to the wall to escape the greatsword finds the one place the bowl pushes
--     them toward is the one place that is trapped -- Root, no damage, invisible until a detector is
--     carried (Trap.visibleTo). Deliberately only TWO, and only on the escape tiles, so they punish
--     the specific behaviour being fixed rather than taxing movement at large.
--   * THE SOFT GROUND (visible grasping_hollow patches on the two mid-field shoulders). Roots on
--     ENTRY, and its `hostile` disposition means Saber's own side paths around it while the party has
--     to decide -- so it prices a flanking crossing without the party ever being surprised by it. The
--     honest, seeable counterpart to the hidden snares: one is the house cheating, one is just the
--     ground, and between them the flanks cost something to use.
--
-- Note the sand Saber's own swing churns up (weapon_first_motion's channelHazard) is laid at COMBAT
-- time, on commit -- it is not authored here. This board is the standing terrain; her wind-up adds to it.
return {
    biome = "castle",
    fixed = true, -- addressable by name (spec.layout); never rolled by an ordinary castle fight
    -- x:  1          2         3         4         5         6         7         8
    tiles = {
        { "ground",   "ground", "ground", "ground", "ground", "ground", "ground",   "ground" }, -- y1 enemy back line / gate
        { "ground",   "obstacle","ground","ground", "ground", "ground", "obstacle", "ground" }, -- y2 shoulder pillars
        { "ground",   "ground", "ground", "ground", "ground", "ground", "ground",   "ground" }, -- y3 approach
        { "obstacle", "ground", "ground", "ground", "ground", "ground", "ground",   "obstacle" }, -- y4 THE FUNNEL (walls x1/x8)
        { "obstacle", "ground", "ground", "ground", "ground", "ground", "ground",   "obstacle" }, -- y5 THE FUNNEL (walls x1/x8)
        { "ground",   "ground", "ground", "ground", "ground", "ground", "ground",   "ground" }, -- y6 approach
        { "ground",   "obstacle","ground","ground", "ground", "ground", "obstacle", "ground" }, -- y7 shoulder pillars
        { "ground",   "ground", "ground", "ground", "ground", "ground", "ground",   "ground" }, -- y8 party back line
    },
    -- Slot 1 = avatar, slot 2 = the second party member (Arena.build binds in party order); the rest
    -- are spare, for a party that arrives larger than the prologue's two.
    partySpawns = {
        { x = 4, y = 8 }, { x = 5, y = 8 },
        { x = 3, y = 8 }, { x = 6, y = 8 },
    },
    -- Composition order: Saber (the boss twin), then the House Hand. She takes the centre of the gate;
    -- the netter sets up off her shoulder.
    enemySpawns = {
        { x = 4, y = 2 }, { x = 6, y = 2 },
    },
    -- The house's own rigging: two hidden snares at the funnel mouths, where the walls push a fleeing
    -- body. `side = "enemy"` so they never bite Saber's team, and hidden (like every authored trap)
    -- until the party carries a detector.
    traps = {
        { id = "snare_stake", x = 2, y = 5, side = "enemy" },
        { id = "snare_stake", x = 7, y = 4, side = "enemy" },
    },
    -- Soft ground on the mid-field shoulders: seeable, and the enemy AI routes around it, so it prices
    -- a flanking crossing for the party without ever springing on them.
    hazards = {
        { id = "hazard_grasping_hollow", x = 3, y = 4 },
        { id = "hazard_grasping_hollow", x = 6, y = 5 },
    },
}
