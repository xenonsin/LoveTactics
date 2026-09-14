/*
 * Plays the web bundle in a real browser, as a step list, and says whether the loop survived
 * each step.
 *
 *   node tools/web-drive.js                                  # the local bundle on :8080
 *   node tools/web-drive.js https://xenonsin.github.io/LoveTactics/
 *   node tools/web-drive.js --touch                          # as a finger, on a phone-shaped screen
 *   node tools/web-drive.js --steps my-route.json --out shots
 *
 * A step is { click: [x, y] } in logical coordinates, { dom: selector }, { key: name } or a bare
 * { wait: ms }, plus optional `shot` (a screenshot name), `wait` and `note`. Coordinates are read
 * against 1280x720 unless the step carries its own `space: [w, h]` (or the run carries --space):
 * a fight screen on a phone is laid out in WIDTHx450, not 1280x720.
 *
 * WHY THIS EXISTS. tools/web-build.ps1 and tools/web-publish.ps1 are the deploy; this is the
 * verification between them, and it is the only one there is. The headless suite cannot see any
 * web-only failure -- it runs the desktop LOVE against the source tree, not the emscripten engine
 * against the bundle -- and the class of bug that matters most on the web LOGS NOTHING AT ALL.
 * love.audio.stop() inside emscripten's OpenAL, or newImage on a file that is not there, kills the
 * main loop between frames: no Lua error, no JS exception, no console line, just a canvas frozen
 * on its last frame. A console-log check passes cleanly on a dead game.
 *
 * So the thing this measures is FRAMES. An init script wraps requestAnimationFrame with a counter,
 * and every step reports the delta since the last one. A step with a positive delta proves the
 * loop is alive; a step that reports +0 is the step that killed it, which is as close to a stack
 * trace as this failure mode offers. That is also why the route is walked one beat at a time with
 * a wait after each: the loop dies BETWEEN frames, so several clicks inside one frame cannot be
 * told apart afterwards.
 *
 * The steps are DATA, and screenshots are how a run is read. "Every step alive" only says the game
 * is running -- it does not say a click landed on the button it was aimed at, and a missed click
 * looks exactly like a successful one in the log. Look at the pictures.
 *
 * THREE THINGS ABOUT DRIVING LOVE THROUGH A BROWSER, each of which costs a run to rediscover:
 *   - The Play gate is DOM, not canvas: <button id="start"> in tools/web/index.html, sitting over
 *     the canvas. A click at logical (640, 360) hits nothing.
 *   - page.mouse.click is too fast for LOVE. Press and release inside one frame is swallowed --
 *     the button visibly highlights (the move arrived) and never fires. Every click here is
 *     move, wait, down, wait, up.
 *   - Typing does not reach the game. Key presses arrive (Enter works a menu), but text input does
 *     not, so the name field stays empty. The name is typed by clicking the game's own on-screen
 *     keyboard, which is drawn for touch anyway.
 *
 * AND ON A PHONE (--touch): tap, never click. A single real mouse event anywhere puts the game
 * into hover mode and hides every touch-only bug, so the context is built with hasTouch and the
 * whole route -- the Play gate included -- goes through page.touchscreen.
 */

const fs = require("fs");
const path = require("path");

// Playwright lives in the portable Node install rather than in this repo: the game is Lua and has
// no package.json to hang a devDependency off, and the MSI for a system-wide Node needs elevation.
// Resolved rather than required by name so the tool works from any working directory.
const NODE_PORTABLE = path.join(
  process.env.LOCALAPPDATA || "", "node-portable", "node_modules");
function loadPlaywright() {
  for (const where of [ "playwright", path.join(NODE_PORTABLE, "playwright") ]) {
    try { return require(where); } catch (e) { /* try the next one */ }
  }
  console.error("playwright not found -- looked on the require path and in " + NODE_PORTABLE);
  process.exit(2);
}

// The local Chrome, rather than a browser Playwright downloads for itself: `playwright install`
// pulls ~130 MB per engine and this needs no particular build. Headless Chrome renders WebGL
// through SwiftShader; the "outsideRenderPass queueSerial" warnings it prints are noise.
const CHROME = "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe";
const GL_ARGS = [ "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader" ];

