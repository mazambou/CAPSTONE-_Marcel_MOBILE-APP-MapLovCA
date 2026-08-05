# Préparation des paiements Stripe, PayPal et Flutterwave

## État de l’intégration

Le code est préparé, mais les paiements externes restent volontairement
désactivés par défaut :

- le serveur exige `EXTERNAL_CHECKOUT_ENABLED=true`;
- Flutter n’affiche ces prestataires que sur le Web avec le
  `dart-define` correspondant;
- iOS et Android continuent d’utiliser Apple In-App Purchase et Google Play
  Billing;
- aucune clé secrète n’est incluse dans l’application Flutter.

Cette double activation évite de publier par erreur un bouton externe avant la
configuration des comptes marchands, des webhooks et des règles applicables.

## Architecture

1. L’utilisateur connecté choisit un abonnement, ou un achat ponctuel Stripe,
   sur le Web.
2. `create-external-checkout` choisit le prix ou plan depuis les secrets
   Supabase, crée une référence opaque liée au compte, puis demande au
   prestataire une page de paiement hébergée.
3. Le navigateur n’ouvre que des URL HTTPS appartenant à Stripe, PayPal ou
   Flutterwave.
4. `external-billing-webhook` vérifie cryptographiquement le webhook et relit
   l’abonnement ou la transaction directement chez le prestataire.
5. La fonction PostgreSQL réservée au `service_role` retrouve le compte et le
   niveau depuis la session créée par le serveur. Le webhook ne peut pas choisir
   arbitrairement un utilisateur ou lui accorder VIP.
6. L’identifiant d’événement et celui de transaction rendent les répétitions de
   webhooks idempotentes.

La référence de checkout est un UUID : elle respecte notamment la limite de
38 caractères de `PayPal-Request-Id` et sert aussi de clé d’idempotence lors de
la création de l’abonnement PayPal.

## 1. Créer le catalogue produit

Les identifiants canoniques MapLov sont :

| Type | Produit MapLov | Facturation |
| --- | --- | --- |
| Plus | `maplov_plus_monthly` | mensuelle |
| Plus | `maplov_plus_yearly` | annuelle |
| VIP | `maplov_vip_monthly` | mensuelle |
| VIP | `maplov_vip_yearly` | annuelle |
| Country Pass | `maplov_country_pass_24h` | unique |
| Country Pass | `maplov_country_pass_7d` | unique |
| International Pass | `maplov_international_pass_24h` | unique |
| International Pass | `maplov_international_pass_7d` | unique |
| Boost | `maplov_boost_30m` | unique |
| Boost | `maplov_boost_3h` | unique |
| Boost | `maplov_boost_24h` | unique |
| Super Likes | `maplov_super_likes_5` | unique |
| Super Likes | `maplov_super_likes_15` | unique |
| Super Likes | `maplov_super_likes_30` | unique |

Tarifs d’abonnement en production :

- Plus : 12,99 $ CAD par mois ou 99,99 $ CAD par an, soit 55,89 $
  d’économie (36 %);
- VIP : 19,99 $ CAD par mois ou 149,99 $ CAD par an, soit 89,89 $
  d’économie (37 %).

Tarifs approuvés des achats ponctuels :

| Produit | Prix CAD |
| --- | ---: |
| Country Pass 24 h | 2,99 $ |
| Country Pass 7 jours | 6,99 $ |
| International Pass 24 h | 4,99 $ |
| International Pass 7 jours | 9,99 $ |
| Boost 30 min | 2,99 $ |
| Boost 3 h | 4,99 $ |
| Boost 24 h | 7,99 $ |
| Super Likes ×5 | 2,99 $ |
| Super Likes ×15 | 6,99 $ |
| Super Likes ×30 | 11,99 $ |

Les montants configurés dans Stripe doivent correspondre exactement à cette
grille en dollars canadiens avant l’activation en production.

Les montants, taxes, devises et textes affichés sur chaque page hébergée doivent
être vérifiés avant le lancement.

### Stripe

