import puppeteer from "puppeteer";
import { fileURLToPath } from "url";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const W = 2064, H = 2752;
const slides = ["slide-1", "slide-2", "slide-3"];
const names  = ["01-accueil", "02-navigateur", "03-reglages"];

const browser = await puppeteer.launch({
  headless: "new",
  args: ["--no-sandbox", "--force-color-profile=srgb"],
});
const page = await browser.newPage();
await page.setViewport({ width: W, height: H, deviceScaleFactor: 1 });
await page.goto("file://" + path.join(__dirname, "index-ipad.html"), { waitUntil: "networkidle0" });

await page.evaluate(async () => {
  await document.fonts.ready;
  await Promise.all(
    [...document.images].map((img) =>
      img.complete ? Promise.resolve() : new Promise((r) => { img.onload = img.onerror = r; })
    )
  );
});
await new Promise((r) => setTimeout(r, 600));

for (let i = 0; i < slides.length; i++) {
  const el = await page.$("#" + slides[i]);
  const out = path.join(__dirname, "export-ipad", `${names[i]}-${W}x${H}.png`);
  await el.screenshot({ path: out, type: "png" });
  console.log("✓ " + out);
}

await browser.close();
console.log("done");