// THE DEFAULT ROUTE: title -> New Game -> a body -> a typed name -> the prologue -> the tutorial
// battle. It is the path every web-only bug so far has been caught on, because it is the one that
// loads a state, a save, a conversation and a board in that order.
//
// Coordinates are in the game's own 1280x720 logical space (see toPage), so they survive any
// window size -- but NOT a relayout of the screen they point at. The keyboard rows shifted 66px
// the last time ui/name_entry.lua was re-centred, and the tell was soft: every step still reported
// alive and the name simply came out a different word. Read the typed name in the screenshot.
const DEFAULT_STEPS = [
  { dom: "#start", wait: null, shot: "01_loaded", note: "the Play gate is DOM; the engine boots behind it" },
  { click: [640, 310], wait: 1500, shot: "02_newgame" },
  { click: [484, 485], wait: 1500, shot: "03_body" },
  { click: [640, 334], wait: 400, note: "D -- letters are a 7-wide grid from A at (358, 334), pitch 94 x 66" },
  { click: [452, 334], wait: 400, note: "b" },
  { click: [452, 400], wait: 400, shot: "04_typed", note: "i" },
  { click: [734, 598], wait: 7000, shot: "05_prologue", note: "Done" },
  { key: "Enter", wait: 2500, shot: "06_scene", note: "Enter advances the mentor's scene; 'Return' is not a Playwright key name" },
];

function parseArgs(argv) {
  const opts = { url: "http://localhost:8080/", out: "build/web-drive", touch: false,
                 headed: false, steps: null, gate: null, space: [ 1280, 720 ] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--touch") opts.touch = true;
    else if (a === "--headed") opts.headed = true;
    else if (a === "--steps") opts.steps = argv[++i];
    else if (a === "--out") opts.out = argv[++i];
    else if (a === "--gate") opts.gate = Number(argv[++i]);
    // THE LOGICAL SPACE A COORDINATE IS WRITTEN IN, which is not one number for a whole run. Most
    // screens are authored in 1280x720. A screen that has opted into the short space (states/battle
    // .lua's handheldSpace, on a device scale.lua calls handheld) is laid out in WIDTHx450, where
    // the width comes from the device's own aspect and clamps to [880, 1120] -- so a step aimed at
    // the fight screen on a phone carries its own `space` and the rest of the route does not.
    else if (a === "--space") opts.space = argv[++i].split("x").map(Number);
    else if (a.startsWith("--")) { console.error("unknown flag " + a); process.exit(2); }
    else opts.url = a;
  }
  // A first visit downloads ~32 MB and then compiles it, and the live site is slower than a local
  // server by more than a constant. One number rather than a wait on every step.
  if (opts.gate == null) opts.gate = /^https?:\/\/localhost|^https?:\/\/127\./.test(opts.url) ? 14000 : 45000;
  return opts;
}

