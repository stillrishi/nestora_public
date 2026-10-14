import { cp, mkdir } from 'node:fs/promises';

await mkdir(new URL('../www/', import.meta.url), { recursive: true });
for (const file of ['index.html', 'cloud-config.js', 'nestora-cloud.js']) {
  await cp(new URL(`../${file}`, import.meta.url), new URL(`../www/${file}`, import.meta.url));
}
console.log('Prepared Nestora web assets in www/.');