Déployer `sync-stripe-catalog`, se connecter avec un compte administrateur,
puis ouvrir **Administration > Catalogue Stripe > Synchroniser avec Stripe**.
Cette opération idempotente crée ou vérifie les quatre prix récurrents et les
dix prix à paiement unique en CAD. Chaque Price utilise l’identifiant canonique
MapLov comme `lookup_key`; le checkout résout ensuite le Price ID côté serveur
et vérifie son montant, sa devise et sa périodicité. Il n’est donc plus
nécessaire de maintenir quatorze secrets `STRIPE_*_PRICE_ID`.

La clé publiable peut rester dans les secrets Supabase, mais le parcours
Checkout hébergé ne l’envoie pas à Flutter. La clé secrète Stripe n’est lue que
par les Edge Functions. Les durées et quantités sont validées côté serveur :
elles ne sont jamais acceptées depuis le navigateur.

Les Pass créent des droits temporaires, les Boosts créent une période de mise
en avant et les packs alimentent un solde de Super Likes. Les répétitions du
même webhook Stripe ne prolongent ni ne créditent une seconde fois l’achat.

### Promotions administrables

La rubrique **Administration > Promotions** permet à un administrateur de
programmer une campagne sans modifier l’application : nom commercial, produit,
prix normal, prix réduit, début, fin et état actif. Les heures font partie de
la période afin de permettre une offre « aujourd’hui seulement ».

Avant de créer la campagne dans MapLov, créer dans Stripe un Price distinct au
montant promotionnel, dans la même devise et avec le même type de facturation
que le produit concerné. Copier son identifiant `price_...` dans la promotion.
Le prix saisi dans l’administration sert à l’affichage; le Price Stripe est la
source facturée. Ces deux valeurs doivent donc correspondre exactement.

Lorsqu’une campagne active couvre un produit, la boutique Web affiche le prix
normal barré, le prix promotionnel, le nom de la campagne et son échéance. Le
serveur sélectionne lui-même le Price promotionnel lors du checkout et conserve
l’identifiant de la campagne dans la session de paiement. Si plusieurs
campagnes se chevauchent, le prix actif le plus bas est retenu. Désactiver une
campagne ou atteindre sa date de fin restaure automatiquement le tarif normal.

Les promotions Stripe ne sont pas affichées dans les builds Android/iOS, dont
les achats numériques passent par les boutiques natives. Une promotion mobile
doit être configurée séparément dans Google Play ou App Store Connect.

### PayPal

Créer les produits puis deux plans mensuels. Les achats annuels et ponctuels
restent Stripe uniquement. Reporter leurs identifiants
`P-...` dans `PAYPAL_PLUS_PLAN_ID` et `PAYPAL_VIP_PLAN_ID`.

### Flutterwave

Créer deux payment plans mensuels. Les achats annuels et ponctuels restent
Stripe uniquement. La devise envoyée au premier paiement doit
être celle du plan. Reporter les identifiants dans
`FLUTTERWAVE_PLUS_PLAN_ID` et `FLUTTERWAVE_VIP_PLAN_ID`.

Vérifier avec Flutterwave que le compte marchand et la devise choisis acceptent
les paiements récurrents par carte. Les abonnements Flutterwave sont attachés à
l’adresse courriel du client : un changement de courriel exige une procédure
de résiliation et de réabonnement.

## 2. Configurer les secrets Supabase

Copier `supabase/external-payments.env.example` vers un fichier ignoré :

```bash
cp supabase/external-payments.env.example supabase/.env.external-payments
```

Remplacer tous les placeholders. Conserver d’abord
`EXTERNAL_CHECKOUT_ENABLED=false`, puis charger les secrets :

```bash
supabase secrets set --env-file supabase/.env.external-payments
```

Les URL de succès et d’annulation prévues pour Flutter Web sont :

```text
https://maplov.ca/premium/external-return
```

`EXTERNAL_CHECKOUT_ALLOWED_ORIGINS` doit contenir uniquement les origines Web
réellement déployées, sans chemin. Ajouter une origine locale uniquement pendant
les essais locaux, par exemple `http://localhost:8080`.

