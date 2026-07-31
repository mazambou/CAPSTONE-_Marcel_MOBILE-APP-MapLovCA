# MapLov legal review notes — 2026-07-30

The in-app Terms of Use, Privacy Policy, Cookie and Similar Technologies
Policy, and Face Verification Notice are original MapLov drafts. Tinder's
documents were used only to identify broad subject areas commonly addressed by
a dating service. US-specific Tinder provisions were not transplanted.

These drafts reflect the implementation reviewed on July 30, 2026:

- adults-only dating and social profiles;
- discovery filters, compatibility signals, likes, matches and friendships;
- private messages, posts, comments and Secret Garden access;
- foreground location and approximate-distance display;
- one private registration selfie per account;
- pairwise AWS Rekognition face detection and comparison;
- Supabase Auth, database, server functions and private storage;
- Namecheap transactional email;
- Apple App Store and Google Play subscription billing;
- account export, blocking, reporting and 30-day scheduled account deletion;
- no third-party behavioural advertising or optional analytics SDK in the
  current Flutter application.

## Required decisions before publication

1. Identify the contracting and data-controlling legal person. Insert its exact
   legal name, business or registered postal address, province, and any required
   registration number in the Terms, Privacy Policy, store listings and website.
2. Formally designate the MapLov privacy officer and publish the officer's title
   and contact details. Confirm that `privacy@maplov.ca`,
   `support@maplov.ca`, and `child-safety@maplov.ca` are monitored.
3. Obtain Canadian counsel's review of the Terms, including Ontario governing
   law, provincial consumer rights, subscription disclosure, limitation of
   liability and moderation appeals.
4. Complete and document a privacy impact assessment for the dating-profile,
   precise-location and facial-comparison systems before launch and whenever
   their purposes or providers materially change.
5. For people in Québec, obtain advice on and complete any required declaration
   of the biometric system or biometric-characteristics database before it is
   put into service. The Commission d'accès à l'information states that a
   non-biometric method must be available when biometric consent is refused.
   The current product requires the selfie to finish the normal profile setup,
   so this product flow needs a compliant alternative before Québec launch.
6. Verify the configured AWS Region, contractual terms and AWS Organizations
   AI-services opt-out policy. MapLov's code uses non-collection `DetectFaces`
   and `CompareFaces` calls, but AWS's broader service documentation states that
   input images may be stored or used to improve services unless the account
   opts out. The privacy notice must remain consistent with the actual account
   configuration.
7. For Québec information processed outside Québec, complete the required
   privacy-factor assessment and written processing agreements. Review the
   Supabase, AWS, Namecheap, Apple and Google data-processing terms and
   subprocessors.
8. Approve an operational retention schedule for database records, storage,
   authentication data, provider logs, backups, safety cases, legal holds,
   transaction evidence and biometric information. Test deletion against that
   schedule.
9. Maintain a current cookie and mobile-SDK inventory. Add a consent manager
   before enabling non-essential analytics, advertising, social pixels or
   comparable tracking.
10. Deploy `202607300040_maplov_legal_documents_v2.sql` before releasing an app
    build that records the new `2026-07-30` Terms and Privacy Policy versions.
    Do not backfill acceptance for existing users. Build an affirmative
    re-acceptance flow if counsel determines existing users must accept a
    material revision.

## Primary sources used for the Canadian adaptation

- Office of the Privacy Commissioner of Canada, PIPEDA fair information
  principles:
  <https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/p_principle/>
- Office of the Privacy Commissioner of Canada, meaningful consent:
  <https://www.priv.gc.ca/en/privacy-topics/business-privacy/collecting-personal-information/consent/gl_omc_201805/>
- Office of the Privacy Commissioner of Canada, biometrics guidance for
  businesses:
  <https://www.priv.gc.ca/en/privacy-topics/health-genetic-and-other-body-information/biometrics/gd_bio_org-final/>
- Office of the Privacy Commissioner of Canada, cross-border processing:
  <https://www.priv.gc.ca/en/privacy-topics/airports-and-borders/gl_dab_090127/>
- Commission d'accès à l'information du Québec, biometrics:
  <https://www.cai.gouv.qc.ca/protection-renseignements-personnels/sujets-et-domaines-dinteret/biometrie>
- Commission d'accès à l'information du Québec, private-sector obligations:
  <https://www.cai.gouv.qc.ca/protection-renseignements-personnels/information-entreprises-privees>
- Consumer Protection Ontario, contracts and cancellation:
  <https://www.ontario.ca/page/your-rights-when-signing-or-cancelling-contract>
- CRTC, cookies and computer-program consent under CASL:
  <https://crtc.gc.ca/eng/internet/install.htm>
- AWS, `CompareFaces` operation and probabilistic-result warning:
  <https://docs.aws.amazon.com/rekognition/latest/APIReference/API_CompareFaces.html>
- AWS, Rekognition data privacy:
  <https://aws.amazon.com/rekognition/faqs/>

This file is an engineering and legal-review checklist, not legal advice or a
substitute for advice from qualified counsel.
