/** Condec 1969-inspired multi-layered SVG illustrations for parallax sections.
 *  Colored pencil / gouache style: sepia linework, bold color block accents,
 *  crosshatch texture, layered depth planes. */

// ═══════════ TURNTABLE CUTAWAY — hero illustration ═══════════
export function TurntableCutaway() {
  return (
    <svg viewBox="0 0 600 500" fill="none" xmlns="http://www.w3.org/2000/svg" class="condec-svg">
      {/* Background plane — warm shadow */}
      <rect x="40" y="60" width="520" height="380" rx="4" fill="#e8dfc9" />

      {/* Cabinet body */}
      <path d="M80 120 L520 120 L540 140 L540 400 L60 400 L60 140Z" fill="#8b7355" class="parallax-target" data-speed="0.02" />
      <path d="M80 120 L520 120 L540 140 L60 140Z" fill="#6b5e52" /> {/* top edge */}

      {/* Platter well — darker recess */}
      <ellipse cx="280" cy="260" rx="150" ry="130" fill="#3d3530" />
      <ellipse cx="280" cy="260" rx="140" ry="120" fill="#1c1815" />

      {/* Record on platter */}
      <ellipse cx="280" cy="258" rx="120" ry="105" fill="#1c1815" stroke="#3d3530" stroke-width="0.5" />
      {/* Grooves */}
      {[95, 85, 75, 65, 55, 45].map(r => (
        <ellipse cx="280" cy="258" rx={r} ry={r * 0.87} fill="none" stroke="#3d3530" stroke-width="0.3" />
      ))}
      {/* Label */}
      <ellipse cx="280" cy="258" rx="28" ry="24" fill="#d4302b" />
      <ellipse cx="280" cy="258" rx="24" ry="21" fill="none" stroke="#1c1815" stroke-width="0.5" />
      <text x="280" y="255" font-family="Departure Mono, monospace" font-size="6" fill="#f5f0e4" text-anchor="middle">LAST.FM</text>
      <text x="280" y="265" font-family="Departure Mono, monospace" font-size="4" fill="#f5f0e4" text-anchor="middle" opacity="0.7">45 RPM</text>
      {/* Spindle */}
      <ellipse cx="280" cy="258" rx="4" ry="3.5" fill="#d4a843" />

      {/* Tonearm — bold color accent */}
      <g class="parallax-target" data-speed="0.04">
        <line x1="440" y1="140" x2="440" y2="180" stroke="#6b5e52" stroke-width="6" stroke-linecap="round" />
        <line x1="440" y1="180" x2="340" y2="240" stroke="#3d3530" stroke-width="3" stroke-linecap="round" />
        <line x1="340" y1="240" x2="320" y2="250" stroke="#3a3f8f" stroke-width="2" stroke-linecap="round" /> {/* headshell - indigo */}
        <circle cx="440" cy="175" r="8" fill="#d4a843" stroke="#8b7355" stroke-width="1" />
        <rect x="314" y="245" width="14" height="8" rx="2" fill="#3a6fb5" /> {/* cartridge - blue */}
      </g>

      {/* Speed selector — colored buttons */}
      <g class="parallax-target" data-speed="0.01">
        <rect x="460" y="320" width="50" height="50" rx="4" fill="#6b5e52" />
        <circle cx="475" cy="335" r="6" fill="#d4302b" /> {/* 33 */}
        <circle cx="495" cy="335" r="6" fill="#d4a843" /> {/* 45 */}
        <circle cx="475" cy="355" r="6" fill="#5d9e4a" /> {/* 78 */}
        <circle cx="495" cy="355" r="6" fill="#3d3530" /> {/* off */}
        <text x="475" y="338" font-family="Departure Mono, monospace" font-size="4" fill="white" text-anchor="middle">33</text>
        <text x="495" y="338" font-family="Departure Mono, monospace" font-size="4" fill="white" text-anchor="middle">45</text>
      </g>

      {/* VU meters — Condec rainbow stripe accent */}
      <g class="parallax-target" data-speed="0.03">
        <rect x="100" y="320" width="120" height="50" rx="3" fill="#1c1815" />
        <rect x="108" y="328" width="46" height="34" rx="2" fill="#f5f0e4" opacity="0.9" />
        <rect x="162" y="328" width="46" height="34" rx="2" fill="#f5f0e4" opacity="0.9" />
        {/* Needle arcs */}
        <line x1="131" y1="358" x2="120" y2="335" stroke="#d4302b" stroke-width="1" />
        <line x1="185" y1="358" x2="178" y2="335" stroke="#d4302b" stroke-width="1" />
        {/* Scale marks */}
        {[112, 118, 124, 130, 136, 142, 148].map(x => (
          <line x1={x} y1="330" x2={x} y2="333" stroke="#3d3530" stroke-width="0.5" />
        ))}
      </g>

      {/* Rainbow stripe — Condec signature motif */}
      {["#d4302b", "#e67a30", "#d4a843", "#e8d44a", "#5d9e4a", "#3a9e8f", "#3a6fb5", "#3a3f8f"].map((color, i) => (
        <rect x={250 + i * 8} y="400" width="6" height="60" fill={color} />
      ))}

      {/* Crosshatch texture overlay (pencil feel) */}
      <defs>
        <pattern id="crosshatch" width="8" height="8" patternUnits="userSpaceOnUse">
          <line x1="0" y1="0" x2="8" y2="8" stroke="#8b7355" stroke-width="0.2" opacity="0.15" />
          <line x1="8" y1="0" x2="0" y2="8" stroke="#8b7355" stroke-width="0.2" opacity="0.1" />
        </pattern>
      </defs>
      <rect x="60" y="120" width="480" height="280" fill="url(#crosshatch)" opacity="0.3" />

      {/* Technical label */}
      <text x="80" y="430" font-family="Departure Mono, monospace" font-size="7" fill="#9c8e7e" letter-spacing="0.15em">SCROBBLE NOW · TECHNICAL DIAGRAM NO. 1 · LISTENING APPARATUS</text>
    </svg>
  );
}

