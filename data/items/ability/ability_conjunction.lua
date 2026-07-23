-- Conjunction: the Arcanum decides that several bodies are one body, and they are, until it stops
-- paying attention. Aimed at a foe; every enemy in the 3x3 around it is Conjoined
-- (data/status/status_conjoined.lua), and from then on a wound landing on ANY of them is felt by all
-- the others at half strength.
--
-- The struck unit takes its wound WHOLE. The echo is ADDED to the others rather than divided out of
-- it, so a conjunction never softens the blow that set it off -- hit one of four for 40 and the
-- binding pays 20 into each of the other three. Sixty damage the board did not have to be dealt.
--
-- IT LANDS NOTHING ITSELF. That is what makes it a mage ability rather than a bigger spell: it is a
-- turn spent entirely on making next turn's damage worth three times what it would otherwise have
-- been. Pride's whole shelf is setup-then-payoff -- a channel that resolves later, a hazard that
-- decides where people may stand, a Collapse that gathers a formation -- and this is the version that
-- edits the arithmetic instead of the board.
--
-- WHAT IT PAIRS WITH is most of the catalogue, and choosing is the interesting part:
--   * anything SINGLE-TARGET and enormous -- a channeled Greatsword blow, a Coup de Grace, a Powershot
--     -- because the binding turns one big number into four. This is the intended reading.
--   * a Twinned Sigil beside the follow-up (data/items/utility/utility_twinned_sigil.lua), which forks
--     the trigger as well, so two bodies take a full wound and each rings the other two.
--   * Collapse (data/items/ability/ability_collapse.lua) BEFORE it, to gather a formation loose enough
--     that a 3x3 would not otherwise have caught four of them.
-- It pairs badly with an AoE follow-up, and deliberately so: a Fireball that hits all four already
-- spent its area doing what the binding does, and the echoes it rings are off its own smaller
-- per-target number. The conjunction wants ONE big hit, not four small ones.
--
-- THE COUNTER is Cure, one body at a time. A cleanse takes that unit out of the ring and leaves the
-- ring standing, so an enemy priest can blunt this but never undo it in a turn -- and the mage can see
-- exactly how much was blunted by counting badges.
--
-- Read against the knight's Shared Burden (data/items/ability/ability_shared_burden.lua), which is
-- this machine with the sign flipped: a bond CONSERVES suffering between two bodies and costs the
-- swearer its own blood, and a conjunction MULTIPLIES it across four and costs the caster a turn.
-- Sloth guards a body it can reach; pride edits what a body is and walks away.
return {
    name = "Conjunction",
    description = "Binds foes in an area: a wound on any one of them is felt by all the others at half strength.",
    flavor = "The Arcanum does not consider this cruelty. It considers it a correction of a bookkeeping error.",
    sprite = "assets/items/ability_conjunction.png",
    type = "ability",
    tags = { "magical", "arcane" },
    class = "mage",
    price = 440,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 5,
        support = true, -- it lands no damage of its own: the binding is the whole cast
        cost = { stat = "mana", amount = 18 },
        aoe = { radius = 1, shape = "square" },
        -- Worth a turn only when there is a cluster to bind. Two is the floor at which the echo pays
        -- for the turn that laid it; the scorer finds the cluster on its own.
        ai = { priority = "high", act = "attack",
               when = { subject = "any_foe", test = "count_at_least", value = 2 } },
        effect = function(fx)
            -- One LINK per cast, minted here: a bare table whose only job is identity. It is what
            -- separates this working from another one at the far end of the field, which would
            -- otherwise feed it (see Combat.echoWound). A status carrying no link does nothing.
            local link = {}
            local bound = 0
            for _, u in ipairs(fx.aoeUnits()) do
                -- Foes only. Binding your own line into the enemy's would be a way to lose a party,
                -- and there is no reading of this spell in which the Arcanum meant to do that.
                if u.side ~= fx.user.side then
                    -- Duration scales with the forge; the SHARE does not. A better-kept working holds
                    -- the binding open longer -- it never makes half into more than half, because
                    -- half is what the binding says at every level.
                    local st = fx.applyStatus(u, "status_conjoined", { duration = 20 + 2 * fx.level })
                    -- May be nil: Conjoined is `resistible`, so a strong-willed body can shrug the
                    -- binding off entirely, and an unbound unit must not be stamped with the link.
                    if st then
                        st.link = link
                        bound = bound + 1
                    end
                end
            end
            if bound > 0 then
                fx.log("action", string.format("%d foes are bound into one.", bound))
            end
        end,
    },
}
