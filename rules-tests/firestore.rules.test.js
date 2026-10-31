import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, query, where,
} from 'firebase/firestore';

let env;
const RULES = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ljc',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8081 },
  });
});
after(async () => env.cleanup());

const job = (over = {}) => ({
  title: 'Clean office', description: 'd', category: 'Cleaning', payRate: 100,
  posterId: 'poster1', status: 'open', ...over,
});
const application = (over = {}) => ({
  jobId: 'j1', jobTitle: 'Clean office', seekerId: 'seeker1', posterId: 'poster1',
  status: 'pending', note: 'hi', ...over,
});
const chatDoc = { jobId: 'j1', seekerId: 'seeker1', posterId: 'poster1', lastMessage: 'x' };

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'admins/admin1'), { role: 'admin' });
    await setDoc(doc(db, 'users/seeker1'), { displayName: 'S', role: 'seeker' });
    await setDoc(doc(db, 'jobs/j1'), job());
    await setDoc(doc(db, 'applications/a1'), application());
    await setDoc(doc(db, 'chats/c1'), chatDoc);
    await setDoc(doc(db, 'chats/c1/messages/m1'), { senderId: 'seeker1', text: 'hello', isRead: false });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

// ---- users ----
test('users: owner can read own profile, others cannot', async () => {
  await assertSucceeds(getDoc(doc(as('seeker1'), 'users/seeker1')));
  await assertFails(getDoc(doc(as('other'), 'users/seeker1')));
  await assertFails(getDoc(doc(anon(), 'users/seeker1')));
});
test('users: cannot self-promote to admin role', async () => {
  await assertFails(setDoc(doc(as('seeker1'), 'users/seeker1'), { displayName: 'S', role: 'admin' }));
  await assertSucceeds(setDoc(doc(as('seeker1'), 'users/seeker1'), { displayName: 'S', role: 'poster' }));
});
test('users: cannot write another user', async () => {
  await assertFails(setDoc(doc(as('other'), 'users/seeker1'), { displayName: 'X', role: 'seeker' }));
});
test('users: admin can read and change any profile', async () => {
  await assertSucceeds(getDoc(doc(as('admin1'), 'users/seeker1')));
  await assertSucceeds(updateDoc(doc(as('admin1'), 'users/seeker1'), { role: 'poster' }));
});
test('users: owner can edit name, phone and city', async () => {
  await assertSucceeds(updateDoc(doc(as('seeker1'), 'users/seeker1'), {
    displayName: 'New Name', phone: '0241234567', city: 'Kumasi',
  }));
  await assertFails(updateDoc(doc(as('seeker1'), 'users/seeker1'), { displayName: '' }));
});
test('users: owner cannot set their own rating or createdAt', async () => {
  await assertFails(updateDoc(doc(as('seeker1'), 'users/seeker1'), { rating: 5 }));
  await assertFails(updateDoc(doc(as('seeker1'), 'users/seeker1'), { createdAt: 'x' }));
  await assertFails(setDoc(doc(as('new1'), 'users/new1'), { displayName: 'N', role: 'seeker', rating: 4.9 }));
  await assertSucceeds(setDoc(doc(as('new2'), 'users/new2'), { displayName: 'N', role: 'seeker', rating: 5 }));
  await assertSucceeds(updateDoc(doc(as('admin1'), 'users/seeker1'), { rating: 4 }));
});
test('users: favorites are private to the owner', async () => {
  await assertSucceeds(setDoc(doc(as('seeker1'), 'users/seeker1/favorites/j1'), { jobId: 'j1' }));
  await assertFails(setDoc(doc(as('other'), 'users/seeker1/favorites/j1'), { jobId: 'j1' }));
});

// ---- jobs ----
test('jobs: anyone can read', async () => {
  await assertSucceeds(getDoc(doc(anon(), 'jobs/j1')));
});
test('jobs: create requires own posterId and valid data', async () => {
  await assertSucceeds(setDoc(doc(as('poster1'), 'jobs/j2'), job()));
  await assertFails(setDoc(doc(as('other'), 'jobs/j3'), job()));
  await assertFails(setDoc(doc(anon(), 'jobs/j4'), job()));
  await assertFails(setDoc(doc(as('poster1'), 'jobs/j5'), job({ payRate: -1 })));
  await assertFails(setDoc(doc(as('poster1'), 'jobs/j6'), job({ status: 'weird' })));
});
test('jobs: search keywords must be a bounded list', async () => {
  await assertSucceeds(setDoc(doc(as('poster1'), 'jobs/js1'), job({ searchTerms: ['clean', 'office'] })));
  await assertFails(setDoc(doc(as('poster1'), 'jobs/js2'), job({ searchTerms: 'clean' })));
  await assertFails(setDoc(doc(as('poster1'), 'jobs/js3'), job({
    searchTerms: Array.from({ length: 61 }, (_, i) => `t${i}`),
  })));
});
test('jobs: only owner updates; posterId immutable', async () => {
  await assertSucceeds(updateDoc(doc(as('poster1'), 'jobs/j1'), { isFilled: true }));
  await assertFails(updateDoc(doc(as('other'), 'jobs/j1'), { title: 'hijack' }));
  await assertFails(updateDoc(doc(as('poster1'), 'jobs/j1'), { posterId: 'other' }));
});
test('jobs: owner or admin can delete, others cannot', async () => {
  await assertFails(deleteDoc(doc(as('other'), 'jobs/j1')));
  await assertSucceeds(deleteDoc(doc(as('admin1'), 'jobs/j1')));
});