Comme Flutter Web utilise des URL sans `#`, l’hébergeur doit réécrire
`/premium/external-return` et `/premium/subscription` vers `index.html`.

## 3. Déployer le schéma et les fonctions

```bash
supabase db push
supabase functions deploy create-external-checkout
supabase functions deploy sync-stripe-catalog
supabase functions deploy manage-external-subscription
supabase functions deploy external-billing-webhook --no-verify-jwt
```

L’URL de base des webhooks est :

```text
https://heqkgexzlhdnmrkuikle.supabase.co/functions/v1/external-billing-webhook
```

Configurer un endpoint distinct par prestataire :

```text
?provider=stripe
?provider=paypal
?provider=flutterwave
```

### Événements Stripe

Enregistrer au minimum :

- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `checkout.session.async_payment_failed`
- `checkout.session.expired`
- `payment_intent.payment_failed`
- `invoice.paid`
- `invoice.payment_succeeded`
- `invoice.payment_failed`
- `customer.subscription.updated`
- `customer.subscription.deleted`

Copier le signing secret de cet endpoint dans `STRIPE_WEBHOOK_SECRET`.
Activer également le Stripe Customer Portal : le bouton de gestion MapLov y
redirige l’abonné pour modifier ou résilier son abonnement.

Les retours d’annulation marquent uniquement la tentative appartenant au
compte connecté. Les échecs asynchrones et expirations proviennent du webhook
signé. Un état payé ne peut jamais être rétrogradé par le navigateur.

### Événements PayPal

Enregistrer au minimum :

- `BILLING.SUBSCRIPTION.ACTIVATED`
- `BILLING.SUBSCRIPTION.UPDATED`
- `BILLING.SUBSCRIPTION.CANCELLED`
- `BILLING.SUBSCRIPTION.EXPIRED`
- `BILLING.SUBSCRIPTION.SUSPENDED`
- `BILLING.SUBSCRIPTION.PAYMENT.FAILED`
- `PAYMENT.SALE.COMPLETED`

Copier l’identifiant du webhook dans `PAYPAL_WEBHOOK_ID`. Le code demande
ensuite à l’API PayPal de vérifier chaque signature. Le bouton de gestion ouvre
la page PayPal des paiements automatiques.

### Événements Flutterwave

Ajouter l’URL Flutterwave, activer les webhooks JSON et les répétitions, puis
configurer un secret hash long et aléatoire identique à
`FLUTTERWAVE_SECRET_HASH`. Le flux traite `charge.completed`, relit la
transaction par son identifiant et compare exactement le montant et la devise
à la session MapLov. La recherche d’abonnement utilise aussi le filtre
`transaction_id` de Flutterwave afin de ne pas confondre deux abonnements d’une
même adresse courriel. Un paiement initial vérifié comme échoué marque seulement
la tentative comme échouée et n’accorde aucun avantage. MapLov appelle
l’endpoint officiel de désactivation après confirmation de l’utilisateur, sans
annuler le payment plan des autres clients.

## 4. Recette sandbox obligatoire

Effectuer la recette avec un compte MapLov de test différent pour chaque cas :

- achat Plus réussi avec chacun des trois prestataires;
- achat VIP réussi;
- abonnements Plus et VIP annuels réussis par Stripe;
- chacun des dix achats ponctuels Stripe crée exactement le droit temporaire
  ou le nombre de crédits attendu;
- deux achats successifs du même Pass empilent leurs durées;
- deux packs de Super Likes additionnent leurs quantités;
- annulation avant paiement, sans abonnement créé;
- webhook rejoué deux fois, avec une seule transaction en base;
- montant ou devise Flutterwave incorrects, sans activation;
- signature webhook incorrecte, réponse HTTP 401;
- paiement refusé et renouvellement échoué;
- résiliation puis maintien de l’accès jusqu’à la fin de la période payée;
- expiration et remboursement;
- tentative d’un second abonnement refusée tant qu’un abonnement courant existe,
  afin d’éviter une double facturation lors d’un changement Plus/VIP;