// ═══════════ MIXING CONSOLE — features illustration ═══════════
export function MixingConsole() {
  return (
    <svg viewBox="0 0 500 400" fill="none" xmlns="http://www.w3.org/2000/svg" class="condec-svg">
      {/* Console body */}
      <path d="M30 100 L470 100 L490 130 L490 360 L10 360 L10 130Z" fill="#6b5e52" />
      <path d="M30 100 L470 100 L490 130 L10 130Z" fill="#8b7355" />

      {/* Channel strips — each a different accent color */}
      {[
        { x: 40, color: "#d4302b", label: "LF", level: 0.8 },
        { x: 110, color: "#e67a30", label: "DC", level: 0.6 },
        { x: 180, color: "#d4a843", label: "MB", level: 0.9 },
        { x: 250, color: "#5d9e4a", label: "IT", level: 0.4 },
        { x: 320, color: "#3a6fb5", label: "WD", level: 0.5 },
        { x: 390, color: "#6a3e8f", label: "MX", level: 0.7 },
      ].map(ch => (
        <g class="parallax-target" data-speed={`${0.01 + Math.random() * 0.03}`}>
          {/* Channel strip background */}
          <rect x={ch.x} y="140" width="60" height="200" rx="2" fill="#3d3530" />

          {/* Knob */}
          <circle cx={ch.x + 30} cy="165" r="10" fill="#1c1815" stroke={ch.color} stroke-width="1.5" />
          <line x1={ch.x + 30} y1="158" x2={ch.x + 30} y2="165" stroke={ch.color} stroke-width="2" />

          {/* Fader track */}
          <rect x={ch.x + 26} y="190" width="8" height="120" rx="2" fill="#1c1815" />
          {/* Fader position */}
          <rect x={ch.x + 22} y={190 + (1 - ch.level) * 100} width="16" height="12" rx="2" fill={ch.color} />

          {/* Label */}
          <text x={ch.x + 30} y="330" font-family="Departure Mono, monospace" font-size="7" fill="#f5f0e4" text-anchor="middle">{ch.label}</text>

          {/* Level indicator dots */}
          {Array.from({ length: 8 }, (_, i) => (
            <circle cx={ch.x + 55} cy={310 - i * 12} r="2"
              fill={i < Math.floor(ch.level * 8) ? ch.color : "#3d3530"} />
          ))}
        </g>
      ))}

      {/* Master output meters */}
      <rect x="460" y="140" width="20" height="200" rx="2" fill="#1c1815" />
      <rect x="462" y="200" width="7" height="138" rx="1" fill="#5d9e4a" opacity="0.7" />
      <rect x="471" y="220" width="7" height="118" rx="1" fill="#5d9e4a" opacity="0.7" />

      {/* Crosshatch */}
      <rect x="10" y="100" width="480" height="260" fill="url(#crosshatch)" opacity="0.2" />

      <text x="30" y="380" font-family="Departure Mono, monospace" font-size="7" fill="#9c8e7e" letter-spacing="0.15em">DIAGRAM NO. 2 · MULTI-SOURCE SCORING CONSOLE</text>
    </svg>
  );
}

