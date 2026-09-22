/**
 * Backfills `searchTerms` on existing job documents.
 *
 * Jobs written before search shipped have no keywords, so the feed's search
 * (an `array-contains` query) cannot find them. Run this once per environment
 * after deploying the search change. It is safe to re-run: documents whose
 * keywords already match are skipped.
 *
 * Usage (never commit the key; see docs/03 section 2):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/outside/repo/service-account.json \
 *   node scripts/backfill-search-terms.mjs [--dry-run]
 */
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const MIN_TERM = 3;
const MAX_TERM_LENGTH = 12;
const MAX_TERMS = 60;

/** Mirrors JobPost.buildSearchTerms in lib/core/models/job_model.dart. */
export function buildSearchTerms(sources) {
  const terms = new Set();
  for (const source of sources) {
    for (const word of String(source ?? '').toLowerCase().split(/[^a-z0-9]+/)) {
      if (!word) continue;
      if (word.length < MIN_TERM) {
        terms.add(word);
        continue;
      }
      const longest = Math.min(word.length, MAX_TERM_LENGTH);
      for (let end = MIN_TERM; end <= longest; end++) terms.add(word.slice(0, end));
    }
  }
  return [...terms].slice(0, MAX_TERMS);
}

const same = (a = [], b = []) =>
  a.length === b.length && a.every((v, i) => v === b[i]);

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  initializeApp({ credential: applicationDefault() });
  const db = getFirestore();

  const snapshot = await db.collection('jobs').get();
  let updated = 0;
  let batch = db.batch();
  let pending = 0;

  for (const doc of snapshot.docs) {
    const d = doc.data();
    const terms = buildSearchTerms([d.title, d.locationName, d.category, d.city]);
    if (same(d.searchTerms, terms)) continue;
    updated++;
    if (dryRun) continue;
    batch.update(doc.ref, { searchTerms: terms });
    if (++pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (!dryRun && pending > 0) await batch.commit();

  console.log(
    `${snapshot.size} jobs read, ${updated} ${dryRun ? 'would be updated' : 'updated'}.`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
