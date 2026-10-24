// Explicit application automation only. Safari DOM access is restricted to
// YouTube hosts, and commands revalidate the exact tab URL before execution.
ObjC.import('Foundation');
function run(argv) {
    const request = JSON.parse(argv[0] || '{}');
    const sessions = [], errors = [];
    const sources = request.source === 'automatic' ? ['spotify', 'safari', 'music'] : [request.source];
    function text(value) { return value === null || value === undefined ? '' : String(value); }
    function number(value) { value = Number(value); return isFinite(value) ? Math.max(0, value) : 0; }
    function failure(source, error) {
        errors.push({source: source, code: Number(error.errorNumber) || 0, message: text(error.message)});
    }
    function youtube(url) { return /^https:\/\/(?:www\.|m\.|music\.)?youtube\.com\//i.test(url) || /^https:\/\/youtu\.be\//i.test(url); }
    function native(source) {
        const app = Application(source === 'spotify' ? 'com.spotify.client' : 'com.apple.Music');
        if (!app.running()) return;
        const state = text(app.playerState());
        if (state === 'stopped') return;
        const track = app.currentTrack();
        if (request.action) {
            if (request.action === 'toggle') app.playpause();
            else if (request.action === 'next') app.nextTrack();
            else if (request.action === 'previous') app.previousTrack();
            else if (request.action === 'seek') app.playerPosition = number(request.position);
            return;
        }
        let artwork = null;
        if (source === 'spotify') { try { artwork = text(track.artworkUrl()); } catch (_) {} }
        sessions.push({source: source, key: text(source === 'spotify' ? track.id() : track.persistentID()),
            title: text(track.name()), artist: text(track.artist()), album: text(track.album()), playing: state === 'playing',
            position: number(app.playerPosition()), duration: number(track.duration()) / (source === 'spotify' ? 1000 : 1), artwork: artwork});
    }
    function safari() {
        const app = Application('com.apple.Safari');
        if (!app.running()) return;
        let inspected = 0;
        const windows = app.windows();
        for (let w = 0; w < windows.length; w++) {
            const tabs = windows[w].tabs();
            for (let t = 0; t < tabs.length && inspected < 30; t++) {
                const tab = tabs[t], url = text(tab.url());
                if (!youtube(url) || (request.action && url !== request.key)) continue;
                inspected++;
                const payload = JSON.stringify({action: request.action || '', position: number(request.position), key: url});
                const script = '(' + function (input) {
                    if (location.href !== input.key || !/^(www\.|m\.|music\.)?youtube\.com$|^youtu\.be$/.test(location.hostname)) return null;
                    const video = document.querySelector('video');
                    if (!video) return null;
                    const finite = function (v) { return Number.isFinite(v) ? Math.max(0, v) : 0; };
                    if (input.action) {
                        if (input.action === 'toggle') { if (video.paused) video.play().catch(function () {}); else video.pause(); }
                        else if (input.action === 'next') video.currentTime = Math.min(Number.isFinite(video.duration) ? video.duration : Infinity, video.currentTime + 10);
                        else if (input.action === 'previous') video.currentTime = Math.max(0, video.currentTime - 10);
                        else if (input.action === 'seek' && Number.isFinite(video.duration)) video.currentTime = Math.min(video.duration, input.position);
                        return JSON.stringify({ok: true});
                    }
                    const metadata = navigator.mediaSession && navigator.mediaSession.metadata;
                    const heading = document.querySelector('ytd-watch-metadata h1, h1.ytd-watch-metadata, .title.ytmusic-player-bar');
                    const channel = document.querySelector('ytd-watch-metadata ytd-channel-name a, #owner #channel-name a');
                    const image = document.querySelector('meta[property="og:image"]');
                    return JSON.stringify({source: 'safari', key: location.href,
                        title: (metadata && metadata.title) || (heading && heading.textContent.trim()) || document.title.replace(/ - YouTube$/, ''),
                        artist: (metadata && metadata.artist) || (channel && channel.textContent.trim()) || 'YouTube',
                        album: (metadata && metadata.album) || '', playing: !video.paused && !video.ended,
                        position: finite(video.currentTime), duration: finite(video.duration),
                        artwork: (metadata && metadata.artwork && metadata.artwork[0] && metadata.artwork[0].src) || (image && image.content) || null});
                }.toString() + ')(' + payload + ')';
                const result = app.doJavaScript(script, {in: tab});
                if (request.action) return;
                if (result) {
                    const session = JSON.parse(result);
                    if (session && session.title) sessions.push(session);
                }
            }
        }
    }
    sources.forEach(function (source) {
        try { if (source === 'safari') safari(); else native(source); }
        catch (error) { failure(source, error); }
    });
    return JSON.stringify({sessions: sessions, errors: errors});
}