// ═══════════ TAPE REEL — history illustration ═══════════
export function TapeReelMachine() {
  return (
    <svg viewBox="0 0 500 350" fill="none" xmlns="http://www.w3.org/2000/svg" class="condec-svg">
      {/* Machine body */}
      <rect x="30" y="40" width="440" height="270" rx="6" fill="#6b5e52" />
      <rect x="34" y="44" width="432" height="262" rx="4" fill="none" stroke="#8b7355" stroke-width="0.5" />

      {/* Left reel */}
      <g class="parallax-target" data-speed="0.03">
        <circle cx="160" cy="160" r="80" fill="#3d3530" stroke="#8b7355" stroke-width="1" />
        <circle cx="160" cy="160" r="70" fill="#1c1815" />
        {/* Spokes */}
        {[0, 120, 240].map(angle => {
          const rad = (angle * Math.PI) / 180;
          return <line x1="160" y1="160" x2={160 + 62 * Math.cos(rad)} y2={160 + 62 * Math.sin(rad)} stroke="#3d3530" stroke-width="4" />;
        })}
        {/* Windows */}
        {[60, 180, 300].map(angle => {
          const rad = (angle * Math.PI) / 180;
          return <circle cx={160 + 40 * Math.cos(rad)} cy={160 + 40 * Math.sin(rad)} r="14" fill="#3d3530" />;
        })}
        {/* Hub */}
        <circle cx="160" cy="160" r="15" fill="#d4302b" />
        <circle cx="160" cy="160" r="4" fill="#d4a843" />
      </g>

      {/* Right reel */}
      <g class="parallax-target" data-speed="0.02">
        <circle cx="340" cy="160" r="80" fill="#3d3530" stroke="#8b7355" stroke-width="1" />
        <circle cx="340" cy="160" r="70" fill="#1c1815" />
        {[0, 120, 240].map(angle => {
          const rad = (angle * Math.PI) / 180;
          return <line x1="340" y1="160" x2={340 + 62 * Math.cos(rad)} y2={160 + 62 * Math.sin(rad)} stroke="#3d3530" stroke-width="4" />;
        })}
        {[60, 180, 300].map(angle => {
          const rad = (angle * Math.PI) / 180;
          return <circle cx={340 + 40 * Math.cos(rad)} cy={160 + 40 * Math.sin(rad)} r="14" fill="#3d3530" />;
        })}
        <circle cx="340" cy="160" r="15" fill="#3a6fb5" />
        <circle cx="340" cy="160" r="4" fill="#d4a843" />
      </g>

      {/* Tape path */}
      <path d="M230 160 Q250 260 270 260 L250 260 Q250 160 270 160" stroke="#8b7355" stroke-width="2" fill="none" />

      {/* Head assembly — blue/gold accent */}
      <rect x="235" y="240" width="30" height="30" rx="3" fill="#3a6fb5" />
      <rect x="240" y="245" width="20" height="10" rx="1" fill="#d4a843" />

      {/* Controls — colored buttons */}
      <g class="parallax-target" data-speed="0.01">
        {[
          { x: 100, color: "#d4302b", label: "●" },
          { x: 140, color: "#5d9e4a", label: "▶" },
          { x: 180, color: "#d4a843", label: "⏸" },
          { x: 220, color: "#3a6fb5", label: "⏹" },
          { x: 260, color: "#8b7355", label: "⏪" },
          { x: 300, color: "#8b7355", label: "⏩" },
        ].map(btn => (
          <>
            <circle cx={btn.x} cy="290" r="10" fill={btn.color} />
            <text x={btn.x} y="294" font-family="Departure Mono, monospace" font-size="8" fill="white" text-anchor="middle">{btn.label}</text>
          </>
        ))}
      </g>

      {/* Counter display */}
      <rect x="340" y="275" width="80" height="25" rx="2" fill="#1c1815" />
      <text x="380" y="292" font-family="Departure Mono, monospace" font-size="10" fill="#5d9e4a" text-anchor="middle">03:42</text>

      {/* Rainbow stripe */}
      {["#d4302b", "#e67a30", "#d4a843", "#e8d44a", "#5d9e4a", "#3a9e8f", "#3a6fb5", "#3a3f8f"].map((color, i) => (
        <rect x={200 + i * 7} y="310" width="5" height="30" fill={color} />
      ))}

      <text x="50" y="340" font-family="Departure Mono, monospace" font-size="7" fill="#9c8e7e" letter-spacing="0.15em">DIAGRAM NO. 3 · SCROBBLE HISTORY RECORDING APPARATUS</text>
    </svg>
  );
}

