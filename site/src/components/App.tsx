import { For, createSignal, onCleanup, onMount } from "solid-js";
import { setlistRows, featurePanels, footerFacts, FAQ_ITEMS } from "../content";
import { TurntableCutaway, MixingConsole, TapeReelMachine, SpeakerStack } from "./CondecIllustrations";

const TITLE = "SCROBBLE NOW";

const STRIPE_COLORS = ["#d4302b", "#e67a30", "#d4a843", "#e8d44a", "#5d9e4a", "#3a9e8f", "#3a6fb5", "#3a3f8f"];

export function App() {
  const [title, setTitle] = createSignal(TITLE);
  const [navVisible, setNavVisible] = createSignal(false);
  const year = new Date().getFullYear();

  onMount(() => {
    // Title glitch
    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      const handle = setInterval(() => {
        const chars = [...TITLE];
        const idx = Math.floor(Math.random() * chars.length);
        if (chars[idx] !== " ") chars[idx] = " ";
        setTitle(chars.join(""));
        setTimeout(() => setTitle(TITLE), 60);
      }, 4000);
      onCleanup(() => clearInterval(handle));
    }

    // Scroll reveal
    const observer = new IntersectionObserver(
      (entries) => entries.forEach((e) => { if (e.isIntersecting) e.target.classList.add("visible"); }),
      { threshold: 0.1, rootMargin: "0px 0px -40px 0px" }
    );
    document.querySelectorAll(".reveal").forEach((el) => observer.observe(el));
    onCleanup(() => observer.disconnect());

    // Sticky nav
    const heroEl = document.querySelector(".hero-shell");
    if (heroEl) {
      const navObs = new IntersectionObserver(([e]) => setNavVisible(!e.isIntersecting), { threshold: 0 });
      navObs.observe(heroEl);
      onCleanup(() => navObs.disconnect());
    }

    // Parallax on scroll for SVG layers
    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      const onScroll = () => {
        document.querySelectorAll(".parallax-target").forEach((el) => {
          const speed = parseFloat((el as HTMLElement).dataset.speed || "0.02");
          const rect = el.closest("svg")?.getBoundingClientRect();
          if (!rect) return;
          const center = rect.top + rect.height / 2;
          const viewCenter = window.innerHeight / 2;
          const offset = (center - viewCenter) * speed;
          (el as SVGElement).style.transform = `translateY(${offset}px)`;
        });
      };
      window.addEventListener("scroll", onScroll, { passive: true });
      onCleanup(() => window.removeEventListener("scroll", onScroll));
    }
  });

  return (
    <main>
      {/* STICKY NAV */}
      <nav class={`sticky-nav ${navVisible() ? "visible" : ""}`}>
        <a href="#setlist">Setlist</a>
        <a href="#features">Features</a>
        <a href="#how-it-works">How It Works</a>
        <a href="#install">Install</a>
        <a href="#faq">FAQ</a>
      </nav>

      {/* ═══════ HERO ═══════ */}
      <section class="hero-shell">
        <div class="maxwidth">
          <div class="hero-content">
            <div class="hero-text">
              <p class="kicker">macOS Menu Bar Companion for Last.fm</p>
              <div class="hero-headline">
                <h1>{title()}</h1>
              </div>
              {/* Condec rainbow stripe */}
              <div style="display: flex; gap: 2px; margin-top: 1.5rem;">
                <For each={STRIPE_COLORS}>{(c) => <span style={`display:block;width:5px;height:40px;background:${c}`} />}</For>
              </div>
              <p class="hero-desc">
                See what you're listening to, discover albums across five sources,
                generate shareable collages, and visualize your listening habits.
                All from your menu bar. No browser tabs.
              </p>
              <menu class="hero-menu">
                <a href="https://github.com/jeanluciradukunda/scrobble-now/releases/latest">
                  <span>DOWNLOAD APP</span>
                  <small>macOS 14+ · Latest DMG</small>
                </a>
                <a href="https://github.com/jeanluciradukunda/scrobble-now">
                  <span>VIEW SOURCE</span>
                  <small>Swift · SwiftUI · AppKit</small>
                </a>
              </menu>
            </div>
            {/* Hero illustration — turntable cutaway */}
            <div style="flex-shrink: 0; width: 420px;" class="reveal">
              <TurntableCutaway />
            </div>
          </div>
        </div>
      </section>

      {/* ═══════ SETLIST ═══════ */}
      <section class="setlist-shell" id="setlist">
        <div class="maxwidth">
          <div class="setlist-header reveal">
            <div class="setlist-stripes">
              <For each={STRIPE_COLORS}>{(c) => <span style={`background:${c}`} />}</For>
            </div>
            <h2 class="setlist-title">Tonight's Setlist</h2>
            <div class="setlist-stripes">
              <For each={STRIPE_COLORS}>{(c) => <span style={`background:${c}`} />}</For>
            </div>
          </div>
          <div class="setlist-board">
            <div class="setlist-row setlist-row-header reveal">
              <span class="setlist-col col-num">#</span>
              <span class="setlist-col col-feature">Feature</span>
              <span class="setlist-col">Source</span>
              <span class="setlist-col col-status">Status</span>
            </div>
            <For each={setlistRows}>
              {(row, i) => (
                <div class={`setlist-row reveal reveal-delay-${i() + 1}`} classList={{ "setlist-active": row.highlight }}>
                  <span class="setlist-col col-num">{row.num}</span>
                  <span class="setlist-col col-feature">{row.feature}</span>
                  <span class="setlist-col">{row.source}</span>
                  <span class="setlist-col col-status">{row.status}</span>
                </div>
              )}
            </For>
          </div>
          <p class="setlist-footer reveal">All features available now · Local data · No account sharing</p>
        </div>
      </section>

      {/* ═══════ FEATURES ═══════ */}
      <section class="feature-shell" id="features">
        <div class="maxwidth">
          <div class="section-head reveal">
            <p class="kicker">What You Get</p>
            <h2>Five instruments in one menu bar.</h2>
          </div>
          <div class="feature-grid">
            <For each={featurePanels}>
              {(panel, i) => (
                <article class={`feature-panel accent-${panel.accent} reveal reveal-delay-${(i() % 3) + 1}`}>
                  <div>
                    <p class="eyebrow">{panel.eyebrow}</p>
                    <h3>{panel.title}</h3>
                    <p>{panel.body}</p>
                    <ul>
                      <For each={panel.stats}>{(s) => <li>{s}</li>}</For>
                    </ul>
                  </div>
                  <div class="feature-visual">
                    {i() === 0 && <SpeakerStack />}
                    {i() === 1 && <MixingConsole />}
                    {i() === 2 && <TurntableCutaway />}
                    {i() === 3 && <TapeReelMachine />}
                    {i() === 4 && <SpeakerStack />}
                  </div>
                </article>
              )}
            </For>
          </div>
        </div>
      </section>

      {/* ═══════ EDITORIAL ═══════ */}
      <section class="editorial-shell" id="how-it-works">
        <div class="maxwidth editorial-grid">
          <div class="section-head reveal">
            <p class="kicker">How It Works</p>
            <h2>Read-only. Local data. Five sources scored.</h2>
          </div>
          <div class="editorial-stack">
            <article class="paper-card reveal">
              <p class="eyebrow">What Ships</p>
              <p>
                See what's playing in real-time from your Last.fm profile. Discover any album across
                five music databases simultaneously — scored, ranked, and merged. Generate shareable
                album collages. Browse your top albums and artists by period. Visualize your listening
                in beautiful charts.
              </p>
            </article>
            <article class="paper-card reveal reveal-delay-2">
              <p class="eyebrow">Technical Stack</p>
              <ul class="paper-list">
                <li>macOS 14+ / SwiftUI / AppKit</li>
                <li>Menu bar resident — no Dock icon</li>
                <li>Local JSON persistence, no cloud</li>
                <li>Last.fm + Discogs + MusicBrainz + iTunes + Wikidata</li>
                <li>5-dimension weighted scoring engine</li>
                <li>PNG collage export at 300px per cell</li>
              </ul>
            </article>
          </div>
        </div>
      </section>

      {/* ═══════ ORIGIN STORY ═══════ */}
      <section class="origin-shell">
        <div class="maxwidth origin-content reveal">
          <blockquote class="origin-quote">
            "I kept checking Last.fm in a browser tab to see what was playing,
            searching Discogs for album art separately, and losing track of what
            I'd been listening to all week. So I built a menu bar app that does
            all of that without leaving what I'm working on."
          </blockquote>
          <p class="origin-caption">— The entire reason this exists</p>
          {/* Condec stripe */}
          <div style="display: flex; gap: 2px; justify-content: center; margin-top: 1.5rem;">
            <For each={STRIPE_COLORS}>{(c) => <span style={`display:block;width:4px;height:30px;background:${c}`} />}</For>
          </div>
        </div>
      </section>

      {/* ═══════ INSTALL GUIDE ═══════ */}
      <section class="install-shell" id="install">
        <div class="maxwidth">
          <div class="section-head reveal">
            <p class="kicker">Soundcheck</p>
            <h2>Installation in four tracks.</h2>
          </div>
          <div class="install-grid">
            <div class="install-step reveal reveal-delay-1">
              <span class="install-step-num">TRACK 1</span>
              <h4>Download</h4>
              <p>Grab the latest DMG from GitHub Releases. Single .app bundle, no installer.</p>
            </div>
            <div class="install-step reveal reveal-delay-2">
              <span class="install-step-num">TRACK 2</span>
              <h4>Applications</h4>
              <p>Drag Scrobble Now.app into your Applications folder.</p>
            </div>
            <div class="install-step reveal reveal-delay-3">
              <span class="install-step-num">TRACK 3</span>
              <h4>Open</h4>
              <p>Unsigned app — right-click, choose Open, click Open again.</p>
              <code>Right-click → Open → Open</code>
            </div>
            <div class="install-step reveal reveal-delay-4">
              <span class="install-step-num">TRACK 4</span>
              <h4>Connect</h4>
              <p>Enter your Last.fm username in Settings. Your scrobble feed appears in seconds.</p>
            </div>
          </div>
        </div>
      </section>

      {/* ═══════ FAQ ═══════ */}
      <section class="faq-shell" id="faq">
        <div class="maxwidth">
          <div class="section-head reveal">
            <p class="kicker">Liner Notes</p>
            <h2>Before you press play.</h2>
          </div>
          <div class="faq-list">
            <For each={FAQ_ITEMS}>
              {(item) => <FAQItem question={item.q} answer={item.a} />}
            </For>
          </div>
        </div>
      </section>

      {/* ═══════ FOOTER ═══════ */}
      <footer class="site-footer">
        <div class="maxwidth footer-grid">
          <div>
            <p class="kicker">Scrobble Now / {year}</p>
            <h2>One app. Your music. Visible.</h2>
          </div>
          <div class="footer-meta">
            <ul class="footer-facts">
              <For each={footerFacts}>{(f) => <li>{f}</li>}</For>
            </ul>
            <div class="footer-links">
              <a href="https://github.com/jeanluciradukunda/scrobble-now/releases/latest">DOWNLOAD</a>
              <a href="https://github.com/jeanluciradukunda/scrobble-now">SOURCE</a>
            </div>
          </div>
        </div>
        <div class="maxwidth footer-legal">
          <p>
            Scrobble Now is an independent, non-commercial, open-source project released under the
            {" "}<a href="https://opensource.org/licenses/MIT" target="_blank" rel="noopener">MIT License</a>.
            It is not affiliated with or endorsed by Last.fm, CBS Interactive, or Audioscrobbler.
            Album data is sourced from
            {" "}<a href="https://www.last.fm/" target="_blank" rel="noopener">Last.fm</a>,
            {" "}<a href="https://musicbrainz.org/" target="_blank" rel="noopener">MusicBrainz</a>,
            {" "}<a href="https://www.discogs.com/" target="_blank" rel="noopener">Discogs</a>,
            {" "}<a href="https://www.wikidata.org/" target="_blank" rel="noopener">Wikidata</a>,
            and the iTunes Search API.
          </p>
        </div>
      </footer>
    </main>
  );
}

function FAQItem(props: { question: string; answer: string }) {
  const [open, setOpen] = createSignal(false);
  return (
    <div class="faq-item reveal" classList={{ open: open() }}>
      <button type="button" class="faq-question" onClick={() => setOpen((o) => !o)}>
        {props.question}
        <span class="faq-chevron">▸</span>
      </button>
      <div class="faq-answer">
        <p>{props.answer}</p>
      </div>
    </div>
  );
}
