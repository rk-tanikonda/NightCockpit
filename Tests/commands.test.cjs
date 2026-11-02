const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const source = path.resolve(__dirname, '..');

// Real command parsing and path resolution, with system-changing endpoints replaced.
function fixture(t, { version = '26.0', lockStatus = 0, bundled = false } = {}) {
  const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'night cockpit test ')));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const project = path.join(root, 'source with spaces');
  const bin = path.join(root, 'bin');
  const home = path.join(root, 'home');
  fs.mkdirSync(path.join(project, 'scripts/lib'), { recursive: true });
  fs.mkdirSync(bin);
  fs.mkdirSync(home);
  if (bundled) {
    fs.mkdirSync(path.join(project, 'Videos'));
    fs.writeFileSync(path.join(project, 'Videos/wallpaper.mp4'), 'original demo fixture');
  }
  fs.copyFileSync(path.join(source, 'scripts/lib/common.sh'), path.join(project, 'scripts/lib/common.sh'));
  fs.copyFileSync(path.join(source, 'setup.command'), path.join(project, 'setup.command'));
  fs.copyFileSync(path.join(source, 'Info.plist'), path.join(project, 'Info.plist'));
  const calls = path.join(root, 'calls');
  function script(file, body) { fs.writeFileSync(file, `#!/bin/bash\n${body}\n`, { mode: 0o755 }); }
  script(path.join(bin, 'uname'), 'echo Darwin');
  script(path.join(bin, 'sw_vers'), `echo '${version}'`);
  script(path.join(bin, 'defaults'), 'if [[ "$1" == read ]]; then exit 1; fi; printf "defaults" >> "$CALLS"; printf " <%s>" "$@" >> "$CALLS"; echo >> "$CALLS"');
  script(path.join(project, 'build.command'), 'echo build >> "$CALLS"');
  script(path.join(project, 'service.command'), 'printf "service <%s> <%s>\\n" "$1" "${2:-}" >> "$CALLS"; if [[ "$1" == prepare && -f "$(dirname "$0")/Videos/wallpaper.mp4" ]]; then mkdir -p "$HOME/Applications/Night Cockpit.app/Contents/Resources"; cp "$(dirname "$0")/Videos/wallpaper.mp4" "$HOME/Applications/Night Cockpit.app/Contents/Resources/"; fi');
  script(path.join(project, 'lockscreen.command'), `printf 'lock <%s> <%s>\\n' "$1" "$2" >> "$CALLS"; exit ${lockStatus}`);
  const env = { ...process.env, HOME: home, PATH: `${bin}:${process.env.PATH}`, CALLS: calls };
  function run(args) {
    return spawnSync('/bin/bash', [path.join(project, 'setup.command'), ...args], { cwd: root, env, encoding: 'utf8' });
  }
  function log() { return fs.existsSync(calls) ? fs.readFileSync(calls, 'utf8') : ''; }
  return { root, project, home, run, log };
}

test('help works without platform/toolchain checks or system changes', () => {
  for (const command of ['build', 'setup', 'service', 'lockscreen', 'check']) {
    const result = spawnSync('/bin/bash', [path.join(source, `${command}.command`), '--help'], {
      cwd: os.tmpdir(), env: { ...process.env, PATH: '/usr/bin:/bin' }, encoding: 'utf8'
    });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Usage:/);
  }
});

test('a source download with no media installs and lets the app choose a video', t => {
  const f = fixture(t);
  const result = f.run([]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(f.log(), /^build\nservice <prepare> <--use-build>/);
  assert.match(f.log(), /nativeWallpaper> <-bool> <false>/);
  assert.match(f.log(), /service <activate>/);
  assert.doesNotMatch(f.log(), /lock <|videoPath/);
});

test('video paths resolve from the caller directory and preserve spaces and shell characters', t => {
  const f = fixture(t);
  const name = 'own clip $(touch unintended).mp4';
  fs.writeFileSync(path.join(f.root, name), 'fixture');
  const result = f.run(['--video', name, '--desktop-only']);
  assert.equal(result.status, 0, result.stderr);
  assert.ok(f.log().includes(`<${path.join(f.root, name)}>`));
  assert.doesNotMatch(f.log(), /websiteMode/);
  assert.equal(fs.existsSync(path.join(f.root, 'unintended')), false);
  assert.doesNotMatch(f.log(), /lock </);
});

test('missing, empty and malformed video arguments fail before mutation', t => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.root, 'empty.mp4'), '');
  for (const args of [['--video'], ['--video', '--lock-screen'], ['--video', 'missing.mp4'], ['--video', 'empty.mp4'], ['--unknown']]) {
    const result = f.run(args);
    assert.notEqual(result.status, 0);
    assert.equal(f.log(), '');
  }
});

