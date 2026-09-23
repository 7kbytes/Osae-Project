/**
 * Seeds clearly fictional demo data for a walkthrough of the app, and wipes it
 * again. Every document it writes carries `demo: true`, and `--wipe` deletes
 * exactly those documents, so real accounts and real jobs are never touched.
 *
 * The posters and seekers are invented people with invented phone numbers.
 * This is product demo material, not market activity: do not present it as
 * real usage.
 *
 * Usage (never commit the key; see docs/03 section 2):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/outside/repo/service-account.json \
 *   node scripts/seed-demo-data.mjs [--wipe]
 */
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const MIN_TERM = 3;
const MAX_TERM_LENGTH = 12;
const MAX_TERMS = 60;

/** Mirrors JobPost.buildSearchTerms in lib/core/models/job_model.dart. */
function buildSearchTerms(sources) {
  const terms = new Set();
  for (const source of sources) {
    for (const word of String(source ?? '').toLowerCase().split(/[^a-z0-9]+/)) {
      if (!word) continue;
      if (word.length < MIN_TERM) {
        terms.add(word);
        continue;
      }
      const longest = Math.min(word.length, MAX_TERM_LENGTH);
      for (let end = MIN_TERM; end <= longest; end++) {
        terms.add(word.slice(0, end));
      }
    }
  }
  return [...terms].slice(0, MAX_TERMS);
}

const CITY = {
  Accra: { lat: 5.56, lng: -0.2057 },
  Kumasi: { lat: 6.6885, lng: -1.6244 },
  Tema: { lat: 5.6698, lng: -0.0166 },
};

const POSTERS = [
  { id: 'demo_poster_ama', displayName: 'Ama Boateng (demo)', phone: '+233 24 000 0101', city: 'Accra' },
  { id: 'demo_poster_kwesi', displayName: 'Kwesi Owusu (demo)', phone: '+233 24 000 0102', city: 'Kumasi' },
  { id: 'demo_poster_naa', displayName: 'Naa Adjeley (demo)', phone: '+233 24 000 0103', city: 'Tema' },
];

const SEEKERS = [
  { id: 'demo_seeker_yaw', displayName: 'Yaw Mensah (demo)', phone: '+233 24 000 0201', city: 'Accra' },
  { id: 'demo_seeker_efua', displayName: 'Efua Danso (demo)', phone: '+233 24 000 0202', city: 'Accra' },
  { id: 'demo_seeker_kojo', displayName: 'Kojo Antwi (demo)', phone: '+233 24 000 0203', city: 'Kumasi' },
];

// title, category, city, locationName, payRate, payUnit
const JOBS = [
  ['Office cleaner needed, Circle', 'Cleaning', 'Accra', 'Circle', 90, 'per day'],
  ['Shop assistant at Kaneshie Market', 'Retail', 'Accra', 'Kaneshie', 80, 'per day'],
  ['Mason for two-week block work', 'Construction & Labor', 'Accra', 'Madina', 150, 'per day'],
  ['Waiter for weekend events', 'Hospitality', 'Accra', 'Osu', 100, 'per day'],
  ['Delivery rider, own motorbike', 'Transport', 'Accra', 'Spintex', 130, 'per day'],
  ['House cleaning, twice weekly', 'Cleaning', 'Accra', 'East Legon', 110, 'per day'],
  ['Carpenter for shop fitting', 'Construction & Labor', 'Accra', 'Achimota', 170, 'per day'],
  ['Kitchen assistant, chop bar', 'Hospitality', 'Accra', 'Adabraka', 85, 'per day'],
  ['Security guard, night shift', 'Retail', 'Accra', 'Dansoman', 95, 'per day'],
  ['Taxi driver, daily rental', 'Transport', 'Accra', 'Lapaz', 120, 'per day'],
  ['Painter for three-bedroom house', 'Construction & Labor', 'Accra', 'Teshie', 160, 'per day'],
  ['Cleaner for a small clinic', 'Cleaning', 'Accra', 'Abeka', 95, 'per day'],
  ['Market stall attendant, Kejetia', 'Retail', 'Kumasi', 'Kejetia Market', 75, 'per day'],
  ['Labourer for building site', 'Construction & Labor', 'Kumasi', 'Asafo', 140, 'per day'],
  ['Hotel room attendant', 'Hospitality', 'Kumasi', 'Adum', 100, 'per day'],
  ['Trotro mate needed', 'Transport', 'Kumasi', 'Suame', 70, 'per day'],
  ['Cleaner for guest house', 'Cleaning', 'Kumasi', 'Bantama', 90, 'per day'],
  ['Welder for gate fabrication', 'Construction & Labor', 'Kumasi', 'Suame Magazine', 180, 'per day'],
  ['Cook for staff canteen', 'Hospitality', 'Kumasi', 'Ayeduase', 120, 'per day'],
  ['Shop sales attendant, phones', 'Retail', 'Kumasi', 'Adum', 85, 'per day'],
  ['Dock loader, Tema Port', 'Construction & Labor', 'Tema', 'Tema Port', 155, 'per day'],
  ['Warehouse packer', 'Retail', 'Tema', 'Community 1', 100, 'per day'],
  ['Truck driver, short haul', 'Transport', 'Tema', 'Tema Industrial Area', 200, 'per day'],
  ['Cleaner for office block', 'Cleaning', 'Tema', 'Community 5', 95, 'per day'],
  ['Restaurant server, evenings', 'Hospitality', 'Tema', 'Community 11', 90, 'per day'],
  ['Fitter mate for workshop', 'Construction & Labor', 'Tema', 'Community 2', 130, 'per day'],
];