// ═══════════ SPEAKER STACK — stats illustration ═══════════
export function SpeakerStack() {
  return (
    <svg viewBox="0 0 300 400" fill="none" xmlns="http://www.w3.org/2000/svg" class="condec-svg">
      {/* Cabinet */}
      <rect x="40" y="20" width="220" height="360" rx="8" fill="#3d3530" />
      <rect x="44" y="24" width="212" height="352" rx="6" fill="none" stroke="#6b5e52" stroke-width="0.5" />

      {/* Top tweeter */}
      <circle cx="150" cy="80" r="25" fill="#1c1815" stroke="#8b7355" stroke-width="1" />
      <circle cx="150" cy="80" r="18" fill="#3d3530" />
      <circle cx="150" cy="80" r="8" fill="#d4a843" />

      {/* Mid driver */}
      <circle cx="150" cy="170" r="45" fill="#1c1815" stroke="#8b7355" stroke-width="1" />
      <circle cx="150" cy="170" r="38" fill="#3d3530" />
      <circle cx="150" cy="170" r="20" fill="#6b5e52" />
      <circle cx="150" cy="170" r="10" fill="#d4302b" />

      {/* Woofer */}
      <circle cx="150" cy="290" r="60" fill="#1c1815" stroke="#8b7355" stroke-width="1" />
      <circle cx="150" cy="290" r="52" fill="#3d3530" />
      {/* Cone ridges */}
      {[45, 38, 30, 22].map(r => (
        <circle cx="150" cy="290" r={r} fill="none" stroke="#6b5e52" stroke-width="0.3" />
      ))}
      <circle cx="150" cy="290" r="14" fill="#6b5e52" />
      <circle cx="150" cy="290" r="6" fill="#3a6fb5" />

      {/* Sound waves emanating */}
      {[80, 100, 120].map((r, i) => (
        <path d={`M${260 + i * 15} 170 Q${280 + i * 20} 170 ${260 + i * 15} 130`}
          fill="none" stroke="#d4a843" stroke-width="1" opacity={0.5 - i * 0.15} />
      ))}

      {/* Nameplate */}
      <rect x="100" y="365" width="100" height="12" rx="1" fill="#d4a843" />
      <text x="150" y="374" font-family="Departure Mono, monospace" font-size="5" fill="#1c1815" text-anchor="middle" letter-spacing="0.1em">SCROBBLE NOW</text>
    </svg>
  );
}
