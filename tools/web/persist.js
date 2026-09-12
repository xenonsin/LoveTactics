/*
  Persisting the save directory. tools/web-build.ps1 (Set-SavePersistence) substitutes this file
  for the one line love.js writes at the end of its glue, INSIDE the module closure -- which is
  the only place `FS` can be reached, since this build does not export Module.FS.

  What love.js ships is:

      window.addEventListener("beforeunload", function () { FS.syncfs(false, ...) })

  and that never once persisted anything. The save directory is an IDBFS mount: writes land in
  memory and reach IndexedDB only when something calls FS.syncfs, which is ASYNCHRONOUS -- it
  opens a transaction, walks the mount, and writes each changed entry in a later task. A
  beforeunload handler gets none of those tasks: the document is torn down the moment the handler
  returns, the transaction is abandoned, and the campaign the player just spent an hour on is
  discarded with the page. Nothing reports this, because the write itself succeeded; only the
  crossing into IndexedDB did not happen. Every load then repopulates from an empty database and
  the main menu offers no Continue.

  Two mobile browsers make it worse rather than better: iOS Safari does not fire beforeunload at
  all, and a backgrounded tab on either platform may be killed without any unload event.

  So the flush is driven by the WRITE, not by the exit. FS.trackingDelegate names every path the
  engine touches; a write under the mount marks it dirty and a short debounce flushes it, so a
  save is in IndexedDB a fraction of a second after Player.save returns and closing the tab --
  or losing it -- costs nothing that was already written. The lifecycle handlers below are kept
  as a last chance for the debounce that has not fired yet, with visibilitychange ahead of
  beforeunload because it is the one event a phone reliably delivers.
*/
(function () {
  var MOUNT = "/home/web_user/love";

  var dirty = false;   // a write has landed that IndexedDB has not seen
  var busy  = false;   // a syncfs is in flight; starting a second logs and does extra work
  var timer = null;    // the pending debounce

  function flush(done) {
    if (busy) { if (done) done(); return; }
    busy = true;
    dirty = false;
    try {
      FS.syncfs(false, function (err) {
        busy = false;
        if (err) Module["printErr"]("save sync failed: " + err);
        // A write that arrived while the transaction was open is not covered by it.
        if (dirty) schedule(0);
        if (done) done(err);
      });
    } catch (e) {
      busy = false;
      Module["printErr"]("save sync threw: " + e);
      if (done) done(e);
    }
  }

  function schedule(ms) {
    if (timer) clearTimeout(timer);
    timer = setTimeout(function () { timer = null; flush(); }, ms);
  }

  // Every file the engine writes comes through here, the game's own assets included, so the
  // mount prefix is what keeps this to the handful of files that are actually the player's.
  function touched(path) {
    if (typeof path !== "string" || path.lastIndexOf(MOUNT, 0) !== 0) return;
    dirty = true;
    // Long enough that a save writing several files is one transaction, short enough that the
    // window in which a kill loses the write is not one a player could notice.
    schedule(400);
  }

  FS.trackingDelegate["onWriteToFile"] = touched;
  FS.trackingDelegate["onDeletePath"]  = touched;
  FS.trackingDelegate["onMovePath"]    = function (from, to) { touched(from); touched(to); };

  // Going away: flush what the debounce still owes. Best effort by definition -- if the document
  // dies first this achieves nothing, which is precisely why it is not the only path.
  function leaving() {
    if (timer) { clearTimeout(timer); timer = null; }
    if (dirty) flush();
  }
  document.addEventListener("visibilitychange", function () {
    if (document.hidden) leaving();
  }, false);
  window.addEventListener("pagehide", leaving, false);
  window.addEventListener("beforeunload", leaving, false);

  // The page's only handle on any of this, for a driver that needs to know the save has actually
  // crossed before it reloads.
  Module["loveSyncSaves"]    = function (done) { flush(done); };
  Module["loveSavesPending"] = function () { return dirty || busy || timer !== null; };
})();
