// record_audio.js: record the web version's synthesized music and sound effects to files
// for the Godot version. Runs the web game in headless Chromium (Playwright), taps every
// connection to the speakers into a MediaRecorder, and saves each sound as WebM/Opus;
// ffmpeg then trims and converts (music: one exact loop as .ogg; effects: .wav).
//
// Usage: node tools/record_audio.js [outdir]    (default godot/assets/audio)
'use strict';
const { chromium } = require('playwright');
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.resolve(process.argv[2] || path.join(ROOT, 'godot', 'assets', 'audio'));
const MUSIC = ['title', 'stage1', 'boss', 'clear', 'gameover'];
const SFX = ['punch', 'heavy', 'whiff', 'hurt', 'jump', 'land', 'step', 'enemyDie', 'explode', 'block',
  'select', 'menu', 'pause', 'go', 'combo', 'glitch', 'pickup', 'heal', 'warn', 'roar', 'throw', 'stomp'];

// injected before the game's scripts: every connect() to the speakers also feeds a recorder
const TAP = `(() => {
  const orig = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (dest, ...rest) {
    const r = orig.call(this, dest, ...rest);
    if (dest instanceof AudioDestinationNode) {
      const ctx = this.context;
      if (!ctx.__tap) ctx.__tap = ctx.createMediaStreamDestination();
      orig.call(this, ctx.__tap);
    }
    return r;
  };
  window.__record = async (seconds, start) => {
    const ctx = window.__ctx;
    const rec = new MediaRecorder(ctx.__tap.stream, { mimeType: 'audio/webm;codecs=opus', audioBitsPerSecond: 192000 });
    const chunks = [];
    rec.ondataavailable = (e) => chunks.push(e.data);
    const done = new Promise((res) => (rec.onstop = res));
    rec.start();
    start();
    await new Promise((res) => setTimeout(res, seconds * 1000));
    rec.stop();
    await done;
    const buf = await new Blob(chunks).arrayBuffer();
    let s = '';
    const u = new Uint8Array(buf);
    for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000));
    return btoa(s);
  };
  const OrigAC = window.AudioContext;
  window.AudioContext = function (...a) { const c = new OrigAC(...a); window.__ctx = c; return c; };
  window.AudioContext.prototype = OrigAC.prototype;
})();`;

function ffmpeg(args) {
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...args]);
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hotfix-audio-'));
  const browser = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage();
  await page.addInitScript(TAP);
  await page.goto('file://' + path.join(ROOT, 'index.html'));
  await page.evaluate(() => { G.Audio.init(); G.Audio.stopMusic(); G.Audio.setVol('music', 0.8); G.Audio.setVol('sfx', 0.9); });
  await page.waitForTimeout(500);

  for (const id of MUSIC) {
    const info = await page.evaluate((id) => { const s = G.Songs.compile(id); return { secs: s.len * 60 / s.bpm / 4, loop: s.loop }; }, id);
    const b64 = await page.evaluate(async ([id, secs]) => {
      G.Audio.stopMusic();
      await new Promise((r) => setTimeout(r, 400));
      return window.__record(secs + 1.5, () => G.Audio.playMusic(id));
    }, [id, info.secs]);
    const raw = path.join(tmp, id + '.webm');
    fs.writeFileSync(raw, Buffer.from(b64, 'base64'));
    // start at the first note, keep exactly one loop (or the whole jingle plus its tail)
    const len = info.loop ? info.secs : info.secs + 1.2;
    ffmpeg(['-i', raw, '-af', `silenceremove=start_periods=1:start_threshold=-50dB,atrim=0:${len.toFixed(4)},afade=t=in:d=0.005`,
      '-ac', '2', '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '5', path.join(OUT, 'music_' + id + '.ogg')]);
    console.log('music', id, info.secs.toFixed(2) + 's', info.loop ? 'loop' : 'jingle');
  }
  await page.evaluate(() => G.Audio.stopMusic());
  for (const name of SFX) {
    const b64 = await page.evaluate(async (name) => {
      await new Promise((r) => setTimeout(r, 200));
      return window.__record(1.4, () => G.Audio.sfx(name));
    }, name);
    const raw = path.join(tmp, name + '.webm');
    fs.writeFileSync(raw, Buffer.from(b64, 'base64'));
    // trim leading silence and the silent tail
    ffmpeg(['-i', raw, '-af', 'silenceremove=start_periods=1:start_threshold=-55dB,areverse,silenceremove=start_periods=1:start_threshold=-60dB,areverse',
      '-ac', '1', '-ar', '44100', path.join(OUT, 'sfx_' + name + '.wav')]);
  }
  console.log('sfx', SFX.length, 'effects');
  await browser.close();
  fs.rmSync(tmp, { recursive: true, force: true });
})();
