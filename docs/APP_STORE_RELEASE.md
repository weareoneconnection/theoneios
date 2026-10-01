# App Store release gate

An archive is not a release. Submit only when every gate below has evidence for
the exact commit being uploaded.

## Product

- [ ] Native app icon, launch presentation and localized App Store screenshots.
- [x] Sign in with Apple code path links the verified Apple subject to the same
      TheOne identity and tenant as email and GitHub sign-in.
- [ ] Enable Sign in with Apple for `ai.oneailabs.theone` in Apple Developer,
      configure `THEONE_APPLE_CLIENT_ID`, and capture a signed-device E2E run.
- [ ] Native push notifications for approvals and completed work.
- [ ] Native camera, photo and file entry points.
- [x] Origin-checked native share sheet, haptics and full WebKit sign-out bridge.
- [x] Account deletion can be initiated inside the app, revokes access
      immediately, and creates a durable seven-day deletion request.
- [ ] Exercise the production purge worker and Apple-token revocation with a
      disposable TestFlight account; retain the deletion receipt as evidence.
- [ ] Billing is either StoreKit-based or absent from the iOS app. No hidden
      external checkout or upgrade link.

## Security and isolation

- [ ] Two-person account-isolation matrix passes for chats, code workspaces,
      memories, goals, automations, attachments and usage.
- [ ] Sign-out clears WebKit cookies, caches and native secrets.
- [ ] The app never downloads or executes code, a shell or an agent runtime.
- [ ] Universal links use a deployed `apple-app-site-association` file.
- [ ] ATS remains strict; production traffic uses HTTPS only.
- [ ] Privacy manifest and App Store privacy answers match observed collection.

## Reliability and review

- [ ] Fresh install, upgrade, expired-session and revoked-member journeys pass.
- [ ] Offline compose/retry, attachment recovery and task notification pass on
      a real iPhone under weak-network conditions.
- [ ] VoiceOver, Dynamic Type, Reduce Motion and landscape/iPad pass.
- [ ] Reviewer demo account has representative data but no production secrets.
- [ ] Backend and independent verifier remain available throughout review.
- [ ] TestFlight internal, external and production-candidate builds use the same
      API origin and release configuration.

## Distribution

Use the OneAI Labs organization account so the company is the seller. Set the
Xcode Development Team, create the App Store Connect record, upload an Archive,
complete export-compliance/privacy/age-rating metadata, and distribute to
TestFlight before requesting App Review.
