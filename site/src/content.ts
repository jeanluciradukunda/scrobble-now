const base = import.meta.env.BASE_URL;
export const asset = (path: string) => `${base}${path.replace(/^\//, "")}`;

export type FeaturePanel = {
  title: string;
  eyebrow: string;
  body: string;
  stats: string[];
  accent: string;
};

export type SetlistRow = {
  num: string;
  feature: string;
  source: string;
  status: string;
  highlight?: boolean;
};

export const setlistRows: SetlistRow[] = [
  { num: "I", feature: "Live Scrobble Feed", source: "Last.fm", status: "● LIVE", highlight: true },
  { num: "II", feature: "Album Discovery Engine", source: "5 Sources", status: "● SCORING" },
  { num: "III", feature: "Collage Generator", source: "Top Albums", status: "EXPORT" },
  { num: "IV", feature: "Listening History", source: "Timeline", status: "TRACKING" },
  { num: "V", feature: "Statistics Dashboard", source: "Analytics", status: "CHARTED" },
];

export const featurePanels: FeaturePanel[] = [
  {
    eyebrow: "LIVE FEED",
    title: "See what you're listening to without switching windows.",
    body: "Polls your Last.fm profile every 15 seconds and shows the current track, artist, album artwork, and recent scrobble history. All from your menu bar — no browser tab needed.",
    stats: ["15-second live polling", "Album artwork", "Loved track indicators"],
    accent: "feed",
  },
  {
    eyebrow: "ALBUM DISCOVERY",
    title: "Five sources. One scored answer.",
    body: "Tap any album to discover it across Last.fm, Discogs, MusicBrainz, iTunes, and Wikidata simultaneously. Results are scored across five dimensions and merged — artwork, tracks, tags, and external links from every source that found it.",
    stats: ["5 sources in parallel", "5-dimension scoring", "Merged artwork gallery"],
    accent: "discover",
  },
  {
    eyebrow: "COLLAGE GENERATOR",
    title: "Your listening as a grid. Shareable.",
    body: "Generate topsters-style album collages from your listening history. Pick a time period, choose your grid size, toggle titles, and export as a high-resolution PNG or copy to clipboard.",
    stats: ["3×3 to 10×10 grids", "Period selector", "PNG export + clipboard"],
    accent: "collage",
  },
  {
    eyebrow: "LISTENING HISTORY",
    title: "A timeline of everything you've heard.",
    body: "Day-grouped scrobble timeline with timestamps, artwork thumbnails, and loved track indicators. See how many tracks, artists, and albums you hit each day. Tap any track to discover the album.",
    stats: ["Day-grouped timeline", "Track + artist + album counts", "Tap to discover"],
    accent: "history",
  },
  {
    eyebrow: "STATISTICS",
    title: "Numbers that sound good.",
    body: "Total scrobbles, today's count, this week's listening, and your member-since date in big bold numbers. Horizontal bar charts for top artists. Genre breakdown extracted from Last.fm tags with a stacked color bar.",
    stats: ["Top artists bar chart", "Genre breakdown", "FlowingData-inspired"],
    accent: "stats",
  },
];

export const footerFacts = [
  "macOS 14+",
  "SwiftUI + AppKit",
  "5 music APIs",
  "Local-first",
  "Last.fm companion",
  "PNG export",
];

export const FAQ_ITEMS = [
  { q: "Is this app stable yet?", a: "Not fully. Scrobble Now is still in public beta. The core workflow — live feed, album discovery, collages, history — is usable, but the UI, scoring accuracy, and some edge cases are still being refined in the open." },
  { q: "Do I need a Last.fm account?", a: "Yes. Scrobble Now scrobbles to and reads from your Last.fm account. The app ships with its own API key, so you only sign in and authorise it." },
  { q: "Does this app do the scrobbling?", a: "Yes, on the Mac. It detects what is playing in the Spotify and Apple Music apps and on music sites (YouTube, SoundCloud, Bandcamp and more) in Safari and Chrome, and scrobbles it following Last.fm's rules. Each app can be switched off. The iPhone companion shows your Last.fm data but does not scrobble." },
  { q: "Is my data sent anywhere?", a: "Only where it has to go: your scrobbles go to Last.fm, and artist and album names go to the music databases used for artwork and album details. No analytics, no cloud storage, no telemetry." },
  { q: "How does album discovery work?", a: "When you tap an album, five sources are queried in parallel — Last.fm, Discogs, MusicBrainz, iTunes, and Wikidata. Each result is scored on title match, artist match, track count, source trust, and content completeness. External links and artwork from all sources are merged into the top result." },
  { q: "What API keys do I need?", a: "None. The app ships with its own Last.fm API key. If you prefer your own, add it under Settings, Integrations, API Keys, Advanced. Building from source needs your own key in Secrets.plist." },
  { q: "Is the app signed?", a: "Yes. Scrobble Now is signed with an Apple Developer ID certificate and notarized by Apple. Download, install, and it just works — no security warnings or Terminal commands." },
];
