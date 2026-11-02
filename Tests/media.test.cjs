const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

test('source download includes the licensed demo bytes recorded in its provenance', () => {
    const root = path.join(__dirname, '..');
    const movie = fs.readFileSync(path.join(root, 'Videos/wallpaper.mp4'));
    const source = fs.readFileSync(path.join(root, 'Videos/SOURCE.md'), 'utf8');
    const expected = source.match(/SHA-256: `([a-f0-9]{64})`/);
    assert.ok(expected, 'Media provenance must record its checksum');
    assert.equal(crypto.createHash('sha256').update(movie).digest('hex'), expected[1]);
    assert.ok(movie.length > 1024 * 1024 && movie.length < 100 * 1024 * 1024);
    assert.match(fs.readFileSync(path.join(root, 'MEDIA_LICENSE.md'), 'utf8'), /CC0 1\.0 Universal/);
});
