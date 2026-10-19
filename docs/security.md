# Security rules

OmniLife stores everything a person creates under their own folder, and the
rules make sure nobody else can open it. This page explains what the rules
allow, how to check them, and how to change them safely.

The rules files are `firestore.rules` and `storage.rules` at the repository
root. They are not deployed by anything in this repository. Deploying is a
manual step for whoever owns the Firebase project (see
`docs/firebase-setup.md`).

## The model

- Every document lives under `users/{uid}/...`.
- A request is allowed only when the caller is signed in and
  `request.auth.uid` equals the `{uid}` in the path.
- Every path that is not listed below is denied, for reads and writes.

## Firestore collections

All of these are subcollections of `users/{uid}`.

| Collection | Used by | Extra checks on create/update |
|---|---|---|
| `tasks` | Tasks | owner fields, shape |
| `projects` | reserved | owner fields, shape |
| `events` | Calendar | owner fields, shape |
| `notes` | Notes | owner fields, shape |
| `habits`, `habit_logs` | Habits | owner fields, shape |
| `goals` | Goals | owner fields, shape |
| `expenses` | Finance transactions | owner fields, shape |
| `settings` | Finance budgets | owner fields, shape |
| `wellness` | Wellness daily logs | owner fields, shape |
| `focus_sessions` | Focus | owner fields, shape |
| `locations` | Saved places | owner fields, shape |
| `sensor_daily` | Step totals | owner fields, shape |
| `reminders` | Reminders | owner fields, shape |
| `devices` | Push tokens | owner fields, shape |
| `conversations` and `conversations/{id}/messages` | Assistant | owner fields, shape |
| `life_events` | OmniPulse moments | `type` is a string, `timestamp` and `updatedAt` are whole numbers, `deleted` (if present) is true or false |

The user document `users/{uid}` itself can be read and written by its owner.

### What "owner fields" and "shape" mean

- Shape: the written data must be a map with at most 60 fields.
- Owner fields: if the document has a `userId` or `uid` field, it must equal
  the caller's uid. A client cannot save a document that claims to belong to
  someone else. Documents without those fields (for example saved places,
  which keep their owner in the path) are fine.
- Documents with a `title` must have it as text (or empty).

Deleting is allowed for the owner in every listed collection. Life events
are normally removed by writing a tombstone (`deleted: true`), which the sync
engine resolves by `updatedAt`; a hard delete by the owner is also allowed.

## Cloud Storage

Receipt photos are stored at `receipts/{uid}/{fileName}`.

- Only the signed-in owner can read, upload or delete.
- Uploads must be an image or a PDF, smaller than 10 MB.
- Everything else in the bucket is denied.

The app sets the file's content type when it uploads a receipt, which the
rule above relies on.

## Checking the rules

The Firebase emulator is the real test. From a machine with the Firebase CLI
and a linked project (do not run `firebase init` or deploy from this
repository's automation):

```bash
firebase emulators:start --only firestore,storage
```

Then try, as two different signed-in users A and B:

1. A creates `users/A/tasks/t1` with `{userId: 'A', title: 'x'}`. Allowed.
2. A creates `users/A/tasks/t2` with `{userId: 'B'}`. Denied.
3. B reads `users/A/tasks/t1`. Denied.
4. A signed-out client reads anything. Denied.
5. A writes `users/A/unknown_collection/x`. Denied.
6. A writes a life event with `timestamp: 'noon'`. Denied.
7. A uploads a 20 MB file to `receipts/A/big.jpg`. Denied. B reading
   `receipts/A/receipt.jpg` is denied.

`test/security/rules_files_test.dart` is a cheap guard that runs with the
normal test suite. It does not evaluate the rules; it checks that every
collection the app writes is named in `firestore.rules`, that the default
deny is still last, and that no rule grants access with `if true`.

## Changing the rules

1. Add the new collection to the lists in `firestore.rules` (read, write and
   delete).
2. Add a row to the table above.
3. Add the collection name to `test/security/rules_files_test.dart`.
4. Try it in the emulator before anyone deploys.
