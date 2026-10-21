# Contributing

The team of three works on one repository. To keep each person's work visible
in the history, everyone commits under their own GitHub account and no one
commits straight to `main`.

## Workflow

1. Update main.

   ```bash
   git checkout main
   git pull
   ```

2. Create a branch named after your work: `feature/<name>`, for example
   `feature/finance-pdf`, or `fix/<name>` for bug fixes.

   ```bash
   git checkout -b feature/finance-pdf
   ```

3. Make small commits with short messages that say what changed.

   ```bash
   git add <files>
   git commit -m "finance report now includes budgets"
   ```

4. Run the tests before you push.

   ```bash
   flutter test
   ```

5. Push the branch and open a pull request into `main`.

   ```bash
   git push -u origin feature/finance-pdf
   ```

   Describe what changed and how you checked it. Another member reviews and
   merges it.

## Rules

- Set your own identity: `git config user.name` and `user.email` must be your own account, so commits are attributed to you.
- Never commit secrets: `.env`, `android/key.properties`, keystores, `google-services.json`, service account files. They are in `.gitignore`; do not force-add them.
- Do not commit build output (`build/`, `.dart_tool/`).
- Keep the layer rules: UI in `presentation`, rules and logic in `domain`, storage and network in `data`.
- Add or update a test for behaviour you change, and add a row to `docs/TESTING.md` for new user-facing features.
- Never deploy Firestore rules or release builds from a feature branch without agreeing with the team first.
