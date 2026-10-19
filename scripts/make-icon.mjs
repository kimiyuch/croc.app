// Draws the Croc icon: a crocodile peeking over a film clapperboard with the kimiyu bear chalked on its board,
// on a billabong-green square. Writes the SVGs to artwork/ and renders the PNGs with headless Chrome
// (no npm packages needed), then copies the icon to Resources/ (build.sh) and docs/ (README).
// Usage: node scripts/make-icon.mjs
import { execFileSync } from "node:child_process";
import { copyFileSync as copy, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const root = new URL("../", import.meta.url).pathname;
const chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

// The kimiyu studio bear (copied from kimiyu.web), in light greys like chalk on the clapperboard.
const chalk = {
  "#9d6b45": "#5d6066", // ears, head
  "#e3bb92": "#6c6f75", // inside the ears
  "#ddb487": "#6a6d73", // snout
  "#292929": "#3a3c40", // eyes, nose, mouth
  "#fcfbfc": "#5d6066", // eye highlights blend into the head
};
const bearSource = readFileSync(root + "artwork/kimiyu-bear.svg", "utf8");
const bear = bearSource
  .replace(/^[\s\S]*?<svg[^>]*>|<\/svg>\s*$/g, "")
  .replace(/<!--.*?-->/g, "")
  .replace(/fill="(#[0-9a-f]{6})"/gi, (match, hex) => `fill="${chalk[hex.toLowerCase()] ?? "#606369"}"`);

const defs = `
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2c733b"/><stop offset=".55" stop-color="#1c3d25"/><stop offset="1" stop-color="#0c2113"/></linearGradient>
    <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".2"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <linearGradient id="skin" gradientUnits="userSpaceOnUse" x1="0" y1="150" x2="0" y2="520"><stop offset="0" stop-color="#74c77a"/><stop offset="1" stop-color="#2f8448"/></linearGradient>
    <linearGradient id="snout" gradientUnits="userSpaceOnUse" x1="0" y1="318" x2="0" y2="520"><stop offset="0" stop-color="#8fd88f"/><stop offset="1" stop-color="#55a865"/></linearGradient>
    <linearGradient id="board" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a3d42"/><stop offset="1" stop-color="#1f2124"/></linearGradient>
    <linearGradient id="stick" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#34373c"/><stop offset="1" stop-color="#1c1e21"/></linearGradient>
    <filter id="drop" x="-20%" y="-20%" width="140%" height="160%"><feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#04100a" flood-opacity=".4"/></filter>
    <filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#04100a" flood-opacity=".3"/></filter>
    <filter id="chalk" x="-10%" y="-10%" width="120%" height="120%"><feDropShadow dx="0" dy="-2" stdDeviation="1" flood-color="#000" flood-opacity=".5"/></filter>
    <filter id="icon" x="-10%" y="-10%" width="120%" height="125%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity=".3"/></filter>
    <clipPath id="squircle"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath>
    <clipPath id="stickClip"><rect x="280" y="524" width="464" height="62" rx="10"/></clipPath>`;

const background = `
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <rect width="1024" height="560" fill="url(#sheen)"/>`;

// Clapper stripes: white parallelograms across the stick.
const stripes = Array.from({ length: 7 }, (_, i) => {
  const x = 262 + i * 80;
  return `<path d="M${x} 586l40-62h40l-40 62z" fill="#f1f1ee"/>`;
}).join("");

// The croc behind the clapperboard, the board with the bear on it, then the paws on its top edge.
const art = `

  <g transform="translate(0 6)">
  <g class="croc" filter="url(#soft)">
    <circle cx="424" cy="214" r="66" fill="url(#skin)"/>
    <circle cx="600" cy="214" r="66" fill="url(#skin)"/>
    <ellipse cx="512" cy="290" rx="190" ry="98" fill="url(#skin)"/>
    <path d="M396 300C396 392 418 470 438 508Q512 540 586 508C606 470 628 392 628 300Z" fill="url(#skin)"/>
  </g>
  <g class="teeth" fill="#fbfbf6">
    <path d="M404 358l-28 10 30 14zM412 402l-28 11 31 13zM423 444l-27 13 31 11zM436 482l-25 14 30 8zM620 358l28 10-30 14zM612 402l28 11-31 13zM601 444l27 13-31 11zM588 482l25 14-30 8z"/>
  </g>
  <path d="M408 318C410 396 428 462 448 496Q512 522 576 496C596 462 614 396 616 318Q512 344 408 318Z" fill="url(#snout)"/>
  <ellipse cx="512" cy="494" rx="62" ry="30" fill="#a5e3a0"/>
  <g fill="#1f5a33"><ellipse cx="494" cy="490" rx="9" ry="7"/><ellipse cx="530" cy="490" rx="9" ry="7"/></g>
  <g fill="#2f8448" opacity=".55">
    <ellipse cx="512" cy="248" rx="13" ry="9"/><ellipse cx="482" cy="266" rx="11" ry="8"/><ellipse cx="542" cy="266" rx="11" ry="8"/>
    <ellipse cx="512" cy="384" rx="9" ry="7"/><ellipse cx="488" cy="420" rx="8" ry="6"/><ellipse cx="536" cy="420" rx="8" ry="6"/>
  </g>
  <g class="eyes">
    <g fill="#fff"><circle cx="424" cy="210" r="43"/><circle cx="600" cy="210" r="43"/></g>
    <g fill="#e9c443"><circle cx="429" cy="214" r="29"/><circle cx="595" cy="214" r="29"/></g>
    <g fill="#16180f"><ellipse cx="429" cy="215" rx="10" ry="23"/><ellipse cx="595" cy="215" rx="10" ry="23"/></g>
    <g fill="#fff"><circle cx="437" cy="201" r="7"/><circle cx="603" cy="201" r="7"/></g>
    <g fill="none" stroke="#2f8448" stroke-width="10" stroke-linecap="round"><path d="M380 180q44-28 88 0M556 180q44-28 88 0"/></g>
  </g>

  <g filter="url(#drop)">
    <rect x="296" y="594" width="432" height="290" rx="30" fill="url(#board)"/>
  </g>
  <path d="M326 598h372a26 26 0 0 1 26 26" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".18"/>
  <g fill="none" stroke="#f1f1ee" stroke-width="5" opacity=".35"><path d="M326 812h372M512 812v46"/></g>
  <g filter="url(#chalk)" transform="translate(512 706) scale(0.16) translate(-627 -632)">${bear}</g>

  <g transform="rotate(-5 296 586)">
    <rect x="280" y="524" width="464" height="62" rx="10" fill="url(#stick)"/>
    <g clip-path="url(#stickClip)">${stripes}</g>
    <rect x="280" y="524" width="464" height="62" rx="10" fill="none" stroke="#000" stroke-opacity=".25" stroke-width="3"/>
  </g>
  <circle cx="302" cy="586" r="11" fill="#9a9da3"/>

  <g fill="#4ea062" filter="url(#soft)">
    <ellipse cx="372" cy="548" rx="48" ry="29"/><ellipse cx="652" cy="526" rx="48" ry="29"/>
  </g>
  <g fill="none" stroke="#e3f3e0" stroke-width="6" stroke-linecap="round" opacity=".85">
    <path d="M355 558v13M372 560v13M389 558v13M635 536v13M652 538v13M669 536v13"/>
  </g>
  </g>`;

const svg = (viewBox, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}">\n  <defs>${defs}\n  </defs>${body}\n</svg>\n`;

// Rounded square on transparent with a shadow, on the macOS icon grid like the siblings': the app icon, favicon, README.
const rounded = svg("0 0 1024 1024", `
  <rect x="100" y="100" width="824" height="824" rx="185" fill="#1c3d25" filter="url(#icon)"/>
  <g clip-path="url(#squircle)"><g transform="translate(100 100) scale(0.8047)">${background}${art}</g></g>`);
// Full-bleed square for the apple-touch-icon (iOS rounds the corners itself).
const square = svg("0 0 1024 1024", background + art);
// The croc and its clapperboard without a background.
const mascot = svg("150 120 724 800", art);

mkdirSync(root + "artwork", { recursive: true });
writeFileSync(root + "artwork/icon.svg", rounded);
writeFileSync(root + "artwork/icon-square.svg", square);
writeFileSync(root + "artwork/mascot.svg", mascot);

const renders = [
  [rounded, "artwork/icon.png", 1024],
  [square, "artwork/icon-square.png", 1024],
  [mascot, "artwork/mascot.png", 800],
];
const work = mkdtempSync(join(tmpdir(), "croc-icon-"));
for (const [source, out, size] of renders) {
  const page = join(work, "page.html");
  writeFileSync(page, `<style>html,body{margin:0;background:transparent}svg{display:block;width:${size}px;height:${size}px}</style>${source}`);
  execFileSync(chrome, [
    "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
    `--window-size=${size},${size}`, "--default-background-color=00000000",
    `--user-data-dir=${join(work, "profile")}`, `--screenshot=${root + out}`, `file://${page}`,
  ], { stdio: "ignore" });
  console.log(out);
}

mkdirSync(root + "Resources", { recursive: true });
mkdirSync(root + "docs", { recursive: true });
copy(root + "artwork/icon.png", root + "Resources/icon.png");
copy(root + "artwork/icon.png", root + "docs/icon.png");
