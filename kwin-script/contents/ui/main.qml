import QtQuick
import org.kde.kwin

// Terminal animations. Settings live in ~/.config/kwinrc under [Script-termanim]; edit them with `termanim`.
Item {
    id: root

    function cfg(key, def) { return KWin.readConfig(key, def); }
    function num(key, def) { return Number(KWin.readConfig(key, def)); }

    // which windows animate when they open, and which window the hotkey toggles
    readonly property var terminalClasses: String(cfg("terminalClasses", "com.mitchellh.ghostty,org.kde.konsole,kitty,Alacritty")).split(",").map(s => s.trim()).filter(s => s.length > 0)
    readonly property string hotkeyClass: cfg("hotkeyClass", "dev.termanim.dropdown")
    readonly property string hotkey: cfg("hotkey", "F12")

    // animation per trigger: gravity | paddle | fade | slingshot | glitch | slide | shake | pendulum | orbit | yoyo | random
    readonly property string newWindowAnimation: cfg("newWindowAnimation", "gravity")
    readonly property string hotkeyAnimation: cfg("hotkeyAnimation", "gravity")
    readonly property var randomPool: String(cfg("randomPool", "gravity,paddle,fade,slingshot,glitch,slide,shake,pendulum,orbit,yoyo")).split(",").map(s => s.trim()).filter(s => s.length > 0)

    // monitor per trigger: "cursor" (screen the mouse is on) or an output name such as DP-3
    readonly property string newWindowScreen: cfg("newWindowScreen", "cursor")
    readonly property string hotkeyScreen: cfg("hotkeyScreen", "cursor")

    // resting size and position, relative to the screen's top-left corner;
    // width/height of 0 mean 80% / 85% of the screen, and x/y of -1 mean centered horizontally / just below the top bar
    readonly property real restX: num("x", -1)
    readonly property real restY: num("y", -1)
    readonly property real restW: num("width", 0)
    readonly property real restH: num("height", 0)

    // physics and timing
    readonly property real gravity: num("gravity", 4.0)            // screen heights per second squared
    readonly property real restitution: num("restitution", 0.55)   // fraction of speed kept per bounce
    readonly property real bounceTime: num("bounceTime", 2.4)      // paddle: seconds spent bouncing
    readonly property real settleTime: num("settleTime", 0.45)     // seconds easing into the resting spot
    readonly property real fadeTime: num("fadeTime", 0.25)
    readonly property real stiffness: num("slingshotStiffness", 300)   // slingshot: spring pull (higher = snappier)
    readonly property real damping: num("slingshotDamping", 11)        // slingshot: friction (lower = more overshoot)
    readonly property real glitchTime: num("glitchTime", 0.6)
    readonly property real slideTime: num("slideTime", 0.5)             // slide: seconds to glide down
    readonly property real shakeTime: num("shakeTime", 0.7)             // shake: seconds of rattling
    readonly property real shakeStrength: num("shakeStrength", 40)      // shake: starting amplitude in pixels
    readonly property real pendulumSwing: num("pendulumSwing", 55)      // pendulum: starting angle in degrees
    readonly property real orbitTime: num("orbitTime", 1.8)             // orbit: seconds spent spiraling in

    property var anims: []
    property var pending: []
    property bool shown: false
    property string lastRandom: ""

    function chooseAnimation(name) {
        if (name !== "random") return name;
        const choices = randomPool.filter(m => m !== lastRandom);
        const pool = choices.length > 0 ? choices : randomPool;
        lastRandom = pool[Math.floor(Math.random() * pool.length)];
        return lastRandom;
    }

    function pickScreen(setting) {
        if (setting !== "cursor") {
            const screens = Workspace.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === setting) return screens[i];
            }
        }
        return Workspace.screenAt(Workspace.cursorPos);
    }

    function findHotkeyWindow() {
        const list = Workspace.windows;
        for (let i = 0; i < list.length; i++) {
            if (list[i].resourceClass === hotkeyClass) return list[i];
        }
        return null;
    }

    // top-left corner of the window when the pendulum hangs at angle theta
    function pendulumPos(a, theta) {
        return Qt.point(a.pivot.x + a.len * Math.sin(theta) - a.w / 2, a.pivot.y + a.len * Math.cos(theta) - a.h / 2);
    }

    // top-left corner on the inward spiral; t runs 0..1
    function orbitPos(a, t) {
        const g = a.area;
        const radius = Math.pow(1 - t, 1.5);
        const angle = -Math.PI / 2 + a.dir * 2 * Math.PI * 1.5 * (1 - Math.pow(1 - t, 2));
        return Qt.point(a.rest.x + g.width * 0.38 * radius * Math.cos(angle), a.rest.y + g.height * 0.3 * radius * Math.sin(angle));
    }

    function start(win, screen, animation) {
        const g = screen.geometry;
        const w = restW > 0 ? restW : Math.round(g.width * 0.8);
        const h = restH > 0 ? restH : Math.round(g.height * 0.85);
        const rx = restX >= 0 ? restX : Math.round((g.width - w) / 2);
        const ry = restY >= 0 ? restY : Math.round(g.height * 0.04);
        const a = {
            win: win, mode: chooseAnimation(animation), area: g, elapsed: 0, phaseStart: -1, w: w, h: h,
            rest: Qt.point(g.x + rx, g.y + ry),
            px: 0, py: 0, vx: 0, vy: 0, end: Qt.point(0, 0)
        };
        if (a.mode === "gravity") {
            a.px = a.rest.x; a.py = g.y - h;
        } else if (a.mode === "paddle") {
            a.px = g.x; a.py = g.y + g.height * 0.15; a.vx = g.width * 1.1; a.vy = g.height * 0.9;
        } else if (a.mode === "slingshot") {
            const edge = Math.floor(Math.random() * 3);   // launched from the left, right or bottom edge
            a.px = a.rest.x; a.py = a.rest.y;
            if (edge === 0) a.px = g.x - w - 50;
            else if (edge === 1) a.px = g.x + g.width + 50;
            else a.py = g.y + g.height + 50;
        } else if (a.mode === "glitch") {
            a.px = a.rest.x; a.py = a.rest.y; a.next = 0; a.ox = 0; a.oy = 0; a.op = 0;
        } else if (a.mode === "slide" || a.mode === "yoyo") {
            a.px = a.rest.x; a.py = g.y - h;
        } else if (a.mode === "shake") {
            a.px = a.rest.x; a.py = a.rest.y;
        } else if (a.mode === "pendulum") {
            a.pivot = Qt.point(a.rest.x + w / 2, g.y - 150);           // hangs from a point above the screen
            a.len = a.rest.y + h / 2 - a.pivot.y;
            a.theta0 = (Math.random() < 0.5 ? -1 : 1) * pendulumSwing * Math.PI / 180;
            const p = pendulumPos(a, a.theta0);
            a.px = p.x; a.py = p.y;
        } else if (a.mode === "orbit") {
            a.dir = Math.random() < 0.5 ? -1 : 1;
            const p = orbitPos(a, 0);
            a.px = p.x; a.py = p.y;
        } else {
            a.px = a.rest.x; a.py = a.rest.y + 40;
        }
        win.frameGeometry = Qt.rect(a.px, a.py, w, h);
        anims = anims.filter(o => o.win !== win).concat([a]);
        timer.start();
    }

    function bounce(pos, vel, lo, hi) {
        if (pos < lo) { pos = lo + (lo - pos); vel = Math.abs(vel); }
        else if (pos > hi) { pos = hi - (pos - hi); vel = -Math.abs(vel); }
        return [pos, vel];
    }

    function ease(a, dt, key) {          // eased move from a.end to a.rest
        const t = Math.min(1, (a.elapsed - a.phaseStart) / settleTime);
        const e = 1 - Math.pow(1 - t, 3);
        return { x: a.end.x + (a.rest.x - a.end.x) * e, y: a.end.y + (a.rest.y - a.end.y) * e, done: t >= 1 };
    }

    // advances one animation by dt seconds; returns false when it has finished
    function step(a, dt) {
        const g = a.area;
        const w = a.w;
        const h = a.h;
        a.elapsed += dt;
        let x = a.px, y = a.py, done = false;
        if (a.mode === "slide") {
            const t = Math.min(1, a.elapsed / slideTime);
            const e = 1 - Math.pow(1 - t, 3);
            x = a.rest.x; y = a.py + (a.rest.y - a.py) * e;
            if (t >= 1) done = true;
        } else if (a.mode === "yoyo") {
            // dropped on a spring from above: falls past its spot, springs back, bobs to rest
            const k = stiffness, c = damping * 0.55;
            a.vy += (-k * (a.py - a.rest.y) - c * a.vy) * dt;
            a.py += a.vy * dt;
            x = a.rest.x; y = a.py;
            if ((Math.abs(a.py - a.rest.y) < 1.5 && Math.abs(a.vy) < 8) || a.elapsed > 4) { y = a.rest.y; done = true; }
        } else if (a.mode === "shake") {
            const t = Math.min(1, a.elapsed / shakeTime);
            const amp = shakeStrength * Math.pow(1 - t, 2);
            x = a.rest.x + Math.sin(a.elapsed * 70) * amp;
            y = a.rest.y + Math.cos(a.elapsed * 53) * amp * 0.4;
            a.win.opacity = Math.min(1, a.elapsed / 0.12);
            if (t >= 1) { x = a.rest.x; y = a.rest.y; a.win.opacity = 1; done = true; }
        } else if (a.mode === "pendulum") {
            const theta = a.theta0 * Math.exp(-1.1 * a.elapsed) * Math.cos(3.6 * a.elapsed);
            const p = pendulumPos(a, theta);
            x = p.x; y = p.y;
            if ((a.elapsed > 1 && Math.abs(theta) * a.len < 1.5) || a.elapsed > 4) { x = a.rest.x; y = a.rest.y; done = true; }
        } else if (a.mode === "orbit") {
            const t = Math.min(1, a.elapsed / orbitTime);
            const p = orbitPos(a, t);
            x = p.x; y = p.y;
            if (t >= 1) { x = a.rest.x; y = a.rest.y; done = true; }
        } else if (a.mode === "slingshot") {
            // underdamped spring toward the resting spot: flies in fast, overshoots, snaps back
            a.vx += (-stiffness * (a.px - a.rest.x) - damping * a.vx) * dt;
            a.vy += (-stiffness * (a.py - a.rest.y) - damping * a.vy) * dt;
            a.px += a.vx * dt;
            a.py += a.vy * dt;
            x = a.px; y = a.py;
            if ((Math.abs(a.px - a.rest.x) < 1.5 && Math.abs(a.py - a.rest.y) < 1.5 && Math.abs(a.vx) + Math.abs(a.vy) < 8) || a.elapsed > 4) {
                x = a.rest.x; y = a.rest.y; done = true;
            }
        } else if (a.mode === "glitch") {
            const t = a.elapsed / glitchTime;
            if (t >= 1) {
                x = a.rest.x; y = a.rest.y; a.op = 1; done = true;
            } else {
                if (a.elapsed >= a.next) {       // new random jump every 30-80 ms, shrinking over time
                    const amp = 80 * (1 - t);
                    a.ox = (Math.random() - 0.5) * 2 * amp;
                    a.oy = (Math.random() - 0.5) * amp;
                    a.op = [0, 0.3, 1, 1][Math.floor(Math.random() * 4)];
                    a.next = a.elapsed + 0.03 + Math.random() * 0.05;
                }
                x = a.rest.x + a.ox; y = a.rest.y + a.oy;
            }
            a.win.opacity = a.op;
        } else if (a.mode === "fade") {
            const t = Math.min(1, a.elapsed / fadeTime);
            const e = 1 - Math.pow(1 - t, 3);
            x = a.rest.x;
            y = a.rest.y + 40 * (1 - e);
            a.win.opacity = e;
            done = t >= 1;
        } else if (a.mode === "paddle" && a.elapsed < bounceTime) {
            const rx = bounce(a.px + a.vx * dt, a.vx, g.x, g.x + g.width - w);
            const ry = bounce(a.py + a.vy * dt, a.vy, g.y, g.y + g.height - h);
            a.px = rx[0]; a.vx = rx[1]; a.py = ry[0]; a.vy = ry[1];
            x = a.px; y = a.py;
            a.end = Qt.point(x, y);
        } else if (a.mode === "gravity" && a.phaseStart < 0) {
            const floor = g.y + g.height - h;
            a.vy += g.height * gravity * dt;
            a.py += a.vy * dt;
            if (a.py >= floor) {
                a.py = floor;
                a.vy = -a.vy * restitution;
                if (Math.abs(a.vy) < g.height * 0.25) a.phaseStart = a.elapsed;
            }
            x = a.px; y = a.py;
            a.end = Qt.point(x, y);
        } else {                          // final ease into the resting spot
            if (a.phaseStart < 0) a.phaseStart = a.elapsed;
            const r = ease(a, dt);
            x = r.x; y = r.y; done = r.done;
        }
        a.win.frameGeometry = Qt.rect(x, y, w, h);
        if (a.mode !== "fade" && a.mode !== "glitch" && a.mode !== "shake") a.win.opacity = 1;   // revealed only once it is in motion, not at its default spot
        return !done;
    }

    Timer {
        id: timer
        interval: 8
        repeat: true
        onTriggered: {
            const dt = interval / 1000;
            root.anims = root.anims.filter(a => root.step(a, dt));
            if (root.anims.length === 0) stop();
        }
    }

    // new terminal windows wait a moment before animating: KWin ignores moves made while a window is still opening
    Timer {
        id: placeTimer
        interval: 300
        onTriggered: {
            const items = root.pending;
            root.pending = [];
            items.forEach(p => root.start(p.win, p.screen, root.newWindowAnimation));
        }
    }

    function toggle() {
        const win = findHotkeyWindow();
        if (!win) return;
        if (shown) {
            anims = anims.filter(a => a.win !== win);
            shown = false;
            win.minimized = true;
            return;
        }
        win.opacity = 0;
        start(win, pickScreen(hotkeyScreen), hotkeyAnimation);
        win.minimized = false;
        win.keepAbove = true;
        shown = true;
        Workspace.activeWindow = win;
    }

    function prepareHotkeyWindow(w) {
        w.skipTaskbar = true;
        w.skipPager = true;
        w.skipSwitcher = true;
        w.opacity = 0;   // hidden until the hotkey brings it in
        w.minimized = true;
    }

    ShortcutHandler {
        name: "TermAnim"
        text: "Toggle animated drop-down terminal"
        sequence: root.hotkey
        onActivated: root.toggle()
    }

    Connections {
        target: Workspace
        function onWindowAdded(w) {
            if (w.resourceClass === root.hotkeyClass) {
                root.shown = false;
                root.prepareHotkeyWindow(w);
            } else if (root.terminalClasses.indexOf(w.resourceClass) >= 0) {
                w.opacity = 0;   // stay invisible until the animation starts
                root.pending = root.pending.concat([{ win: w, screen: root.pickScreen(root.newWindowScreen) }]);
                placeTimer.restart();
            }
        }
        function onWindowRemoved(w) {
            if (w.resourceClass === root.hotkeyClass) {
                root.anims = root.anims.filter(a => a.win !== w);
                root.shown = false;
            }
        }
    }

    Component.onCompleted: {
        const w = findHotkeyWindow();
        if (w) prepareHotkeyWindow(w);
    }
}
