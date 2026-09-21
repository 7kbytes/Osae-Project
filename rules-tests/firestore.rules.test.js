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
  await assertSucceeds(setDoc(doc(as('seeker2'), 'applications/a2'), application({ seekerId: 'seeker2' })));
  await assertFails(setDoc(doc(as('seeker2'), 'applications/a3'), application({ seekerId: 'seeker1' })));
  await assertFails(setDoc(doc(as('seeker2'), 'applications/a4'), application({ seekerId: 'seeker2', status: 'accepted' })));
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
});
test('chats: members cannot swap participants', async () => {
  await assertSucceeds(updateDoc(doc(as('seeker1'), 'chats/c1'), { lastMessage: 'new' }));
  await assertFails(updateDoc(doc(as('seeker1'), 'chats/c1'), { posterId: 'other' }));
});
test('messages: read and write limited to members; sender must match', async () => {
  await assertSucceeds(getDoc(doc(as('poster1'), 'chats/c1/messages/m1')));
  await assertFails(getDoc(doc(as('other'), 'chats/c1/messages/m1')));
  await assertSucceeds(setDoc(doc(as('poster1'), 'chats/c1/messages/m2'), { senderId: 'poster1', text: 'hi' }));
  await assertFails(setDoc(doc(as('poster1'), 'chats/c1/messages/m3'), { senderId: 'seeker1', text: 'spoof' }));
  await assertFails(setDoc(doc(as('other'), 'chats/c1/messages/m4'), { senderId: 'other', text: 'intrude' }));
});
test('messages: members can only mark read; admin can delete', async () => {
  await assertSucceeds(updateDoc(doc(as('poster1'), 'chats/c1/messages/m1'), { isRead: true }));
  await assertFails(updateDoc(doc(as('seeker1'), 'chats/c1/messages/m1'), { text: 'edited' }));
  await assertFails(deleteDoc(doc(as('seeker1'), 'chats/c1/messages/m1')));
  await assertSucceeds(deleteDoc(doc(as('admin1'), 'chats/c1/messages/m1')));
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