- retour navigateur lent : l’écran attend le webhook sans proposer de repayer;
- vérification que le nom, le montant, la devise, les taxes et le renouvellement
  sont cohérents sur la page hébergée.

Ne passer les clés et comptes en production qu’après cette recette.

## Mise en service Stripe de test — actions manuelles restantes

Les migrations `045` à `047` et les fonctions de facturation sont déjà
déployées sur le projet Supabase `heqkgexzlhdnmrkuikle`. Les URL sont
configurées et `EXTERNAL_CHECKOUT_ENABLED` reste volontairement à `false`.

1. Publier le contenu de `build/web` sur `https://maplov.ca` avec les règles de
   réécriture indiquées plus haut.
2. Se connecter à MapLov avec un compte ayant le rôle `admin`, ouvrir
   **Administration > Catalogue Stripe**, puis cliquer sur
   **Synchroniser avec Stripe**. Vérifier que les 14 lignes et leurs Price IDs
   apparaissent. Cette action peut être répétée sans créer de doublons.
3. Dans Stripe Workbench > Webhooks, créer l’endpoint :
   `https://heqkgexzlhdnmrkuikle.supabase.co/functions/v1/external-billing-webhook?provider=stripe`.
   Sélectionner exactement les événements Stripe listés dans la section
   précédente.
4. Révéler le signing secret `whsec_...`, puis l’enregistrer sans le placer
   dans Flutter :

   ```bash
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_REMPLACER
   ```

5. Dans Stripe, activer et configurer le Customer Portal pour permettre la
   gestion et la résiliation des abonnements.
6. Activer seulement ensuite le serveur :

   ```bash
   supabase secrets set EXTERNAL_CHECKOUT_ENABLED=true
   ```

7. Effectuer toute la recette sandbox. Pour les paiements par carte réussis,
   utiliser la carte de test Stripe `4242 4242 4242 4242`, une date future et
   un CVC quelconque. Tester également une carte refusée depuis la liste
   officielle des cartes de test Stripe.

Le passage en production nécessitera de remplacer les clés par `sk_live_...`
et `pk_live_...`, de synchroniser une seconde fois le catalogue en mode Live,
de créer un webhook Live distinct et de refaire intégralement la recette.

## 5. Activer le Web

Après la recette, définir le secret serveur sur `true`, puis compiler la version
Web avec le drapeau client :

```bash
flutter build web \
  --dart-define=EXTERNAL_CHECKOUT_ENABLED=true
```

Une seule des deux activations ne suffit pas. Ne fournir aucun
`STRIPE_SECRET_KEY`, `PAYPAL_CLIENT_SECRET`, `FLUTTERWAVE_SECRET_KEY`,
webhook secret ou clé Supabase `service_role` dans un `dart-define`.

## Règles App Store et Google Play

MapLov vend des fonctions numériques consommées dans l’application. Les boutons
Stripe, PayPal et Flutterwave ne sont donc pas affichés dans les builds mobiles
généraux. L’utilisation d’un lien ou d’une facturation alternative sur mobile
doit être examinée séparément par territoire et programme de boutique avant
toute modification.

Références officielles :

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en)
- [Stripe Checkout](https://docs.stripe.com/payments/checkout)
- [Stripe webhook signatures](https://docs.stripe.com/webhooks/signature)
- [PayPal Subscriptions](https://developer.paypal.com/docs/subscriptions/integrate/)
- [PayPal webhook verification](https://developer.paypal.com/api/rest/webhooks/rest/)
- [Flutterwave Standard](https://developer.flutterwave.com/v3.0/docs/flutterwave-standard-1)
- [Flutterwave payment plans](https://developer.flutterwave.com/v3.0/docs/payment-plans-1)
- [Flutterwave webhook signatures](https://developer.flutterwave.com/docs/webhooks)
- [Flutterwave transaction verification](https://developer.flutterwave.com/v3.0/docs/transaction-verification)
