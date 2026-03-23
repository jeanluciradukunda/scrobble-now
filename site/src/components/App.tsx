import { For, createSignal, onCleanup, onMount } from "solid-js";
import { FAQ_ITEMS } from "../content";

const base = import.meta.env.BASE_URL;
const img = (name: string) => `${base}assets/illustrations/${name}`;
const STRIPE_COLORS = ["#d4302b", "#e67a30", "#d4a843", "#e8d44a", "#5d9e4a", "#3a9e8f", "#3a6fb5", "#3a3f8f"];

export function App() {
  const [navVisible, setNavVisible] = createSignal(false);
  const year = new Date().getFullYear();

  onMount(() => {
    // Scroll reveal
    const obs = new IntersectionObserver(
      (entries) => entries.forEach((e) => { if (e.isIntersecting) e.target.classList.add("visible"); }),
      { threshold: 0.08, rootMargin: "0px 0px -30px 0px" }
    );
    document.querySelectorAll(".reveal").forEach((el) => obs.observe(el));
    onCleanup(() => obs.disconnect());

    // Sticky nav
    const hero = document.querySelector(".cover");
    if (hero) {
      const navObs = new IntersectionObserver(([e]) => setNavVisible(!e.isIntersecting), { threshold: 0 });
      navObs.observe(hero);
      onCleanup(() => navObs.disconnect());
    }

    // Parallax
    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      const onScroll = () => {
        const scrollY = window.scrollY;
        document.querySelectorAll<HTMLElement>(".cover-layer").forEach((el) => {
          const speed = parseFloat(el.dataset.parallax || "0.1");
          el.style.transform = `translateY(${scrollY * speed}px) scale(${1 + Math.abs(speed) * 0.3})`;
        });
        document.querySelectorAll<HTMLElement>(".float-img").forEach((el) => {
          const rect = el.getBoundingClientRect();
          const progress = (window.innerHeight - rect.top) / (window.innerHeight + rect.height);
          el.style.transform = `translateY(${(progress - 0.5) * -30}px)`;
        });
        // Gallery scroll-jack
        const gs = document.querySelector<HTMLElement>(".gallery-bleed");
        const g = document.querySelector<HTMLElement>(".gallery-scroll");
        if (gs && g) {
          const r = gs.getBoundingClientRect();
          const p = Math.max(0, Math.min(1, -r.top / (gs.offsetHeight - window.innerHeight)));
          g.style.transform = `translateX(${-p * (g.scrollWidth - window.innerWidth)}px)`;
        }
      };
      window.addEventListener("scroll", onScroll, { passive: true });
      onCleanup(() => window.removeEventListener("scroll", onScroll));
    }
  });

  return (
    <main>
      <nav class={`sticky-nav ${navVisible() ? "visible" : ""}`}>
        <a href="#report">Report</a>
        <a href="#gallery">Gallery</a>
        <a href="#appendix">Appendix</a>
      </nav>

      {/* ═══════ COVER PAGE ═══════ */}
      <section class="cover">
        <div class="cover-illustration">
          <img src={img("hero-bg.jpg")} alt="" class="cover-layer" data-parallax="-0.15" />
          <img src={img("hero-mid.png")} alt="" class="cover-layer" data-parallax="-0.35" />
          <img src={img("hero-fg.png")} alt="" class="cover-layer" data-parallax="-0.55" />
        </div>
        <div class="cover-text">
          <img src={`${base}assets/title-scrobble-now.png`} alt="Scrobble Now" class="cover-title" />
          <div class="condec-stripe-h">
            <For each={STRIPE_COLORS}>{(c) => <span style={`background:${c}`} />}</For>
          </div>
          <p class="cover-sub">
            Annual Product Report<br />
            For the Year Ended {year}
          </p>
        </div>
        <span class="page-num" style="bottom:1.5rem;right:2.5rem;color:var(--muted)">1</span>
      </section>

      {/* ═══════ THE REPORT — single flowing document ═══════ */}
      <article class="report" id="report">

        {/* Page 2-3: Introduction */}
        <section class="report-spread reveal">
          <div class="report-page page-left">
            <img src={img("te-zamrock-studio.jpg")} alt="" class="page-full-img float-img" />
          </div>
          <div class="report-page page-right">
            <h2>On the Threshold of Listening</h2>
            <p>
              As we stand on the threshold of a new era in music discovery,
              the listener appears ready to embark on a transformation of how
              they engage with their own habits. The average Last.fm user
              scrobbles thousands of tracks per year — but rarely sees the
              shape of their listening.
            </p>
            <p>
              Scrobble Now was built to change that. A macOS menu bar companion
              that reads your Last.fm profile and transforms raw scrobble data
              into five distinct instruments — each one a different way to
              see, explore, and share your music.
            </p>
            <p>
              With the thrust of multi-source album discovery as the focal
              point, we can see new patterns already taking shape that promise
              opportunities for remarkable engagement in the years ahead.
            </p>
            <span class="page-num pn-left">2</span>
            <span class="page-num pn-right">3</span>
          </div>
        </section>

        {/* Page 4-5: Live Feed */}
        <section class="report-spread reveal">
          <div class="report-page page-left">
            <h2>Live Feed</h2>
            <p>
              The live feed polls your Last.fm profile every fifteen seconds,
              surfacing the current track, artist, album artwork, and your
              recent scrobble history directly in the menu bar. No browser
              tab. No window switching.
            </p>
            <p>
              Loved tracks are indicated with a heart. The now-playing card
              shows album art at a glance. Tap any track to open the album
              discovery engine.
            </p>
            <img src={img("workers-broadcast.jpg")} alt="" class="inset-img float-img reveal" />
            <p>
              The feed updates automatically, maintaining a rolling window
              of your most recent listening activity. When a new track
              begins, it appears at the top within seconds.
            </p>
            <span class="page-num pn-left">4</span>
          </div>
          <div class="report-page page-right">
            <img src={img("discovery-mid.png")} alt="" class="page-full-img float-img" />
            <span class="page-num pn-right">5</span>
          </div>
        </section>

        {/* Page 6-7: Album Discovery */}
        <section class="report-spread reveal">
          <div class="report-page page-left">
            <img src={img("te-modular.jpg")} alt="" class="page-full-img float-img" />
          </div>
          <div class="report-page page-right">
            <h2>Album Discovery</h2>
            <p>
              Five music databases — Last.fm, Discogs, MusicBrainz, iTunes,
              and Wikidata — are queried simultaneously when you tap an album.
              Each result is scored across five dimensions: title match, artist
              match, track count, source trust, and content completeness.
            </p>
            <p>
              The highest-scoring result inherits external links, artwork, tags,
              and track listings from every source that found it. A single album
              view may contain Discogs cover art, MusicBrainz track durations,
              Last.fm listener counts, and an Apple Music link — all merged.
            </p>
            <div class="report-stats">
              <div><strong>5</strong> sources in parallel</div>
              <div><strong>5</strong> scoring dimensions</div>
              <div><strong>15s</strong> average discovery time</div>
            </div>
            <span class="page-num pn-left">6</span>
            <span class="page-num pn-right">7</span>
          </div>
        </section>

        {/* Page 8-9: Collage Generator */}
        <section class="report-spread reveal">
          <div class="report-page page-left">
            <h2>Collage Generator</h2>
            <p>
              Inspired by topsters.org, the collage generator creates album
              cover grids from your listening history. Select a time period —
              seven days, one month, three months, six months, twelve months,
              or all time — and a grid size from 3×3 to 10×10.
            </p>
            <img src={img("collage-mid.jpg")} alt="" class="inset-img float-img reveal" />
            <p>
              Toggle title overlays on or off. Export as a high-resolution PNG
              (300 pixels per cell — a 5×5 grid exports at 1500×1500) or copy
              directly to clipboard for sharing.
            </p>
            <p>
              Album artwork is pre-downloaded in parallel before render, so
              the export never blocks on network requests.
            </p>
            <span class="page-num pn-left">8</span>
          </div>
          <div class="report-page page-right">
            <img src={img("te-vinyl-machine.jpg")} alt="" class="page-full-img float-img" />
            <span class="page-num pn-right">9</span>
          </div>
        </section>

        {/* Page 10-11: History + Stats */}
        <section class="report-spread reveal">
          <div class="report-page page-left">
            <img src={img("history-mid.png")} alt="" class="page-full-img float-img" />
          </div>
          <div class="report-page page-right">
            <h2>History &amp; Statistics</h2>
            <p>
              The listening history presents your scrobbles as a day-grouped
              timeline — timestamps, artwork thumbnails, loved indicators, and
              per-day counts of tracks, artists, and albums. Tap any track
              to discover its album.
            </p>
            <p>
              The statistics dashboard surfaces your total scrobble count,
              today's activity, this week's total, and your member-since date.
              A horizontal bar chart ranks your top ten artists for the period.
              Genre breakdown is extracted from Last.fm tags and rendered as
              a stacked color bar.
            </p>
            <img src={img("stats-mid.png")} alt="" class="inset-img float-img reveal" style="max-height:160px" />
            <span class="page-num pn-left">10</span>
            <span class="page-num pn-right">11</span>
          </div>
        </section>

        {/* Page 12: Technical */}
        <section class="report-single reveal">
          <div class="report-page page-center">
            <h2>Technical Stack</h2>
            <div class="two-col">
              <div>
                <p>
                  Scrobble Now is built entirely in Swift using SwiftUI and AppKit,
                  targeting macOS 14 Sonoma and later. It runs as a menu bar
                  resident application with no Dock icon, appearing only as an
                  icon in the system menu bar.
                </p>
                <p>
                  All data is stored locally in ~/Library/Application Support as
                  plain JSON files. No cloud. No analytics. No telemetry. The
                  application makes read-only API calls to Last.fm, Discogs,
                  MusicBrainz, iTunes Search, and Wikidata SPARQL.
                </p>
              </div>
              <div>
                <p>
                  The scoring engine uses Levenshtein distance for fuzzy title
                  and artist matching, with multiplicative source trust weighting.
                  Results above the configurable confidence threshold are
                  deduplicated by normalized album name and merged across sources.
                </p>
                <p>
                  Collage rendering uses NSBitmapImageRep for direct pixel
                  composition, bypassing SwiftUI's rendering pipeline for
                  reliable high-resolution PNG export.
                </p>
              </div>
            </div>
            <span class="page-num pn-left">12</span>
          </div>
        </section>
      </article>

      {/* ═══════ GALLERY — horizontal scroll of illustrations ═══════ */}
      <section class="gallery-bleed" id="gallery">
        <div class="gallery-sticky">
          <div class="gallery-scroll">
            <img src={img("te-modular.jpg")} alt="" />
            <img src={img("workers-gears.jpg")} alt="" />
            <img src={img("te-pocket-ops.jpg")} alt="" />
            <img src={img("workers-synth.jpg")} alt="" />
            <img src={img("zamrock-collage.jpg")} alt="" />
            <img src={img("workers-assembly.jpg")} alt="" />
            <img src={img("workers-pressing.jpg")} alt="" />
          </div>
        </div>
      </section>

      {/* ═══════ APPENDIX — install + FAQ + credits, dense like back matter ═══════ */}
      <section class="appendix" id="appendix">
        <div class="appendix-grid">

          {/* Left column: Installation + Credits */}
          <div class="appendix-col">
            <h2>Installation</h2>
            <ol class="install-list">
              <li>Download the latest DMG from <a href="https://github.com/jeanluciradukunda/scrobble-now/releases/latest">GitHub Releases</a>.</li>
              <li>Drag <strong>Scrobble Now.app</strong> into Applications.</li>
              <li>Right-click the app → Open → Open (unsigned app bypass).</li>
              <li>Enter your Last.fm username in Settings. Your feed appears in seconds.</li>
            </ol>

            <h2>Requirements</h2>
            <ul class="req-list">
              <li>macOS 14 Sonoma or later</li>
              <li>Last.fm account + free API key (<a href="https://www.last.fm/api" target="_blank">last.fm/api</a>)</li>
              <li>Optional: Discogs token (<a href="https://www.discogs.com/settings/developers" target="_blank">discogs.com</a>)</li>
            </ul>

            <h2>Credits</h2>
            <p class="credits-text">
              Illustrations generated in the style of Arno Sternglass's
              Condec Corporation Annual Report, 1969. Body text set in
              Crimson Text. Headings in Michroma. Title calligraphy generated
              via Nano Banana 2. Built with SwiftUI, AppKit, SolidJS, and Vite.
            </p>

            <div class="appendix-links">
              <a href="https://github.com/jeanluciradukunda/scrobble-now/releases/latest">Download</a>
              <a href="https://github.com/jeanluciradukunda/scrobble-now">Source Code</a>
            </div>
          </div>

          {/* Right column: FAQ */}
          <div class="appendix-col">
            <h2>Frequently Asked Questions</h2>
            <For each={FAQ_ITEMS}>
              {(item) => (
                <div class="faq-entry">
                  <p class="faq-q">{item.q}</p>
                  <p class="faq-a">{item.a}</p>
                </div>
              )}
            </For>
          </div>
        </div>
      </section>

      {/* ═══════ FOOTER — minimal, like report back cover ═══════ */}
      <footer class="back-cover">
        <div class="condec-stripe-h" style="justify-content:center">
          <For each={STRIPE_COLORS}>{(c) => <span style={`background:${c};height:120px`} />}</For>
        </div>
        <p class="back-cover-text">
          Scrobble Now / {year}<br />
          <a href="https://github.com/jeanluciradukunda/scrobble-now">github.com/jeanluciradukunda/scrobble-now</a>
        </p>
        <p class="legal-text">
          Not affiliated with Last.fm or CBS Interactive. Data from Last.fm,
          MusicBrainz, Discogs, Wikidata, and iTunes Search API.
          Released under the MIT License.
        </p>
      </footer>
    </main>
  );
}
