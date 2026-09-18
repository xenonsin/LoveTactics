-- Flee: getting out of a fight before it starts, and what it costs to try.
--
-- WHY THIS EXISTS AT ALL, and it is not "because Wizardry has it". The ordinary fighting on a descent
-- floor is no longer seated on tiles -- it is rolled as the company walks (Descent.PROWL_STEPS) -- and
-- the moment that became true the player lost something they had always had: the marker. A seated fight
-- could be read from across the board (models/muster.lua's band and pips), priced against the company,
-- and walked around. A rolled one arrives. Without a way out, every judgement the muster system was
-- built to support would simply have stopped being askable, and the answer to "is this fight above me?"
-- would have become "it does not matter, you are in it".
--
-- SO THE JUDGEMENT MOVED, it was not deleted. It used to be made on the map, one tile early; it is made
-- on the DEPLOY SCREEN now, over the real board, with the enemy line standing on it and the same muster
-- reading behind it. That is later and better informed, and it is the one beat in the whole fight where
-- backing out costs nobody a turn.
--
-- IT IS A ROLL, AND IT CAN FAIL, which is the half that keeps the prowl dangerous. A guaranteed escape
-- would make the deploy screen a free look at every fight: walk, peek, leave, walk. Nothing would ever
-- be fought that the company did not already expect to win, attrition would never land, and the whole
-- reason the fighting moved off the board would be undone by the valve built to make it bearable.
--
-- AND THE ODDS RUN THE WRONG WAY ON PURPOSE. The fight you most want out of is the one you are least
-- likely to escape: the chance is read off the muster margin, so a company that is outmatched is also
-- slow, heavy and cornered. That is Wizardry's own cruelty and it is what makes a descent a series of
-- decisions rather than a series of previews -- going one floor deeper than you should have is a thing
-- you can still be punished for after you have seen what is waiting.
--
-- Pure (no love.graphics, no Combat, no panel), so it loads under the headless tests.

local Flee = {}

-- ---------------------------------------------------------------------------
-- Whether the company may try at all
-- ---------------------------------------------------------------------------

-- CAN THIS FIGHT BE RUN FROM? Everything the floor ROLLED, and every standing threat the floor seated.
-- Not the ends.
--
-- AN END IS THE WORK THE PLAYER CAME DOWN FOR -- the stair's general, an errand a house posted, the door
-- a circle holds shut -- and it is reached by choosing to walk onto a marker that has been visible since
-- the fog lifted off it. There is nothing to escape: the company is not cornered, it arrived. Offering
-- the plate anyway would put a button on the screen whose only honest label is "undo the last step",
-- and the step back off an objective is already free (game:openEncounter declines it without a fight).
--
-- AN ELITE CAN BE FLED even though it is seated and visible, and that is deliberate rather than an
-- oversight of the rule above. It is not work anybody asked for: it is a thing standing in a corridor,
-- and a company that misjudged one from across the board is in exactly the position this exists for.
function Flee.allowed(enc)
    if type(enc) ~= "table" then return false end
    return enc.kind == "combat" or enc.kind == "elite"
end

-- ---------------------------------------------------------------------------
-- The odds
-- ---------------------------------------------------------------------------

-- AN EVEN FIGHT, in percent of the chance to get away from one. Muster.margin reads 100 for an even
-- match, so this is the chance at exactly parity.
--
-- FIFTY-FIVE, which is deliberately a little better than a coin. The failure costs a harder fight (see
-- Flee.CAUGHT_STATUS) rather than the fight itself, so a company that tries and fails is behind rather
-- than beaten -- and at even odds or worse the correct play would be to never try at all, which would
-- leave the plate on the screen as a trap for people who had not done the arithmetic.
Flee.EVEN = 55

-- HOW FAR THE ODDS SWING ACROSS THE MUSTER SCALE, in percentage points per 100 points of margin.
--
-- Muster.margin is a percent where 100 is even and 200 is "twice their worth" -- the floor of the band
-- that already lets a company walk a fight off entirely (Muster.WALK_OVER). So one full step of margin
-- is the whole usable range of the reading, and pinning the swing to it is what keeps this from becoming
-- a second opinion about how strong the company is: the number that colours the marker is the number
-- that sets the odds.
Flee.SWING = 45

-- ...AND THE ENDS OF IT. Never certain and never hopeless, both for the same reason: a plate whose
-- answer is known before it is pressed is not a decision. The floor also has to stay above zero because
-- the company that needs it most is the one at the bottom of the scale -- a cornered party with no way
-- out is not a hard fight, it is a cutscene.
Flee.MIN, Flee.MAX = 20, 90

-- The chance to get away, in percent, for a company standing at `margin` (Muster.margin -- 100 is even).
--
-- A fight with no reading at all (nil margin: an empty or unresolvable composition) falls back to the
-- even number rather than refusing. There is nothing to compare, so there is nothing to adjust by, and
-- the company should still be allowed to run.
function Flee.chance(margin)
    if type(margin) ~= "number" then return Flee.EVEN end
    local c = Flee.EVEN + (margin - 100) / 100 * Flee.SWING
    return math.max(Flee.MIN, math.min(Flee.MAX, math.floor(c + 0.5)))
end

-- WHAT A FAILED ESCAPE COSTS: the enemy line opens the fight wearing this (Combat.dressSide).
--
-- A STATUS RATHER THAN A NUMBER, and the swap is the whole point. This was six initiative ticks added to
-- the company's clock -- the enemy moved and swung first, which is exactly what an ambush is and exactly
-- what no player could be told before pressing the button. A shuffle inside a countdown cannot be named
-- on a plate without teaching the countdown first, so the honest label for Run Away was a bare percent
-- and a shrug.
--
-- Hasted is a word the game has already taught: a badge on the token, a colour, a line in the log, a
-- tooltip of its own. So the wager states itself -- "fail and they start Hasted" -- and the board keeps
-- the promise where it can be seen, since the badges land during the deploy phase and stand there while
-- the player decides whether to ring the bell anyway.
--
-- PAID BY THE BODIES, NOT BY THE BOARD. Nothing about the arena, the spoils or the win condition
-- changes: it is the same fight, entered badly. That matters for the retry story -- a player who loses a
-- fight they were caught fleeing lost a fight, not a coin flip they were never shown.
--
Flee.CAUGHT_STATUS = "status_hasted"

-- ...AND FOR HOW LONG, in ticks. TEN, which is two turns at Status.TICKS_PER_TURN -- half the status's
-- own twenty.
--
-- CUT FROM THE BLUEPRINT'S CLOCK DELIBERATELY. Hasted is authored as a boon somebody paid for: four
-- quickened turns is what an ability or a relic hands a single body, and the whole enemy line wearing
-- that is not a worse fight, it is a different one. What this is pricing is the OPENING -- the beat the
-- company would have had to itself if it had never pressed the button -- so it lasts the exchange and
-- then it is gone, which is also the closest thing to the round the initiative shove used to cost.
--
-- IT IS ALSO A CEILING ON THE WAGER. The odds already run the wrong way (Flee.chance), so the company
-- most likely to be caught is the one least able to survive the catch; a penalty that outlasts the
-- opening would turn a 45% risk into a fight decided by the roll rather than by the board.
--
-- ONE NUMBER, BOTH SURFACES. The note beside the Run Away plate shows this status at this duration
-- (Flee.caughtStatus), so the hourglass the player reads before pressing is the hourglass the badge
-- carries afterwards -- there is no second account of it to drift.
Flee.CAUGHT_TICKS = 10

-- The status a caught company faces, as an instance -- for the readout that shows it before the press
-- (ui/deploy_phase.lua) and for the apply that lands it after (states/game.lua). Built here so neither
-- surface names the duration itself.
function Flee.caughtStatus()
    return require("models.status").instantiate(Flee.CAUGHT_STATUS, { duration = Flee.CAUGHT_TICKS })
end

-- ---------------------------------------------------------------------------
-- The roll
-- ---------------------------------------------------------------------------

-- DID THEY GET AWAY? True on success.
--
-- DEALT OFF THE RUN'S SEED AND THE LEG, not math.random, which is the rule every roll in the descent
-- keeps (models/seed.lua) and matters more here than most: this one decides whether a fight happens at
-- all, so a save scummed across it would otherwise be unanswerable in a bug report. `leg` moves with
-- every fight the prowl throws (Descent.calmProwl), so consecutive attempts on one trip are independent
-- draws rather than the same draw asked twice.
--
-- `tries` is how many times this company has already asked on THIS fight, and it salts the draw so a
-- second attempt is a new one. Callers that only allow a single attempt pass nothing.
function Flee.roll(seed, leg, chance, tries)
    local h = ((seed or 0) % 1000003) * 31 + (leg or 0) * 7919 + (tries or 0) * 104729
    h = (h * 1103515245 + 12345) % 2147483648
    return (h % 100) < (chance or 0)
end

return Flee
