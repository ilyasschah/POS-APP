export type Lang = "en" | "fr" | "ar";

export const LANGS: { code: Lang; label: string; dir: "ltr" | "rtl" }[] = [
  { code: "en", label: "EN", dir: "ltr" },
  { code: "fr", label: "FR", dir: "ltr" },
  { code: "ar", label: "ع", dir: "rtl" },
];

export const dirOf = (l: Lang): "ltr" | "rtl" => (l === "ar" ? "rtl" : "ltr");

type Feature = { title: string; body: string };
type Platform = { name: string; detail: string };
type Faq = { q: string; a: string };
type Tier = { name: string; note: string; points: string[] };

export type Dict = {
  nav: { features: string; platforms: string; pricing: string; demo: string };
  hero: { eyebrow: string; h1: string; lede: string; cta: string; cta2: string };
  stats: { value: string; label: string; sub: string }[];
  features: { eyebrow: string; h2: string; lede: string; items: Feature[] };
  platforms: { eyebrow: string; h2: string; items: Platform[]; floorTitle: string; floorBody: string };
  pricing: { eyebrow: string; h2: string; lede: string; tiers: Tier[]; cta: string };
  faq: { eyebrow: string; h2: string; items: Faq[] };
  contact: { h2: string; lede: string; cta: string; cta2: string };
  footer: { tagline: string };
};

const en: Dict = {
  nav: { features: "Features", platforms: "Platforms", pricing: "Pricing", demo: "Book a demo" },
  hero: {
    eyebrow: "Offline-first point of sale",
    h1: "The till doesn’t stop when the internet does.",
    lede: "Octopus POS writes every sale to the terminal first and syncs afterwards. Windows counters, Android tablets, a kitchen display and an owner dashboard — one system, built to keep trading through a dead connection.",
    cta: "Book a demo",
    cta2: "See how it works",
  },
  stats: [
    { value: "2", label: "Hardware targets", sub: "Windows + Android" },
    { value: "4", label: "Connected apps", sub: "Till, KDS, web, iOS" },
    { value: "3", label: "Languages", sub: "EN / FR / AR with RTL" },
    { value: "0", label: "Sales lost offline", sub: "Local-first writes" },
  ],
  features: {
    eyebrow: "Features", h2: "Everything a service actually needs.",
    lede: "Built against real restaurant and retail workflows rather than a feature checklist.",
    items: [
      { title: "Floor plan & tables", body: "Lay out the room, move covers between tables, split and merge bills. Table state survives a lost connection." },
      { title: "Kitchen display", body: "Orders reach the pass over the local network. The KDS keeps running on the shop LAN with no internet at all." },
      { title: "Stock & split sourcing", body: "Allocate stock per line item, not per cart — product A from one warehouse, product B from another, in a single sale." },
      { title: "Modifiers & menus", body: "Nested modifier groups, forced choices and price deltas, so a cashier rings a complex order without leaving the cart." },
      { title: "Reporting & Z-reports", body: "Shift totals, Z-reports, tax breakdowns and product mix — exportable, and translated with the rest of the interface." },
      { title: "Bookings", body: "Reservations tied to the same floor plan the service runs on, so the room the host sees is the room that exists." },
      { title: "Loyalty & customers", body: "Customer accounts, loyalty cards, per-customer discounts and store credit, all resolvable while offline." },
      { title: "Refunds & voids", body: "Audited refunds and voids with reason codes and manager approval, returning stock to the warehouse it came from." },
      { title: "Hardware", body: "Receipt printers, cash drawers, barcode scanners and scales, on both Windows and Android from a single codebase." },
    ],
  },
  platforms: {
    eyebrow: "Platforms", h2: "Four screens, one system.",
    items: [
      { name: "Windows terminal", detail: "Native .exe for 10–15\" touch monitors. The full counter experience." },
      { name: "Android tablet", detail: "The same app as an .apk for 10–13\" tablets. Take orders at the table." },
      { name: "Kitchen display", detail: "A companion screen for the pass, served over the local network." },
      { name: "Owner dashboard", detail: "Takings and trends on the web, plus a native iOS app with a home-screen widget." },
    ],
    floorTitle: "Built for the floor, not the desk",
    floorBody: "Finger-sized targets rather than mouse-sized ones. Six themes including a dimmed and a night mode for low-light rooms. Full right-to-left layout for Arabic. Layouts that compute their own columns, so a 10-inch tablet and a 15-inch counter monitor both get a layout that fits instead of one that overflows.",
  },
  pricing: {
    eyebrow: "Pricing", h2: "Per terminal, per month.",
    lede: "No transaction fees and no cut of your takings.",
    cta: "Talk to us",
    tiers: [
      { name: "Single", note: "One terminal", points: ["One Windows or Android terminal", "Kitchen display included", "Offline-first sync", "Email support"] },
      { name: "Venue", note: "Up to 5 terminals", points: ["Everything in Single", "Up to five terminals", "Owner dashboard, web + iOS", "Floor plan & bookings", "Priority support"] },
      { name: "Group", note: "Multi-location", points: ["Everything in Venue", "Unlimited terminals", "Multi-location reporting", "Per-warehouse stock control", "Onboarding & migration"] },
    ],
  },
  faq: {
    eyebrow: "Questions", h2: "Before you ask.",
    items: [
      { q: "What actually happens when the internet drops?", a: "Nothing visible. Every sale is written to the terminal’s own database first and queued for the server. Staff keep ringing orders, printing receipts and sending tickets to the kitchen. When the link returns, the queue drains and conflicts resolve in the background." },
      { q: "Do I need a server in the shop?", a: "No. Terminals hold their own data and sync to the hosted API. The kitchen display talks to the terminal over the shop’s local network, so the pass keeps working even with no internet at the premises." },
      { q: "Can I mix Windows counters and Android tablets?", a: "Yes. They are the same application compiled for two targets, sharing one product catalogue, one floor plan and one set of reports." },
      { q: "What languages does it support?", a: "English, French and Arabic today, including full right-to-left layout — not a mirrored afterthought, but the layout the interface was built against." },
      { q: "Can I run more than one location?", a: "Yes. Each company is isolated at the data layer, with per-location warehouses, stock and reporting under one owner account." },
    ],
  },
  contact: {
    h2: "See it running.",
    lede: "A short walkthrough on your own menu and floor plan — including pulling the network cable mid-sale, which is the part worth watching.",
    cta: "Book a demo", cta2: "Ask a question",
  },
  footer: { tagline: "Built for counters that can’t afford to stop." },
};