(async () => {
  const opts = parseArgs(process.argv.slice(2));
  const steps = opts.steps
    ? JSON.parse(fs.readFileSync(opts.steps, "utf8"))
    : DEFAULT_STEPS;
  fs.mkdirSync(opts.out, { recursive: true });

  const { chromium } = loadPlaywright();
  const browser = await chromium.launch({
    executablePath: fs.existsSync(CHROME) ? CHROME : undefined,
    headless: !opts.headed,
    args: GL_ARGS,
  });
  // isMobile/hasTouch is also what makes the drawable's pixel count honest -- canvas.width against
  // getBoundingClientRect() is the resolution a phone actually gets, which is not the CSS size.
  const context = await browser.newContext(opts.touch
    ? { viewport: { width: 412, height: 915 }, isMobile: true, hasTouch: true, deviceScaleFactor: 3 }
    : { viewport: { width: 1280, height: 800 } });
  const page = await context.newPage();

  await page.addInitScript(() => {
    window.__frames = 0;
    const raf = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = (cb) => raf((t) => { window.__frames++; return cb(t); });
    window.__errors = [];
    window.addEventListener("error", (e) => window.__errors.push(String(e.message)));
  });
  page.on("console", (m) => { if (m.type() === "error") console.log("JS ERROR: " + m.text()); });

  console.log((opts.touch ? "tapping " : "clicking ") + opts.url);
  await page.goto(opts.url, { waitUntil: "domcontentloaded" });

  // The canvas is letterboxed inside the page exactly as scale.lua letterboxes the game inside the
  // canvas, so a logical coordinate is put through the same arithmetic to land where the player
  // would be pointing. Re-measured per step: the canvas is not at the page origin (it sits under
  // the header bar), and reading a coordinate off a screenshot without this is silently wrong --
  // the click lands on empty board and the run still reports every step alive.
  const toPage = async (lx, ly, space) => {
    const [ W, H ] = space || opts.space;
    const box = await page.evaluate(() => {
      const c = document.querySelector("canvas");
      if (!c) return null;
      const r = c.getBoundingClientRect();
      return { x: r.x, y: r.y, w: r.width, h: r.height };
    });
    if (!box) throw new Error("no canvas on the page yet");
    // A drawable taller than it is wide is drawn a QUARTER TURN CLOCKWISE rather than pillarboxed
    // (scale.lua's Scale.rotated), so a phone held upright uses its whole screen. This is the exact
    // inverse of Scale.toGame: the logical space's own top edge runs down the right-hand side, the
    // fitted rect is HEIGHT wide and WIDTH tall, and a logical y therefore walks LEFTWARD across
    // the page. Getting this wrong is silent -- the tap lands somewhere real and the run still
    // reports every step alive.
    if (box.h > box.w) {
      const s = Math.min(box.w / H, box.h / W);
      const ox = box.x + (box.w - H * s) / 2, oy = box.y + (box.h - W * s) / 2;
      return [ ox + H * s - ly * s, oy + lx * s ];
    }
    const s = Math.min(box.w / W, box.h / H);
    return [ box.x + (box.w - W * s) / 2 + lx * s, box.y + (box.h - H * s) / 2 + ly * s ];
  };

  let prev = 0, dead = null;
  for (const [i, st] of steps.entries()) {
    const label = st.shot || st.dom || (st.click ? "click " + st.click.join(",") : st.key || "wait");
    if (st.dom) {
      if (opts.touch) await page.tap(st.dom); else await page.click(st.dom);
    } else if (st.click) {
      const [px, py] = await toPage(st.click[0], st.click[1], st.space);
      if (opts.touch) {
        await page.touchscreen.tap(px, py);
      } else {
        await page.mouse.move(px, py); await page.waitForTimeout(200);
        await page.mouse.down(); await page.waitForTimeout(200); await page.mouse.up();
      }
    } else if (st.key) {
      await page.keyboard.press(st.key);
    }
    await page.waitForTimeout(st.wait == null ? opts.gate : st.wait);

    const frames = await page.evaluate(() => window.__frames);
    const delta = frames - prev; prev = frames;
    if (delta === 0 && dead == null) dead = label;
    console.log(`step ${i + 1}  ${label}  frames +${delta}` +
      (delta === 0 ? "   <<< THE LOOP STOPPED HERE" : "") + (st.note ? "   (" + st.note + ")" : ""));
    if (st.shot) await page.screenshot({ path: path.join(opts.out, "web_" + st.shot + ".png") });
  }

  const errs = await page.evaluate(() => window.__errors);
  console.log("page errors: " + (errs.length ? errs.join(" | ") : "none"));
  console.log("screenshots: " + path.resolve(opts.out) + "  -- look at them; a missed click reads as a clean run");
  await browser.close();

  // Exit code, so this can gate a publish: a dead loop or a thrown page error fails the run.
  if (dead) { console.error("FAILED: the loop stopped at '" + dead + "'"); process.exit(1); }
  if (errs.length) { console.error("FAILED: the page threw"); process.exit(1); }
})().catch((e) => { console.error(e); process.exit(1); });
