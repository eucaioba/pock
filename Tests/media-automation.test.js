const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const script = fs.readFileSync('Vendor/Widgets/now-playing-widget/NowPlaying/Sources/MediaSession.js', 'utf8');
function setup() {
    const state = { spotify: { playing: true, position: 5 }, inspected: [] };
    const video = { paused: false, ended: false, currentTime: 35, duration: 100,
        pause() { this.paused = true; }, play() { this.paused = false; return Promise.resolve(); } };
    const url = 'https://www.youtube.com/watch?v=test';
    const page = { video, location: { href: url, hostname: 'www.youtube.com' }, navigator: { mediaSession: { metadata: { title: 'Video', artist: 'Channel', artwork: [{ src: 'https://i.ytimg.com/vi/test/hqdefault.jpg' }] } } },
        document: { title: 'Video - YouTube', querySelector(selector) { return selector === 'video' ? video : null; } } };
    const tabs = [{ url: () => 'https://youtube.com.evil.example/watch?v=bad' }, { url: () => 'https://example.com/' }, { url: () => url }];
    const safari = { running: () => true, windows: () => [{ tabs: () => tabs }], doJavaScript(js, {in: tab}) {
        state.inspected.push(tab.url());
        return vm.runInNewContext(js, { ...page, Number, JSON, Math, Infinity, Promise });
    } };
    const track = { name: () => 'Song', artist: () => 'Artist', album: () => 'Album', id: () => 'spotify:track:test',
        duration: () => 180000, artworkUrl: () => 'https://i.scdn.co/image/test' };
    const spotify = new Proxy({ running: () => true, playerState: () => state.spotify.playing ? 'playing' : 'paused',
        currentTrack: () => track, playerPosition: () => state.spotify.position,
        playpause() { state.spotify.playing = !state.spotify.playing; }, nextTrack() { state.next = true; }, previousTrack() { state.previous = true; }
    }, { set(object, key, value) { if (key === 'playerPosition') state.spotify.position = value; else object[key] = value; return true; } });
    const context = { ObjC: { import() {} }, Application(id) { return id === 'com.apple.Safari' ? safari : id === 'com.spotify.client' ? spotify : { running: () => false }; }, JSON, Number, String, isFinite };
    vm.createContext(context);
    vm.runInContext(script, context);
    const execute = request => JSON.parse(context.run([JSON.stringify(request)]));
    return { state, video, url, execute, safari, page };
}
{
    const {execute, state} = setup();
    const result = execute({source: 'automatic'});
    assert.equal(result.sessions.length, 2);
    assert.equal(result.sessions[0].duration, 180);
    assert.equal(result.sessions[1].title, 'Video');
    assert.equal(result.sessions[1].artist, 'Channel');
    assert.deepEqual(state.inspected, ['https://www.youtube.com/watch?v=test']);
}
{
    const {execute, video, url} = setup();
    execute({source:'safari', action:'toggle', key:url}); assert.equal(video.paused, true);
    execute({source:'safari', action:'next', key:url}); assert.equal(video.currentTime, 45);
    execute({source:'safari', action:'previous', key:url}); assert.equal(video.currentTime, 35);
    execute({source:'safari', action:'seek', position:200, key:url}); assert.equal(video.currentTime, 100);
    execute({source:'safari', action:'seek', position:2, key:'https://www.youtube.com/watch?v=other'}); assert.equal(video.currentTime, 100);
}
{
    const {execute, video, url, page} = setup();
    page.location.href = 'https://example.com/';
    execute({source:'safari', action:'toggle', key:url}); assert.equal(video.paused, false);
    video.duration = Infinity;
    page.location.href = url;
    assert.equal(execute({source:'safari'}).sessions[0].duration, 0);
}
{
    const {execute, state} = setup();
    execute({source:'spotify', action:'toggle'}); assert.equal(state.spotify.playing, false);
    execute({source:'spotify', action:'seek', position:30}); assert.equal(state.spotify.position, 30);
    execute({source:'spotify', action:'next'}); assert.equal(state.next, true);
}
{
    const {execute, safari} = setup();
    safari.doJavaScript = () => { const error = new Error('Denied'); error.errorNumber = -1743; throw error; };
    assert.equal(execute({source:'safari'}).errors[0].code, -1743);
}
console.log('PASS Spotify and Safari metadata, transport, seeking, YouTube allowlist and permission failures');
