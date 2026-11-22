import sharp from 'sharp';
import { mkdir } from 'node:fs/promises';

const out = 'assets/icon/png';
await mkdir(out, { recursive: true });

const jobs = [
  ['assets/icon/icon.svg', 'icon', [1024, 512, 384, 192, 144, 96, 72, 64, 48]],
  ['assets/icon/icon-dark.svg', 'icon-dark', [512, 192, 96, 48]],
  ['assets/icon/icon-compact.svg', 'icon-compact', [32, 24]],
  ['assets/icon/icon-16.svg', 'icon', [16]],
  ['assets/icon/icon-monochrome.svg', 'icon-mono', [512, 192, 96, 48]],
  ['assets/icon/icon-glyph.svg', 'icon-glyph', [432, 192]],
  ['assets/icon/icon-foreground.svg', 'icon-foreground', [432]],
  ['assets/icon/icon-monochrome-foreground.svg', 'icon-monochrome-foreground', [432]],
];

for (const [src, name, sizes] of jobs) {
  for (const size of sizes) {
    await sharp(src, { density: 384 })
      .resize(size, size, { fit: 'contain', kernel: 'lanczos3' })
      .png({ compressionLevel: 9, adaptiveFiltering: true })
      .toFile(`${out}/${name}-${size}.png`);
  }
}

console.log('rendered', jobs.reduce((n, job) => n + job[2].length, 0), 'png files');
