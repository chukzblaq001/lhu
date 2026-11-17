# Learn Hub 2.0 — Online School + Learning Platform

This upgraded starter combines a student learning portal with early school-management workspaces. It uses separate HTML, CSS and JavaScript files, a PWA shell, optional Supabase authentication/database integration, and local demo storage.

## Included in this upgrade
- Student learning dashboard, subject selection, sample lessons, practice quiz, results and progress.
- Teacher workspace foundations: class list, student directory, learning materials area, assignment publishing and announcements.
- Administrator foundations: user directory, curriculum/question-bank/report areas, attendance register, fee-record ledger, announcements and timetable.
- Student-facing assignment, announcement and timetable views.
- Light/dark theme toggle, responsive layouts and installable PWA shell.
- Expanded Supabase SQL schema for classes, memberships, announcements, assignments/submissions, attendance, timetable, fees and report cards.

## Run locally
1. Extract the ZIP.
2. Open the folder in VS Code.
3. Start the VS Code Live Server extension (or another local static server).
4. Open its localhost URL. PWA installation and service workers require localhost or HTTPS.

## Demo mode limitations
If Supabase is not configured, authentication and school records use browser localStorage. This mode is only for preview:
- Data exists only in that browser and does not sync between devices.
- Demo passwords are not securely hashed; do not use real passwords.
- Demo classes, attendance, fee entries, assignments and announcements are not official school records.
- File submission is a UI demonstration; files are not uploaded.
- Payment records do not collect or verify money.
- Demo mode does not provide a secure way to create teacher/admin accounts.

## Connect Supabase
1. Create a Supabase project.
2. Run the complete `supabase-schema.sql` in the Supabase SQL Editor.
3. Put the Project URL and anon/publishable key in `CONFIG` at the top of `app.js`.
4. Add your deployed site URL to Supabase Auth URL configuration.
5. Test sign-up, sign-in, profile creation, RLS and every role using separate test accounts.
6. Provision the first administrator through a trusted server-side process. Never allow public signup to choose `teacher` or `admin` roles.

**Never put a Supabase `service_role` key in `app.js` or any browser file.**

## Important production work still required
This is an upgraded development starter, not a production-ready school information system. The new school-management screens currently use local demo storage; they are not yet wired to the new Supabase tables. Before real school use, implement and test:
- Cloud CRUD for all school modules and class-scoped teacher access.
- Secure server-side admin provisioning, role changes, staff creation and approval workflows.
- Supabase Storage uploads with private buckets and signed access for assignment files and learning materials.
- Payment provider checkout and server-side webhook verification; never mark a fee paid from a browser form alone.
- Live video classes via a suitable video provider; this starter does not stream live video.
- Report-card calculations, grading policies, promotion approvals, audit logs and backups.
- Full lesson/question content with source/licensing review and alignment against the current NERDC and external-exam syllabuses.
- Privacy policy, child safeguarding controls, consent, accessibility, security and load testing.

## Suggested next development milestones
1. Wire profiles, classes, memberships and role-aware navigation to Supabase.
2. Build teacher content upload and assignment submission with secure Storage.
3. Build CBT authoring, timed exams, autosave, marking and result reports.
4. Add live classes, messaging/notifications, verified fee payments and downloadable report cards.
5. Package Android using a maintained Capacitor workflow and test on real devices.