const fr: Dict = {
  nav: { features: "Fonctions", platforms: "Plateformes", pricing: "Tarifs", demo: "Réserver une démo" },
  hero: {
    eyebrow: "Point de vente hors ligne d’abord",
    h1: "La caisse ne s’arrête pas quand Internet s’arrête.",
    lede: "Octopus POS enregistre chaque vente sur le terminal d’abord, puis synchronise. Comptoirs Windows, tablettes Android, écran cuisine et tableau de bord propriétaire — un seul système, conçu pour continuer à vendre sans connexion.",
    cta: "Réserver une démo", cta2: "Voir comment ça marche",
  },
  stats: [
    { value: "2", label: "Cibles matérielles", sub: "Windows + Android" },
    { value: "4", label: "Applications liées", sub: "Caisse, KDS, web, iOS" },
    { value: "3", label: "Langues", sub: "EN / FR / AR avec RTL" },
    { value: "0", label: "Ventes perdues hors ligne", sub: "Écriture locale d’abord" },
  ],
  features: {
    eyebrow: "Fonctions", h2: "Tout ce dont un service a réellement besoin.",
    lede: "Conçu à partir de vrais flux de restauration et de commerce, pas d’une liste de cases à cocher.",
    items: [
      { title: "Plan de salle & tables", body: "Organisez la salle, déplacez les couverts, divisez et fusionnez les additions. L’état des tables survit à une coupure." },
      { title: "Écran cuisine", body: "Les commandes arrivent au passe via le réseau local. Le KDS continue de fonctionner sur le LAN du magasin sans Internet." },
      { title: "Stock & approvisionnement réparti", body: "Affectez le stock par ligne, pas par panier — produit A d’un entrepôt, produit B d’un autre, dans une seule vente." },
      { title: "Options & menus", body: "Groupes d’options imbriqués, choix obligatoires et écarts de prix : le caissier saisit une commande complexe sans quitter le panier." },
      { title: "Rapports & tickets Z", body: "Totaux de service, tickets Z, ventilation des taxes et mix produits — exportables et traduits comme le reste de l’interface." },
      { title: "Réservations", body: "Réservations liées au plan de salle du service, pour que la salle vue par l’hôte soit la salle réelle." },
      { title: "Fidélité & clients", body: "Comptes clients, cartes de fidélité, remises par client et avoirs, tous utilisables hors ligne." },
      { title: "Remboursements & annulations", body: "Remboursements et annulations tracés, avec motifs et validation manager, rendant le stock à l’entrepôt d’origine." },
      { title: "Matériel", body: "Imprimantes tickets, tiroirs-caisse, douchettes et balances, sur Windows et Android depuis une seule base de code." },
    ],
  },
  platforms: {
    eyebrow: "Plateformes", h2: "Quatre écrans, un seul système.",
    items: [
      { name: "Terminal Windows", detail: "Exécutable natif pour écrans tactiles 10–15\". L’expérience comptoir complète." },
      { name: "Tablette Android", detail: "La même application en .apk pour tablettes 10–13\". Prenez les commandes à table." },
      { name: "Écran cuisine", detail: "Un écran compagnon pour le passe, servi par le réseau local." },
      { name: "Tableau de bord", detail: "Recettes et tendances sur le web, plus une app iOS native avec widget." },
    ],
    floorTitle: "Conçu pour la salle, pas pour le bureau",
    floorBody: "Des cibles à la taille du doigt, pas de la souris. Six thèmes dont un mode atténué et un mode nuit pour les salles sombres. Mise en page entièrement droite-à-gauche pour l’arabe. Des grilles qui calculent leurs colonnes, pour qu’une tablette 10 pouces et un écran 15 pouces aient chacun une mise en page adaptée.",
  },
  pricing: {
    eyebrow: "Tarifs", h2: "Par terminal, par mois.",
    lede: "Aucune commission et aucun prélèvement sur vos recettes.",
    cta: "Nous contacter",
    tiers: [
      { name: "Single", note: "Un terminal", points: ["Un terminal Windows ou Android", "Écran cuisine inclus", "Synchronisation hors ligne d’abord", "Support par e-mail"] },
      { name: "Venue", note: "Jusqu’à 5 terminaux", points: ["Tout Single", "Jusqu’à cinq terminaux", "Tableau de bord, web + iOS", "Plan de salle & réservations", "Support prioritaire"] },
      { name: "Group", note: "Multi-sites", points: ["Tout Venue", "Terminaux illimités", "Rapports multi-sites", "Stock par entrepôt", "Mise en route & migration"] },
    ],
  },
  faq: {
    eyebrow: "Questions", h2: "Avant de demander.",
    items: [
      { q: "Que se passe-t-il vraiment quand Internet tombe ?", a: "Rien de visible. Chaque vente est écrite d’abord dans la base du terminal puis mise en file. L’équipe continue de saisir, d’imprimer et d’envoyer en cuisine. Au retour du lien, la file se vide et les conflits se règlent en arrière-plan." },
      { q: "Ai-je besoin d’un serveur dans le magasin ?", a: "Non. Les terminaux conservent leurs données et se synchronisent avec l’API hébergée. L’écran cuisine dialogue avec le terminal via le réseau local, donc le passe fonctionne même sans Internet sur place." },
      { q: "Puis-je mêler comptoirs Windows et tablettes Android ?", a: "Oui. C’est la même application compilée pour deux cibles, partageant un catalogue, un plan de salle et un jeu de rapports." },
      { q: "Quelles langues sont prises en charge ?", a: "Anglais, français et arabe aujourd’hui, avec une mise en page droite-à-gauche complète — pas un miroir ajouté après coup, mais la mise en page pour laquelle l’interface a été conçue." },
      { q: "Puis-je gérer plusieurs établissements ?", a: "Oui. Chaque société est isolée au niveau des données, avec entrepôts, stocks et rapports par site sous un seul compte propriétaire." },
    ],
  },
  contact: {
    h2: "Voyez-le fonctionner.",
    lede: "Une démonstration courte sur votre propre carte et votre plan de salle — y compris le débranchement du réseau en pleine vente, qui est le moment à voir.",
    cta: "Réserver une démo", cta2: "Poser une question",
  },
  footer: { tagline: "Conçu pour les comptoirs qui ne peuvent pas s’arrêter." },
};