test('desktop setup works on older macOS; native setup fails before mutation', t => {
  const f = fixture(t, { version: '14.0' });
  fs.writeFileSync(path.join(f.root, 'clip.mp4'), 'fixture');
  const lock = f.run(['--video', 'clip.mp4', '--lock-screen']);
  assert.notEqual(lock.status, 0);
  assert.match(lock.stderr, /macOS 26/);
  assert.equal(f.log(), '');
  assert.equal(f.run([]).status, 0);
});

test('native setup uses the same file for native registration and desktop playback', t => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.root, 'clip.mp4'), 'fixture');
  const result = f.run(['--video', 'clip.mp4', '--lock-screen']);
  assert.equal(result.status, 0, result.stderr);
  assert.ok(f.log().includes(`lock <install> <${path.join(f.root, 'clip.mp4')}>`));
  assert.ok(f.log().includes(`videoPath> <-string> <${path.join(f.root, 'clip.mp4')}>`));
  assert.ok(f.log().indexOf('build') < f.log().indexOf('lock <'));
  assert.match(f.log(), /service <prepare> <--use-build>/);
  assert.match(f.log(), /service <activate>/);
  assert.ok(f.log().indexOf('service <prepare>') < f.log().indexOf('lock <'));
  assert.ok(f.log().indexOf('lock <') < f.log().indexOf('service <activate>'));
});

test('failed native setup still starts desktop and returns the native failure', t => {
  const f = fixture(t, { lockStatus: 7 });
  fs.writeFileSync(path.join(f.root, 'clip.mp4'), 'fixture');
  const result = f.run(['--video', 'clip.mp4', '--lock-screen']);
  assert.equal(result.status, 7);
  assert.match(result.stderr, /Native Lock Screen setup failed/);
  assert.match(f.log(), /nativeWallpaper> <-bool> <false>/);
  assert.match(f.log(), /service <activate>/);
});

test('fresh source download uses bundled media from the installed app, with automatic native setup', t => {
  const f = fixture(t, { bundled: true });
  const result = f.run([]);
  assert.equal(result.status, 0, result.stderr);
  const installed = path.join(f.home, 'Applications/Night Cockpit.app/Contents/Resources/wallpaper.mp4');
  assert.ok(f.log().includes(`videoPath> <-string> <${installed}>`));
  assert.ok(f.log().includes(`lock <install> <${installed}>`));
  assert.match(f.log(), /keepLockDisplayAwake> <-bool> <true>/);
  assert.equal(f.log().match(/^build$/gm).length, 1);
  assert.equal(f.log().match(/^service <prepare>/gm).length, 1);
});

test('bundled demo supports older Macs and desktop-only mode without native setup', t => {
  for (const options of [{ version: '13.0', bundled: true }, { version: '26.0', bundled: true }]) {
    const f = fixture(t, options);
    const result = f.run(options.version === '26.0' ? ['--desktop-only'] : []);
    assert.equal(result.status, 0, result.stderr);
    assert.match(f.log(), /wallpaper\.mp4/);
    assert.doesNotMatch(f.log(), /lock <|keepLockDisplayAwake/);
  }
});

test('display-sleep opt-out and incompatible flags are handled before installation', t => {
  const f = fixture(t, { bundled: true });
  assert.equal(f.run(['--allow-display-sleep']).status, 0);
  assert.match(f.log(), /keepLockDisplayAwake> <-bool> <false>/);
  const conflict = fixture(t, { bundled: true });
  assert.notEqual(conflict.run(['--lock-screen', '--desktop-only']).status, 0);
  assert.equal(conflict.log(), '');
});
