# Google Play Data Safety working checklist

This checklist is derived from the current MapLov code and must be reconciled with every production SDK and provider before submission.

| Data category | Collected | Shared publicly/with members | Purpose | Deletable |
|---|---:|---:|---|---:|
| Name, email, phone | Yes | Name only | Account management, fraud prevention | Yes |
| Date of birth / age | Yes | Age | Adults-only access, matching | Yes |
| Gender and dating preferences | Yes | Selected profile fields | Matching and personalization | Yes |
| City, country, precise coordinates | Yes | City and approximate distance only | Nearby discovery | Yes |
| Photos and user files | Yes | According to album visibility | Profile, chat, posts, Secret Garden | Yes |
| Messages and voice recordings | Yes | Conversation participants | Messaging | Yes |
| Friends, likes, matches and comments | Yes | Relevant participants | Social and matching features | Yes |
| Reports, blocks and moderation records | Yes | No | Safety, abuse prevention, legal compliance | Subject to safety retention |
| Purchase/subscription status | Yes | No | Premium entitlements and support | Subject to financial retention |
| Diagnostics | Minimal server/security logs | No | Security and reliability | Retention policy required |

## Security declarations

- Data is encrypted in transit through HTTPS/TLS.
- PostgreSQL RLS limits access by authenticated identity and relationship.
- Raw precise coordinates are not displayed to other members.
- A user can request an in-app export and account deletion.
- Account deletion hides the profile immediately and schedules final erasure after 30 days.
- Safety and financial records may require a documented legal retention exception.

## Console forms to complete

- Data Safety
- Account deletion URL
- Privacy policy URL
- Target audience: adults only / not designed for children
- Age-restricted dating functionality
- Child Safety Standards declaration
- Content rating (IARC)
- Ads declaration: no ads in current MVP
- App access instructions for the Google reviewer
- Foreground location declaration and prominent disclosure
- In-app purchases/subscriptions declaration
