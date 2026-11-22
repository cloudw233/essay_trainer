import sharp from 'sharp';
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const res = join(root, 'android', 'app', 'src', 'main', 'res');
const icon = (name) => join(here, name);

const densities = [
  ['mdpi', 48, 108],
  ['hdpi', 72, 162],
  ['xhdpi', 96, 216],
  ['xxhdpi', 144, 324],
  ['xxxhdpi', 192, 432],
];

const png = (source, size, target) =>
  sharp(source, { density: 384 })
    .resize(size, size, { fit: 'contain', kernel: 'lanczos3' })
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(target);

for (const [bucket, legacySize, adaptiveSize] of densities) {
  const dir = join(res, `mipmap-${bucket}`);
  await mkdir(dir, { recursive: true });

  await Promise.all([
    png(icon('icon.svg'), legacySize, join(dir, 'ic_launcher.png')),
    png(icon('icon-foreground.svg'), adaptiveSize, join(dir, 'ic_launcher_foreground.png')),
    png(
      icon('icon-monochrome-foreground.svg'),
      adaptiveSize,
      join(dir, 'ic_launcher_monochrome.png'),
    ),
  ]);
}

await mkdir(join(res, 'values'), { recursive: true });
await writeFile(
  join(res, 'values', 'ic_launcher_background.xml'),
  `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#F6F1E7</color>
</resources>
`,
);

await mkdir(join(res, 'mipmap-anydpi-v26'), { recursive: true });
await writeFile(
  join(res, 'mipmap-anydpi-v26', 'ic_launcher.xml'),
  `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
`,
);

// The monochrome layer is only read by Android 13+, so keep it out of the
// v26 file that API 26–32 parsers also see.
await mkdir(join(res, 'mipmap-anydpi-v33'), { recursive: true });
await writeFile(
  join(res, 'mipmap-anydpi-v33', 'ic_launcher.xml'),
  `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
`,
);

console.log(`Installed launcher icons into ${res}`);
