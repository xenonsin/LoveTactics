-- BAD DREAMS: what the Sandman's sleep leaves behind ("Sloth's Bestiary", slice G, approved word for word). A body
-- woken from HIS sleep by a blow is Rattled until the end of its next turn. Woken by a Cure, or left to wake on its
-- own, it is not.
--
-- A FLAG AND NOTHING ELSE. Sandman.sleep stamps every sleep its bearer lays (`badDreams`, on the sleep instance),
-- and status_sleep reads the stamp on the one path that is a blow. So the answer is in the company's hands: Cure
-- your sleepers, or let them lie, and the sleep costs only the turns it took.
return {
    name = "Bad Dreams",
    description = "A body woken from his sleep by a blow is Rattled until the end of its next turn.",
    badDreams = true,
}