const DESCRIPTION = (title, location) =>
  `${title}. Work is based around ${location}. Start as soon as possible, ` +
  `payment at the end of each week. Bring your own basic tools where needed. ` +
  `This is demonstration data for a product walkthrough.`;

async function deleteInBatches(db, docs) {
  let batch = db.batch();
  let pending = 0;
  let deleted = 0;
  for (const doc of docs) {
    batch.delete(doc.ref);
    deleted++;
    if (++pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return deleted;
}

async function wipe(db) {
  let total = 0;
  for (const name of ['jobs', 'applications', 'reports', 'users']) {
    const snap = await db.collection(name).where('demo', '==', true).get();
    total += await deleteInBatches(db, snap.docs);
  }
  const chats = await db.collection('chats').where('demo', '==', true).get();
  for (const chat of chats.docs) {
    const messages = await chat.ref.collection('messages').get();
    total += await deleteInBatches(db, messages.docs);
  }
  total += await deleteInBatches(db, chats.docs);
  return total;
}

async function seed(db) {
  const now = Date.now();
  const iso = (minutesAgo) => new Date(now - minutesAgo * 60000).toISOString();
  const batch = db.batch();
  let writes = 0;

  for (const person of [...POSTERS, ...SEEKERS]) {
    const role = POSTERS.includes(person) ? 'poster' : 'seeker';
    batch.set(db.collection('users').doc(person.id), {
      id: person.id,
      displayName: person.displayName,
      phone: person.phone,
      role,
      city: person.city,
      rating: 5,
      createdAt: iso(60 * 24 * 30),
      demo: true,
    });
    writes++;
  }

  const jobIds = [];
  JOBS.forEach((row, i) => {
    const [title, category, city, locationName, payRate, payUnit] = row;
    const poster = POSTERS.find((p) => p.city === city) ?? POSTERS[0];
    const id = `demo_job_${String(i + 1).padStart(2, '0')}`;
    jobIds.push({ id, title, poster, city });
    const jitter = (n) => n + (Math.random() - 0.5) * 0.05;
    batch.set(db.collection('jobs').doc(id), {
      id,
      title,
      description: DESCRIPTION(title, locationName),
      category,
      payRate,
      payUnit,
      currency: 'GHS',
      city,
      locationName,
      latitude: jitter(CITY[city].lat),
      longitude: jitter(CITY[city].lng),
      posterId: poster.id,
      posterName: poster.displayName,
      posterPhone: poster.phone,
      status: 'open',
      isFilled: false,
      createdAt: iso((i + 1) * 90),
      searchTerms: buildSearchTerms([title, locationName, category, city]),
      demo: true,
    });
    writes++;
  });

  // A few applications so the poster's review screen is not empty.
  const applications = [
    { job: jobIds[0], seeker: SEEKERS[0], status: 'pending', note: 'I have two years of office cleaning experience and can start on Monday.' },
    { job: jobIds[0], seeker: SEEKERS[1], status: 'accepted', note: 'I live close to Circle and can work early mornings.' },
    { job: jobIds[2], seeker: SEEKERS[0], status: 'pending', note: 'I have worked on block and plaster jobs around Madina.' },
    { job: jobIds[12], seeker: SEEKERS[2], status: 'rejected', note: 'Available every market day.' },
    { job: jobIds[20], seeker: SEEKERS[2], status: 'pending', note: 'I have port loading experience and my own boots.' },
  ];
  applications.forEach((a, i) => {
    const id = `demo_app_${String(i + 1).padStart(2, '0')}`;
    batch.set(db.collection('applications').doc(id), {
      id,
      jobId: a.job.id,
      jobTitle: a.job.title,
      seekerId: a.seeker.id,
      seekerName: a.seeker.displayName,
      seekerPhone: a.seeker.phone,
      posterId: a.job.poster.id,
      status: a.status,
      note: a.note,
      appliedAt: iso(30 + i * 20),
      demo: true,
    });
    writes++;
  });

  await batch.commit();

  // Chats, with their messages in a subcollection.
  const threads = [
    {
      job: jobIds[0],
      seeker: SEEKERS[1],
      messages: [
        ['seeker', 'Good morning. Is the cleaning job at Circle still open?'],
        ['poster', 'Yes it is. Can you start on Monday at 6am?'],
        ['seeker', 'Yes I can. How many days a week is it?'],
        ['poster', 'Five days, Monday to Friday. Payment every Friday.'],
      ],
    },
    {
      job: jobIds[20],
      seeker: SEEKERS[2],
      messages: [
        ['seeker', 'Please, I am interested in the loading work at the port.'],
        ['poster', 'Do you have your own safety boots?'],
        ['seeker', 'Yes, boots and gloves.'],
      ],
    },
  ];

  for (const thread of threads) {
    const chatId = `chat_${thread.job.id}_${thread.seeker.id}`;
    const last = thread.messages[thread.messages.length - 1];
    await db.collection('chats').doc(chatId).set({
      id: chatId,
      jobId: thread.job.id,
      jobTitle: thread.job.title,
      seekerId: thread.seeker.id,
      seekerName: thread.seeker.displayName,
      posterId: thread.job.poster.id,
      posterName: thread.job.poster.displayName,
      lastMessage: last[1],
      updatedAt: iso(10),
      demo: true,
    });
    writes++;
    const messageBatch = db.batch();
    thread.messages.forEach(([who, text], i) => {
      const sender = who === 'seeker' ? thread.seeker : thread.job.poster;
      messageBatch.set(
        db.collection('chats').doc(chatId).collection('messages').doc(`demo_msg_${i + 1}`),
        {
          id: `demo_msg_${i + 1}`,
          senderId: sender.id,
          senderName: sender.displayName,
          text,
          timestamp: iso(60 - i * 10),
          isRead: true,
        },
      );
      writes++;
    });
    await messageBatch.commit();
  }

  console.log(
    `Seeded ${writes} demo documents: ${JOBS.length} jobs, ${applications.length} applications, ${threads.length} chats, ${POSTERS.length + SEEKERS.length} demo profiles.`,
  );
  console.log('All carry demo:true. Remove them with: node scripts/seed-demo-data.mjs --wipe');
}

async function main() {
  initializeApp({ credential: applicationDefault() });
  const db = getFirestore();
  if (process.argv.includes('--wipe')) {
    const removed = await wipe(db);
    console.log(`Wiped ${removed} demo documents.`);
    return;
  }
  // Re-running replaces the previous demo set rather than duplicating it.
  const removed = await wipe(db);
  if (removed > 0) console.log(`Removed ${removed} documents from a previous seed.`);
  await seed(db);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