// ---- applications ----
test('applications: only seeker, poster and admin can read', async () => {
  await assertSucceeds(getDoc(doc(as('seeker1'), 'applications/a1')));
  await assertSucceeds(getDoc(doc(as('poster1'), 'applications/a1')));
  await assertSucceeds(getDoc(doc(as('admin1'), 'applications/a1')));
  await assertFails(getDoc(doc(as('other'), 'applications/a1')));
});
test('applications: list queries must be scoped to the caller', async () => {
  const col = collection(as('seeker1'), 'applications');
  await assertSucceeds(getDocs(query(col, where('seekerId', '==', 'seeker1'))));
  await assertFails(getDocs(col));
});
test('applications: seeker creates only pending, in own name', async () => {
  await assertSucceeds(setDoc(doc(as('seeker2'), 'applications/j1_seeker2'), application({ seekerId: 'seeker2' })));
  await assertFails(setDoc(doc(as('seeker2'), 'applications/j1_seeker1'), application({ seekerId: 'seeker1' })));
  await assertFails(setDoc(doc(as('seeker3'), 'applications/j1_seeker3'), application({ seekerId: 'seeker3', status: 'accepted' })));
});
test('applications: must match the real job and be one per seeker', async () => {
  await assertFails(setDoc(doc(as('seeker2'), 'applications/j1_seeker2'), application({ seekerId: 'seeker2', posterId: 'victim' })));
  await assertFails(setDoc(doc(as('seeker2'), 'applications/nojob_seeker2'), application({ seekerId: 'seeker2', jobId: 'nojob' })));
  await assertFails(setDoc(doc(as('seeker2'), 'applications/random'), application({ seekerId: 'seeker2' })));
  await assertSucceeds(setDoc(doc(as('seeker2'), 'applications/j1_seeker2'), application({ seekerId: 'seeker2' })));
  await assertFails(setDoc(doc(as('seeker2'), 'applications/j1_seeker2'), application({ seekerId: 'seeker2' })));
});
test('applications: phone is shared only on accepting; status moves forward', async () => {
  await assertFails(updateDoc(doc(as('poster1'), 'applications/a1'), { status: 'rejected', posterPhone: '024' }));
  await assertSucceeds(updateDoc(doc(as('poster1'), 'applications/a1'), { status: 'accepted', posterPhone: '024' }));
  await assertFails(updateDoc(doc(as('poster1'), 'applications/a1'), { status: 'pending' }));
  await assertSucceeds(updateDoc(doc(as('poster1'), 'applications/a1'), { status: 'completed' }));
  await assertFails(updateDoc(doc(as('poster1'), 'applications/a1'), { status: 'accepted' }));
});
test('jobs: the poster phone cannot be stored on a public job', async () => {
  await assertFails(setDoc(doc(as('poster1'), 'jobs/jp'), job({ posterPhone: '024' })));
});
test('applications: poster changes status only; seeker cannot', async () => {
  await assertSucceeds(updateDoc(doc(as('poster1'), 'applications/a1'), { status: 'accepted' }));
  await assertFails(updateDoc(doc(as('poster1'), 'applications/a1'), { note: 'edited' }));
  await assertFails(updateDoc(doc(as('seeker1'), 'applications/a1'), { status: 'accepted' }));
  await assertFails(updateDoc(doc(as('poster1'), 'applications/a1'), { status: 'bogus' }));
});

