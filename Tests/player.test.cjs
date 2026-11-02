const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = fs.readFileSync(path.join(__dirname, '../Sources/Resources/stream-player.html'), 'utf8');
const playerScript = html.match(/<script>([\s\S]*?)<\/script>/)[1];

function createPlayer({ paused = false, fit = false } = {}) {
  const events = new Map();
  const messages = [];
  let interval;
  let deadline;
  let playCount = 0;
  const video = {
    muted: false, paused: true, currentTime: 0, readyState: 0, style: {},
    addEventListener(name, callback) { events.set(name, callback); },
    play() { this.paused = false; playCount++; return Promise.resolve(); },
    pause() { this.paused = true; }
  };
  const window = { webkit: { messageHandlers: { wallpaperStatus: {
    postMessage(message) { messages.push(message); }
  } } } };
  const context = {
    window, document: { getElementById(id) { assert.equal(id, 'wallpaper'); return video; } },
    setTimeout(callback) { deadline = callback; return 1; },
    clearTimeout() {}, setInterval(callback) { interval = callback; return 2; }
  };
  const config = { url: 'https://example.com/test.mp4', paused, fit };
  vm.runInNewContext(playerScript.replace('__CONFIG_JSON__', JSON.stringify(config)), context);
  return { video, window, messages, events, tick: () => interval(), timeout: () => deadline(), plays: () => playCount };
}

test('renders one video surface with no third-party page or controls', () => {
  assert.equal((html.match(/<video\b/g) || []).length, 1);
  assert.doesNotMatch(html, /<(iframe|a|button)\b/i);
  assert.doesNotMatch(html, /https?:\/\//);
  const p = createPlayer();
  assert.equal(p.video.src, 'https://example.com/test.mp4');
  assert.equal(p.video.muted, true);
  assert.equal(p.plays(), 1);
});

test('keeps desktop audio muted after a volume change', () => {
  const p = createPlayer();
  p.video.muted = false;
  p.events.get('volumechange')();
  assert.equal(p.video.muted, true);
});

test('paused startup stays paused; resume starts the player', () => {
  const p = createPlayer({ paused: true });
  assert.equal(p.plays(), 0);
  for (let i = 0; i < 20; i++) p.tick();
  assert.equal(p.messages.length, 0);
  p.window.wallpaper.setPaused(false);
  assert.equal(p.plays(), 1);
});

test('fit can change without reloading the source', () => {
  const p = createPlayer({ fit: true });
  assert.equal(p.video.style.objectFit, 'contain');
  p.window.wallpaper.setFit(false);
  assert.equal(p.video.style.objectFit, 'cover');
  assert.equal(p.video.src, 'https://example.com/test.mp4');
});

test('healthy looping time changes do not trigger reconnection', () => {
  const p = createPlayer();
  for (let i = 0; i < 50; i++) { p.video.currentTime = i % 3; p.tick(); }
  assert.equal(p.messages.length, 0);
  for (let i = 0; i < 10; i++) p.tick();
  assert.ok(p.messages.some(message => message.kind === 'error' && message.message.includes('stalled')));
});

test('missing data and media errors report failure, not successful playback', () => {
  const p = createPlayer();
  p.timeout();
  p.video.error = { code: 4 };
  p.events.get('error')();
  assert.ok(p.messages.every(message => message.kind === 'error'));
  p.events.get('playing')();
  assert.equal(p.messages.at(-1).kind, 'playing');
});