const ar: Dict = {
  nav: { features: "المزايا", platforms: "المنصات", pricing: "الأسعار", demo: "احجز عرضًا" },
  hero: {
    eyebrow: "نقطة بيع تعمل دون اتصال أولًا",
    h1: "الصندوق لا يتوقف عندما ينقطع الإنترنت.",
    lede: "يسجّل Octopus POS كل عملية بيع على الجهاز أولًا ثم يزامنها لاحقًا. حواسيب Windows، أجهزة Android اللوحية، شاشة مطبخ ولوحة تحكم للمالك — نظام واحد مصمم لمواصلة البيع رغم انقطاع الاتصال.",
    cta: "احجز عرضًا", cta2: "شاهد كيف يعمل",
  },
  stats: [
    { value: "٢", label: "منصتان للأجهزة", sub: "Windows + Android" },
    { value: "٤", label: "تطبيقات مترابطة", sub: "الصندوق، المطبخ، الويب، iOS" },
    { value: "٣", label: "لغات", sub: "الإنجليزية / الفرنسية / العربية" },
    { value: "٠", label: "مبيعات ضائعة دون اتصال", sub: "الكتابة محليًا أولًا" },
  ],
  features: {
    eyebrow: "المزايا", h2: "كل ما تحتاجه الخدمة فعلًا.",
    lede: "مبني على سير عمل حقيقي في المطاعم والتجزئة، لا على قائمة مزايا.",
    items: [
      { title: "مخطط القاعة والطاولات", body: "رتّب القاعة، انقل الضيوف بين الطاولات، قسّم الفواتير وادمجها. حالة الطاولات تبقى رغم انقطاع الاتصال." },
      { title: "شاشة المطبخ", body: "تصل الطلبات إلى المطبخ عبر الشبكة المحلية، وتستمر الشاشة بالعمل على شبكة المحل دون إنترنت." },
      { title: "المخزون والتوريد المُقسَّم", body: "خصّص المخزون لكل سطر لا لكل سلة — منتج من مستودع وآخر من مستودع ثانٍ في عملية بيع واحدة." },
      { title: "الإضافات والقوائم", body: "مجموعات إضافات متداخلة وخيارات إلزامية وفروق أسعار، فيسجّل الكاشير طلبًا معقدًا دون مغادرة السلة." },
      { title: "التقارير وتقرير Z", body: "إجماليات الورديات وتقارير Z وتفصيل الضرائب ومزيج المنتجات — قابلة للتصدير ومترجمة مثل بقية الواجهة." },
      { title: "الحجوزات", body: "حجوزات مرتبطة بمخطط القاعة نفسه، فتكون القاعة التي يراها المضيف هي القاعة الحقيقية." },
      { title: "الولاء والعملاء", body: "حسابات العملاء وبطاقات الولاء والخصومات الفردية والرصيد، وكلها متاحة دون اتصال." },
      { title: "المرتجعات والإلغاءات", body: "مرتجعات وإلغاءات موثّقة بأسباب وموافقة المدير، مع إعادة المخزون إلى مستودعه الأصلي." },
      { title: "الأجهزة", body: "طابعات الإيصالات وأدراج النقود والماسحات والموازين، على Windows وAndroid من قاعدة شيفرة واحدة." },
    ],
  },
  platforms: {
    eyebrow: "المنصات", h2: "أربع شاشات، نظام واحد.",
    items: [
      { name: "طرفية Windows", detail: "تطبيق أصلي لشاشات اللمس ١٠–١٥ بوصة. تجربة الكاونتر الكاملة." },
      { name: "جهاز Android لوحي", detail: "التطبيق نفسه لأجهزة ١٠–١٣ بوصة. خذ الطلبات عند الطاولة." },
      { name: "شاشة المطبخ", detail: "شاشة مرافقة للمطبخ تعمل عبر الشبكة المحلية." },
      { name: "لوحة تحكم المالك", detail: "المبيعات والاتجاهات على الويب، مع تطبيق iOS أصلي وأداة للشاشة الرئيسية." },
    ],
    floorTitle: "مصمّم للقاعة لا للمكتب",
    floorBody: "أهداف لمس بحجم الإصبع لا بحجم مؤشر الفأرة. ستة سمات منها وضع خافت ووضع ليلي للقاعات المعتمة. تخطيط عربي كامل من اليمين إلى اليسار. تخطيطات تحسب أعمدتها بنفسها، فتحصل تابلت ١٠ بوصات وشاشة ١٥ بوصة على تخطيط مناسب لكل منهما.",
  },
  pricing: {
    eyebrow: "الأسعار", h2: "لكل طرفية، شهريًا.",
    lede: "بلا رسوم على المعاملات وبلا نسبة من مبيعاتك.",
    cta: "تواصل معنا",
    tiers: [
      { name: "Single", note: "طرفية واحدة", points: ["طرفية Windows أو Android واحدة", "شاشة المطبخ مشمولة", "مزامنة تعمل دون اتصال", "دعم عبر البريد"] },
      { name: "Venue", note: "حتى ٥ طرفيات", points: ["كل مزايا Single", "حتى خمس طرفيات", "لوحة تحكم، ويب + iOS", "مخطط القاعة والحجوزات", "دعم ذو أولوية"] },
      { name: "Group", note: "فروع متعددة", points: ["كل مزايا Venue", "طرفيات غير محدودة", "تقارير متعددة الفروع", "مخزون لكل مستودع", "تهيئة ونقل البيانات"] },
    ],
  },
  faq: {
    eyebrow: "أسئلة", h2: "قبل أن تسأل.",
    items: [
      { q: "ماذا يحدث فعلًا عند انقطاع الإنترنت؟", a: "لا شيء ظاهر. تُكتب كل عملية بيع في قاعدة بيانات الجهاز أولًا ثم تُوضع في الطابور. يواصل الفريق تسجيل الطلبات وطباعة الإيصالات وإرسالها إلى المطبخ. وعند عودة الاتصال يُفرَّغ الطابور وتُحل التعارضات في الخلفية." },
      { q: "هل أحتاج إلى خادم داخل المحل؟", a: "لا. تحتفظ الطرفيات ببياناتها وتتزامن مع الواجهة المستضافة. وتتصل شاشة المطبخ بالطرفية عبر الشبكة المحلية، فيستمر العمل حتى دون إنترنت في المكان." },
      { q: "هل يمكن الجمع بين حواسيب Windows وأجهزة Android؟", a: "نعم. هو التطبيق نفسه مُجمَّعًا لمنصتين، يتشارك كتالوجًا واحدًا ومخطط قاعة واحدًا ومجموعة تقارير واحدة." },
      { q: "ما اللغات المدعومة؟", a: "الإنجليزية والفرنسية والعربية حاليًا، مع تخطيط كامل من اليمين إلى اليسار — ليس انعكاسًا أُضيف لاحقًا، بل التخطيط الذي بُنيت الواجهة عليه." },
      { q: "هل يمكنني إدارة أكثر من فرع؟", a: "نعم. كل شركة معزولة على مستوى البيانات، مع مستودعات ومخزون وتقارير لكل فرع تحت حساب مالك واحد." },
    ],
  },
  contact: {
    h2: "شاهده وهو يعمل.",
    lede: "جولة قصيرة على قائمتك ومخطط قاعتك — بما في ذلك فصل كابل الشبكة أثناء عملية بيع، وهو الجزء الذي يستحق المشاهدة.",
    cta: "احجز عرضًا", cta2: "اطرح سؤالًا",
  },
  footer: { tagline: "مصمّم لصناديق لا تحتمل التوقف." },
};

export const DICTS: Record<Lang, Dict> = { en, fr, ar };