// ---- chats ----
test('chats: only members and admin can read', async () => {
  await assertSucceeds(getDoc(doc(as('seeker1'), 'chats/c1')));
  await assertSucceeds(getDoc(doc(as('poster1'), 'chats/c1')));
  await assertSucceeds(getDoc(doc(as('admin1'), 'chats/c1')));
  await assertFails(getDoc(doc(as('other'), 'chats/c1')));
});
test('chats: cannot create a chat you are not part of', async () => {
  await assertSucceeds(setDoc(doc(as('seeker2'), 'chats/c2'), { ...chatDoc, seekerId: 'seeker2' }));
  await assertFails(setDoc(doc(as('other'), 'chats/c3'), chatDoc));
  await assertFails(setDoc(doc(as('seeker2'), 'chats/c4'), { ...chatDoc, seekerId: 'seeker2', posterId: 'victim' }));
});
test('chats: members cannot swap participants', async () => {
  await assertSucceeds(updateDoc(doc(as('seeker1'), 'chats/c1'), { lastMessage: 'new' }));
  await assertFails(updateDoc(doc(as('seeker1'), 'chats/c1'), { posterId: 'other' }));
  await assertFails(updateDoc(doc(as('seeker1'), 'chats/c1'), { posterName: 'spoof' }));
});
test('messages: read and write limited to members; sender must match', async () => {
  await assertSucceeds(getDoc(doc(as('poster1'), 'chats/c1/messages/m1')));
  await assertFails(getDoc(doc(as('other'), 'chats/c1/messages/m1')));
  await assertSucceeds(setDoc(doc(as('poster1'), 'chats/c1/messages/m2'), { senderId: 'poster1', text: 'hi' }));
  await assertFails(setDoc(doc(as('poster1'), 'chats/c1/messages/m3'), { senderId: 'seeker1', text: 'spoof' }));
  await assertFails(setDoc(doc(as('other'), 'chats/c1/messages/m4'), { senderId: 'other', text: 'intrude' }));
});
test('messages: ids are limited to a safe character set', async () => {
  await assertSucceeds(setDoc(doc(as('seeker1'), 'chats/c1/messages/msg_123-a'), { senderId: 'seeker1', text: 'ok' }));
  await assertFails(setDoc(doc(as('seeker1'), 'chats/c1/messages/"><img src=x onerror=alert(1)>'), { senderId: 'seeker1', text: 'xss' }));
});
test('chats: either member can look a room up by job, seeker and poster', async () => {
  const q = (db) => query(collection(db, 'chats'), where('jobId', '==', 'j1'),
    where('seekerId', '==', 'seeker1'), where('posterId', '==', 'poster1'));
  await assertSucceeds(getDocs(q(as('poster1'))));
  await assertSucceeds(getDocs(q(as('seeker1'))));
  await assertFails(getDocs(q(as('other'))));
});
test('messages: members can only mark read; admin can delete', async () => {
  await assertSucceeds(updateDoc(doc(as('poster1'), 'chats/c1/messages/m1'), { isRead: true }));
  await assertFails(updateDoc(doc(as('seeker1'), 'chats/c1/messages/m1'), { text: 'edited' }));
  await assertFails(deleteDoc(doc(as('seeker1'), 'chats/c1/messages/m1')));
  await assertSucceeds(deleteDoc(doc(as('admin1'), 'chats/c1/messages/m1')));
});

// ---- reports ----
const report = (over = {}) => ({
  targetType: 'job', targetId: 'j1', targetTitle: 'Clean office', reporterId: 'seeker1',
  reason: 'Scam or upfront fee', note: '', status: 'open', ...over,
});
test('reports: signed-in user can file a report in their own name', async () => {
  await assertSucceeds(setDoc(doc(as('seeker1'), 'reports/r1'), report()));
  await assertFails(setDoc(doc(as('seeker1'), 'reports/r2'), report({ reporterId: 'other' })));
  await assertFails(setDoc(doc(anon(), 'reports/r3'), report()));
});
test('reports: must start open and use a known target type', async () => {
  await assertFails(setDoc(doc(as('seeker1'), 'reports/r4'), report({ status: 'resolved' })));
  await assertFails(setDoc(doc(as('seeker1'), 'reports/r5'), report({ targetType: 'planet' })));
  await assertFails(setDoc(doc(as('seeker1'), 'reports/r6'), report({ reason: '' })));
});
test('reports: reporter and admin can read, others cannot', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'reports/r7'), report()));
  await assertSucceeds(getDoc(doc(as('seeker1'), 'reports/r7')));
  await assertSucceeds(getDoc(doc(as('admin1'), 'reports/r7')));
  await assertFails(getDoc(doc(as('other'), 'reports/r7')));
});
test('reports: only admin changes status, and nothing else', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), 'reports/r8'), report()));
  await assertFails(updateDoc(doc(as('seeker1'), 'reports/r8'), { status: 'dismissed' }));
  await assertSucceeds(updateDoc(doc(as('admin1'), 'reports/r8'), { status: 'resolved' }));
  await assertFails(updateDoc(doc(as('admin1'), 'reports/r8'), { reason: 'edited' }));
});

// ---- admins and default deny ----
test('admins collection is readable by self only and unwritable', async () => {
  await assertSucceeds(getDoc(doc(as('admin1'), 'admins/admin1')));
  await assertFails(getDoc(doc(as('other'), 'admins/admin1')));
  await assertFails(setDoc(doc(as('other'), 'admins/other'), { role: 'admin' }));
});
test('unknown collections are denied', async () => {
  await assertFails(getDoc(doc(as('seeker1'), 'secrets/x')));
});
