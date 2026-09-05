import type { GlyphName } from "./components/Glyph";
import type { SlideId } from "./components/HeroSlides";

export type Lang = "en" | "fr" | "ar";

export const LANGS: { code: Lang; label: string; name: string; dir: "ltr" | "rtl" }[] = [
  { code: "en", label: "EN", name: "English", dir: "ltr" },
  { code: "fr", label: "FR", name: "Français", dir: "ltr" },
  { code: "ar", label: "ع", name: "العربية", dir: "rtl" },
];

/**
 * Picks a supported language from the browser's ordered preference list.
 *
 * Matches on the PRIMARY SUBTAG only: a visitor reporting "fr-CA" or "ar-MA"
 * wants French or Arabic, and comparing whole tags would miss both and fall
 * back to English. Order is respected, so the browser's first supported
 * preference wins rather than whichever we happen to check first.
 */
export function detectLang(preferred: readonly string[]): Lang {
  const supported = new Set<string>(LANGS.map((l) => l.code));
  for (const tag of preferred) {
    const primary = tag.toLowerCase().split("-")[0];
    if (supported.has(primary)) return primary as Lang;
  }
  return "en";
}

export const dirOf = (l: Lang): "ltr" | "rtl" => (l === "ar" ? "rtl" : "ltr");

/* `icon` is a slug, not markup: it lives beside the copy so a translation can
   never drift onto the wrong glyph, but it is deliberately NOT translated —
   a receipt printer is a receipt printer in all three languages. */
type Feature = { icon: GlyphName; title: string; body: string };
type Platform = { icon: GlyphName; name: string; detail: string };
/** A role illustration. `img` is a file stem, never translated. */
type Role = { img: string; title: string; body: string };

type Faq = { q: string; a: string };
type Tier = { name: string; price: string; note: string; points: string[] };

export type Dict = {
  nav: { features: string; platforms: string; pricing: string; demo: string };
  hero: {
    eyebrow: string; h1: string; lede: string; cta: string; cta2: string;
    slides: Record<SlideId, string>;
    slidesNav: {
      previous: string; next: string; region: string;
      enlarge: string; close: string; zoomIn: string; zoomOut: string;
    };
  };
  roles: { eyebrow: string; h2: string; lede: string; items: Role[] };
  theme: {
    eyebrow: string; h2: string; lede: string;
    legend: string; custom: string; reset: string; applied: string;
  };
  stats: { value: string; label: string; sub: string }[];
  features: { eyebrow: string; h2: string; lede: string; items: Feature[] };
  platforms: { eyebrow: string; h2: string; items: Platform[]; floorTitle: string; floorBody: string };
  pricing: { eyebrow: string; h2: string; lede: string; tiers: Tier[]; cta: string };
  faq: { eyebrow: string; h2: string; items: Faq[] };
  contact: { h2: string; lede: string; cta: string; cta2: string };
  demo: {
    eyebrow: string; h2: string; lede: string;
    currency: string;
    items: { id: string; name: string; emoji: string; cents: number }[];
    online: string; offline: string; queued: string; cut: string; restore: string;
    empty: string; subtotal: string; tax: string; total: string;
    pay: string; paying: string; receipt: string; synced: string;
    savedLocally: string; newSale: string;
  };
  footer: { tagline: string; language: string; nav: string };
};

const en: Dict = {
  nav: { features: "Features", platforms: "Platforms", pricing: "Pricing", demo: "Book a demo" },
  hero: {
    eyebrow: "The complete point of sale",
    h1: "Everything your counter needs. Shaped the way you work.",
    lede: "Floor plans, stock, kitchen tickets, loyalty, promotions and reporting — fifteen modules on one system, running on Windows counters, Android tablets, the kitchen pass and the web. Six themes, any accent colour, three languages with full right-to-left. And it keeps selling when the connection drops.",
    cta: "Book a demo",
    cta2: "See how it works",
    slides: {
      sale: "Ringing a sale — product grid, cart, modifiers and keypad on one screen.",
      dashboard: "The management portal: monthly sales, top products, categories and customers.",
      history: "Sales history — every document, searchable, exportable and refundable.",
      display: "The customer-facing display, carrying your own branding, mirrored live from the till.",
    },
    slidesNav: {
      previous: "Previous screen", next: "Next screen", region: "Product screens",
      enlarge: "Open this screen full size", close: "Close",
      zoomIn: "Zoom to actual size", zoomOut: "Fit to screen",
    },
  },
  stats: [
    { value: "15", label: "Management modules", sub: "Stock, reports, loyalty, promotions…" },
    { value: "6", label: "Themes", sub: "Plus any accent colour" },
    { value: "3", label: "Languages", sub: "EN / FR / AR with RTL" },
    { value: "4", label: "Connected apps", sub: "Till, KDS, web, iOS" },
  ],
  roles: {
    eyebrow: "One system",
    h2: "Everyone at the counter, on the same data.",
    lede: "The till, the stockroom, the customer and the back office are not four products bolted together. They are four views of one.",
    items: [
      { img: "role-till", title: "At the till", body: "Ring a sale, split a bill, apply a promotion, take payment and print — without leaving the cart." },
      { img: "role-stock", title: "In the stockroom", body: "Count, receive and allocate stock per line item, scanning straight into the same catalogue the till sells from." },
      { img: "role-customer", title: "At the counter", body: "A branded customer display, loyalty cards and store credit, resolved on the spot — connection or not." },
      { img: "role-owner", title: "In the back office", body: "Takings, product mix, Z-reports and per-location stock, on the web and on iOS." },
    ],
  },
  theme: {
    eyebrow: "Customisable",
    h2: "Your colours, not ours.",
    lede: "Pick an accent and watch this page change. The POS does exactly the same — these are the swatches from its own Settings screen, and it builds a readable palette from whichever you choose.",
    legend: "Accent colour",
    custom: "Any colour",
    reset: "Back to brand",
    applied: "This page is re-themed live, from one colour.",
  },
  features: {
    eyebrow: "Features", h2: "Everything a service actually needs.",
    lede: "Built against real restaurant and retail workflows rather than a feature checklist.",
    items: [
      { icon: "floor-plan", title: "Floor plan & tables", body: "Lay out the room, move covers between tables, split and merge bills. Table state survives a lost connection." },
      { icon: "kitchen", title: "Kitchen display", body: "Orders reach the pass over the local network. The KDS keeps running on the shop LAN with no internet at all." },
      { icon: "stock", title: "Stock & split sourcing", body: "Allocate stock per line item, not per cart — product A from one warehouse, product B from another, in a single sale." },
      { icon: "modifiers", title: "Modifiers & menus", body: "Nested modifier groups, forced choices and price deltas, so a cashier rings a complex order without leaving the cart." },
      { icon: "reports", title: "Reporting & Z-reports", body: "Shift totals, Z-reports, tax breakdowns and product mix — exportable, and translated with the rest of the interface." },
      { icon: "bookings", title: "Bookings", body: "Reservations tied to the same floor plan the service runs on, so the room the host sees is the room that exists." },
      { icon: "loyalty", title: "Loyalty & customers", body: "Customer accounts, loyalty cards, per-customer discounts and store credit, all resolvable while offline." },
      { icon: "refunds", title: "Refunds & voids", body: "Audited refunds and voids with reason codes and manager approval, returning stock to the warehouse it came from." },
      { icon: "hardware", title: "Hardware", body: "Receipt printers, cash drawers, barcode scanners and scales, on both Windows and Android from a single codebase." },
    ],
  },
  platforms: {
    eyebrow: "Platforms", h2: "Four screens, one system.",
    items: [
      { icon: "desktop", name: "Windows terminal", detail: "Native .exe for 10–15\" touch monitors. The full counter experience." },
      { icon: "tablet", name: "Android tablet", detail: "The same app as an .apk for 10–13\" tablets. Take orders at the table." },
      { icon: "kitchen", name: "Kitchen display", detail: "A companion screen for the pass, served over the local network." },
      { icon: "dashboard", name: "Owner dashboard", detail: "Takings and trends on the web, plus a native iOS app with a home-screen widget." },
    ],
    floorTitle: "Built for the floor, not the desk",
    floorBody: "Finger-sized targets rather than mouse-sized ones. Six themes including a dimmed and a night mode for low-light rooms. Full right-to-left layout for Arabic. Layouts that compute their own columns, so a 10-inch tablet and a 15-inch counter monitor both get a layout that fits instead of one that overflows.",
  },
  pricing: {
    eyebrow: "Pricing", h2: "Per terminal, per month.",
    lede: "No transaction fees and no cut of your takings.",
    cta: "Talk to us",
    tiers: [
      { name: "Single", price: "249 DH", note: "One terminal", points: ["One Windows or Android terminal", "Kitchen display included", "Keeps selling offline", "Email support"] },
      { name: "Venue", price: "199 DH", note: "Up to 5 terminals", points: ["Everything in Single", "Up to five terminals", "Owner dashboard, web + iOS", "Floor plan & bookings", "Priority support"] },
      { name: "Group", price: "149 DH", note: "Multi-location", points: ["Everything in Venue", "Unlimited terminals", "Multi-location reporting", "Per-warehouse stock control", "Onboarding & migration"] },
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
  demo: {
    currency: "DH",
    eyebrow: "Try it", h2: "Ring a sale yourself.",
    lede: "A working miniature of the till. Add a few items, take payment, print the receipt — then cut the connection and watch it carry on.",
    items: [
      { id: "esp", name: "Espresso", emoji: "\u2615", cents: 1200 },
      { id: "cro", name: "Croissant", emoji: "\u{1F950}", cents: 800 },
      { id: "brg", name: "Burger", emoji: "\u{1F354}", cents: 5500 },
      { id: "sal", name: "Salad", emoji: "\u{1F957}", cents: 4000 },
      { id: "bev", name: "Lemonade", emoji: "\u{1F379}", cents: 2000 },
      { id: "cak", name: "Cheesecake", emoji: "\u{1F370}", cents: 3500 },
    ],
    online: "Online", offline: "Offline", queued: "{n} queued",
    cut: "Cut the connection", restore: "Reconnect",
    empty: "Tap a product to start a sale.",
    subtotal: "Subtotal", tax: "VAT 20%", total: "Total",
    pay: "Take payment", paying: "Processing…",
    receipt: "Receipt", synced: "Synced to the server.",
    savedLocally: "No connection — saved on this terminal and queued.",
    newSale: "New sale",
  },
  footer: { tagline: "Built for counters that can’t afford to stop.", language: "Language", nav: "Footer" },
};

const fr: Dict = {
  nav: { features: "Fonctions", platforms: "Plateformes", pricing: "Tarifs", demo: "Réserver une démo" },
  hero: {
    eyebrow: "Le point de vente complet",
    h1: "Tout ce dont votre comptoir a besoin. À votre façon.",
    lede: "Plan de salle, stock, tickets cuisine, fidélité, promotions et rapports — quinze modules sur un seul système, sur comptoirs Windows, tablettes Android, écran cuisine et web. Six thèmes, la couleur d’accent de votre choix, trois langues dont l’arabe en RTL complet. Et il continue de vendre quand la connexion tombe.",
    cta: "Réserver une démo",
    cta2: "Voir comment ça marche",
    slides: {
      sale: "Saisie d’une vente — grille produits, panier, options et pavé numérique sur un seul écran.",
      dashboard: "Le portail de gestion : ventes mensuelles, meilleurs produits, catégories et clients.",
      history: "Historique des ventes — chaque document, recherchable, exportable et remboursable.",
      display: "L’écran client, à vos couleurs, synchronisé en direct avec la caisse.",
    },
    slidesNav: {
      previous: "Écran précédent", next: "Écran suivant", region: "Écrans du produit",
      enlarge: "Ouvrir cet écran en grand", close: "Fermer",
      zoomIn: "Zoomer à la taille réelle", zoomOut: "Ajuster à l’écran",
    },
  },
  stats: [
    { value: "15", label: "Modules de gestion", sub: "Stock, rapports, fidélité, promotions…" },
    { value: "6", label: "Thèmes", sub: "Et la couleur de votre choix" },
    { value: "3", label: "Langues", sub: "EN / FR / AR avec RTL" },
    { value: "4", label: "Applications liées", sub: "Caisse, cuisine, web, iOS" },
  ],
  roles: {
    eyebrow: "Un seul système",
    h2: "Tout le monde au comptoir, sur les mêmes données.",
    lede: "La caisse, la réserve, le client et le bureau ne sont pas quatre produits assemblés. Ce sont quatre vues d’un seul.",
    items: [
      { img: "role-till", title: "À la caisse", body: "Saisir une vente, diviser une addition, appliquer une promotion, encaisser et imprimer — sans quitter le panier." },
      { img: "role-stock", title: "En réserve", body: "Compter, réceptionner et affecter le stock ligne par ligne, en scannant directement dans le catalogue que la caisse vend." },
      { img: "role-customer", title: "Au comptoir", body: "Un écran client à vos couleurs, cartes de fidélité et avoirs, résolus sur place — avec ou sans connexion." },
      { img: "role-owner", title: "Au bureau", body: "Recettes, mix produits, tickets Z et stock par site, sur le web et sur iOS." },
    ],
  },
  theme: {
    eyebrow: "Personnalisable",
    h2: "Vos couleurs, pas les nôtres.",
    lede: "Choisissez une couleur et regardez cette page changer. Le POS fait exactement pareil — ce sont les teintes de son propre écran Réglages, et il construit une palette lisible à partir de celle que vous choisissez.",
    legend: "Couleur d’accent",
    custom: "Une autre couleur",
    reset: "Revenir à la marque",
    applied: "Cette page se re-thématise en direct, à partir d’une seule couleur.",
  },
  features: {
    eyebrow: "Fonctions", h2: "Tout ce dont un service a réellement besoin.",
    lede: "Conçu à partir de vrais flux de restauration et de commerce, pas d’une liste de cases à cocher.",
    items: [
      { icon: "floor-plan", title: "Plan de salle & tables", body: "Organisez la salle, déplacez les couverts, divisez et fusionnez les additions. L’état des tables survit à une coupure." },
      { icon: "kitchen", title: "Écran cuisine", body: "Les commandes arrivent au passe via le réseau local. Le KDS continue de fonctionner sur le LAN du magasin sans Internet." },
      { icon: "stock", title: "Stock & approvisionnement réparti", body: "Affectez le stock par ligne, pas par panier — produit A d’un entrepôt, produit B d’un autre, dans une seule vente." },
      { icon: "modifiers", title: "Options & menus", body: "Groupes d’options imbriqués, choix obligatoires et écarts de prix : le caissier saisit une commande complexe sans quitter le panier." },
      { icon: "reports", title: "Rapports & tickets Z", body: "Totaux de service, tickets Z, ventilation des taxes et mix produits — exportables et traduits comme le reste de l’interface." },
      { icon: "bookings", title: "Réservations", body: "Réservations liées au plan de salle du service, pour que la salle vue par l’hôte soit la salle réelle." },
      { icon: "loyalty", title: "Fidélité & clients", body: "Comptes clients, cartes de fidélité, remises par client et avoirs, tous utilisables hors ligne." },
      { icon: "refunds", title: "Remboursements & annulations", body: "Remboursements et annulations tracés, avec motifs et validation manager, rendant le stock à l’entrepôt d’origine." },
      { icon: "hardware", title: "Matériel", body: "Imprimantes tickets, tiroirs-caisse, douchettes et balances, sur Windows et Android depuis une seule base de code." },
    ],
  },
  platforms: {
    eyebrow: "Plateformes", h2: "Quatre écrans, un seul système.",
    items: [
      { icon: "desktop", name: "Terminal Windows", detail: "Exécutable natif pour écrans tactiles 10–15\". L’expérience comptoir complète." },
      { icon: "tablet", name: "Tablette Android", detail: "La même application en .apk pour tablettes 10–13\". Prenez les commandes à table." },
      { icon: "kitchen", name: "Écran cuisine", detail: "Un écran compagnon pour le passe, servi par le réseau local." },
      { icon: "dashboard", name: "Tableau de bord", detail: "Recettes et tendances sur le web, plus une app iOS native avec widget." },
    ],
    floorTitle: "Conçu pour la salle, pas pour le bureau",
    floorBody: "Des cibles à la taille du doigt, pas de la souris. Six thèmes dont un mode atténué et un mode nuit pour les salles sombres. Mise en page entièrement droite-à-gauche pour l’arabe. Des grilles qui calculent leurs colonnes, pour qu’une tablette 10 pouces et un écran 15 pouces aient chacun une mise en page adaptée.",
  },
  pricing: {
    eyebrow: "Tarifs", h2: "Par terminal, par mois.",
    lede: "Aucune commission et aucun prélèvement sur vos recettes.",
    cta: "Nous contacter",
    tiers: [
      { name: "Single", price: "249 DH", note: "Un terminal", points: ["Un terminal Windows ou Android", "Écran cuisine inclus", "Continue de vendre hors ligne", "Support par e-mail"] },
      { name: "Venue", price: "199 DH", note: "Jusqu’à 5 terminaux", points: ["Tout Single", "Jusqu’à cinq terminaux", "Tableau de bord, web + iOS", "Plan de salle & réservations", "Support prioritaire"] },
      { name: "Group", price: "149 DH", note: "Multi-sites", points: ["Tout Venue", "Terminaux illimités", "Rapports multi-sites", "Stock par entrepôt", "Mise en route & migration"] },
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
  demo: {
    currency: "DH",
    eyebrow: "Essayez", h2: "Encaissez vous-même.",
    lede: "Une miniature fonctionnelle de la caisse. Ajoutez des articles, encaissez, imprimez le ticket — puis coupez la connexion et regardez-la continuer.",
    items: [
      { id: "esp", name: "Espresso", emoji: "\u2615", cents: 1200 },
      { id: "cro", name: "Croissant", emoji: "\u{1F950}", cents: 800 },
      { id: "brg", name: "Burger", emoji: "\u{1F354}", cents: 5500 },
      { id: "sal", name: "Salade", emoji: "\u{1F957}", cents: 4000 },
      { id: "bev", name: "Limonade", emoji: "\u{1F379}", cents: 2000 },
      { id: "cak", name: "Cheesecake", emoji: "\u{1F370}", cents: 3500 },
    ],
    online: "En ligne", offline: "Hors ligne", queued: "{n} en attente",
    cut: "Couper la connexion", restore: "Reconnecter",
    empty: "Touchez un produit pour commencer.",
    subtotal: "Sous-total", tax: "TVA 20 %", total: "Total",
    pay: "Encaisser", paying: "Traitement…",
    receipt: "Ticket", synced: "Synchronisé avec le serveur.",
    savedLocally: "Pas de connexion — enregistré sur ce terminal et mis en attente.",
    newSale: "Nouvelle vente",
  },
  footer: { tagline: "Conçu pour les comptoirs qui ne peuvent pas s’arrêter.", language: "Langue", nav: "Pied de page" },
};

const ar: Dict = {
  nav: { features: "المزايا", platforms: "المنصات", pricing: "الأسعار", demo: "احجز عرضًا" },
  hero: {
    eyebrow: "نقطة البيع المتكاملة",
    h1: "كل ما يحتاجه صندوقك. وبالشكل الذي يناسبك.",
    lede: "مخطط القاعة والمخزون وتذاكر المطبخ والولاء والعروض والتقارير — خمسة عشر وحدة في نظام واحد، على حواسيب Windows وأجهزة Android اللوحية وشاشة المطبخ والويب. ستة سمات، وأي لون تختاره، وثلاث لغات بدعم كامل للكتابة من اليمين إلى اليسار. ويواصل البيع عند انقطاع الاتصال.",
    cta: "احجز عرضًا",
    cta2: "شاهد كيف يعمل",
    slides: {
      sale: "تسجيل عملية بيع — شبكة المنتجات والسلة والإضافات ولوحة الأرقام في شاشة واحدة.",
      dashboard: "بوابة الإدارة: المبيعات الشهرية وأفضل المنتجات والفئات والعملاء.",
      history: "سجل المبيعات — كل مستند، قابل للبحث والتصدير والاسترجاع.",
      display: "شاشة العميل بعلامتك التجارية، متزامنة مباشرة مع الصندوق.",
    },
    slidesNav: {
      previous: "الشاشة السابقة", next: "الشاشة التالية", region: "شاشات المنتج",
      enlarge: "افتح هذه الشاشة بالحجم الكامل", close: "إغلاق",
      zoomIn: "تكبير إلى الحجم الأصلي", zoomOut: "ملاءمة الشاشة",
    },
  },
  stats: [
    { value: "١٥", label: "وحدات الإدارة", sub: "المخزون، التقارير، الولاء، العروض…" },
    { value: "٦", label: "سمات", sub: "وأي لون تختاره" },
    { value: "٣", label: "لغات", sub: "الإنجليزية / الفرنسية / العربية بدعم RTL" },
    { value: "٤", label: "تطبيقات مترابطة", sub: "الصندوق، المطبخ، الويب، iOS" },
  ],
  roles: {
    eyebrow: "نظام واحد",
    h2: "الجميع حول المنضدة، على البيانات نفسها.",
    lede: "الصندوق والمستودع والعميل والمكتب ليست أربعة منتجات مجمّعة، بل أربع واجهات لنظام واحد.",
    items: [
      { img: "role-till", title: "عند الصندوق", body: "سجّل بيعًا، قسّم فاتورة، طبّق عرضًا، اقبض واطبع — دون مغادرة السلة." },
      { img: "role-stock", title: "في المستودع", body: "جرد واستلم وخصّص المخزون لكل سطر، بالمسح مباشرة إلى الكتالوج الذي يبيع منه الصندوق." },
      { img: "role-customer", title: "أمام العميل", body: "شاشة عميل بعلامتك، وبطاقات ولاء ورصيد، تُحسم في مكانها — باتصال أو دونه." },
      { img: "role-owner", title: "في المكتب", body: "الإيرادات ومزيج المنتجات وتقارير Z والمخزون لكل فرع، على الويب وعلى iOS." },
    ],
  },
  theme: {
    eyebrow: "قابل للتخصيص",
    h2: "ألوانك أنت، لا ألواننا.",
    lede: "اختر لونًا وشاهد هذه الصفحة تتغيّر. يفعل النظام الشيء نفسه تمامًا — هذه هي الألوان الموجودة في شاشة الإعدادات، ويبني منها لوحة ألوان مقروءة.",
    legend: "لون التمييز",
    custom: "لون آخر",
    reset: "العودة إلى لون العلامة",
    applied: "تُعاد تهيئة ألوان هذه الصفحة مباشرة، انطلاقًا من لون واحد.",
  },
  features: {
    eyebrow: "المزايا", h2: "كل ما تحتاجه الخدمة فعلًا.",
    lede: "مبني على سير عمل حقيقي في المطاعم والتجزئة، لا على قائمة مزايا.",
    items: [
      { icon: "floor-plan", title: "مخطط القاعة والطاولات", body: "رتّب القاعة، انقل الضيوف بين الطاولات، قسّم الفواتير وادمجها. حالة الطاولات تبقى رغم انقطاع الاتصال." },
      { icon: "kitchen", title: "شاشة المطبخ", body: "تصل الطلبات إلى المطبخ عبر الشبكة المحلية، وتستمر الشاشة بالعمل على شبكة المحل دون إنترنت." },
      { icon: "stock", title: "المخزون والتوريد المُقسَّم", body: "خصّص المخزون لكل سطر لا لكل سلة — منتج من مستودع وآخر من مستودع ثانٍ في عملية بيع واحدة." },
      { icon: "modifiers", title: "الإضافات والقوائم", body: "مجموعات إضافات متداخلة وخيارات إلزامية وفروق أسعار، فيسجّل الكاشير طلبًا معقدًا دون مغادرة السلة." },
      { icon: "reports", title: "التقارير وتقرير Z", body: "إجماليات الورديات وتقارير Z وتفصيل الضرائب ومزيج المنتجات — قابلة للتصدير ومترجمة مثل بقية الواجهة." },
      { icon: "bookings", title: "الحجوزات", body: "حجوزات مرتبطة بمخطط القاعة نفسه، فتكون القاعة التي يراها المضيف هي القاعة الحقيقية." },
      { icon: "loyalty", title: "الولاء والعملاء", body: "حسابات العملاء وبطاقات الولاء والخصومات الفردية والرصيد، وكلها متاحة دون اتصال." },
      { icon: "refunds", title: "المرتجعات والإلغاءات", body: "مرتجعات وإلغاءات موثّقة بأسباب وموافقة المدير، مع إعادة المخزون إلى مستودعه الأصلي." },
      { icon: "hardware", title: "الأجهزة", body: "طابعات الإيصالات وأدراج النقود والماسحات والموازين، على Windows وAndroid من قاعدة شيفرة واحدة." },
    ],
  },
  platforms: {
    eyebrow: "المنصات", h2: "أربع شاشات، نظام واحد.",
    items: [
      { icon: "desktop", name: "طرفية Windows", detail: "تطبيق أصلي لشاشات اللمس ١٠–١٥ بوصة. تجربة الكاونتر الكاملة." },
      { icon: "tablet", name: "جهاز Android لوحي", detail: "التطبيق نفسه لأجهزة ١٠–١٣ بوصة. خذ الطلبات عند الطاولة." },
      { icon: "kitchen", name: "شاشة المطبخ", detail: "شاشة مرافقة للمطبخ تعمل عبر الشبكة المحلية." },
      { icon: "dashboard", name: "لوحة تحكم المالك", detail: "المبيعات والاتجاهات على الويب، مع تطبيق iOS أصلي وأداة للشاشة الرئيسية." },
    ],
    floorTitle: "مصمّم للقاعة لا للمكتب",
    floorBody: "أهداف لمس بحجم الإصبع لا بحجم مؤشر الفأرة. ستة سمات منها وضع خافت ووضع ليلي للقاعات المعتمة. تخطيط عربي كامل من اليمين إلى اليسار. تخطيطات تحسب أعمدتها بنفسها، فتحصل تابلت ١٠ بوصات وشاشة ١٥ بوصة على تخطيط مناسب لكل منهما.",
  },
  pricing: {
    eyebrow: "الأسعار", h2: "لكل طرفية، شهريًا.",
    lede: "بلا رسوم على المعاملات وبلا نسبة من مبيعاتك.",
    cta: "تواصل معنا",
    tiers: [
      { name: "Single", price: "249 د.م.", note: "طرفية واحدة", points: ["طرفية Windows أو Android واحدة", "شاشة المطبخ مشمولة", "يواصل البيع دون اتصال", "دعم عبر البريد"] },
      { name: "Venue", price: "199 د.م.", note: "حتى ٥ طرفيات", points: ["كل مزايا Single", "حتى خمس طرفيات", "لوحة تحكم، ويب + iOS", "مخطط القاعة والحجوزات", "دعم ذو أولوية"] },
      { name: "Group", price: "149 د.م.", note: "فروع متعددة", points: ["كل مزايا Venue", "طرفيات غير محدودة", "تقارير متعددة الفروع", "مخزون لكل مستودع", "تهيئة ونقل البيانات"] },
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
  demo: {
    currency: "د.م.",
    eyebrow: "جرّبه", h2: "سجّل عملية بيع بنفسك.",
    lede: "نموذج مصغّر يعمل فعلًا. أضف بعض الأصناف، استلم الدفع، اطبع الإيصال — ثم اقطع الاتصال وشاهده يواصل العمل.",
    items: [
      { id: "esp", name: "إسبريسو", emoji: "\u2615", cents: 1200 },
      { id: "cro", name: "كرواسون", emoji: "\u{1F950}", cents: 800 },
      { id: "brg", name: "برغر", emoji: "\u{1F354}", cents: 5500 },
      { id: "sal", name: "سلطة", emoji: "\u{1F957}", cents: 4000 },
      { id: "bev", name: "ليموناضة", emoji: "\u{1F379}", cents: 2000 },
      { id: "cak", name: "تشيزكيك", emoji: "\u{1F370}", cents: 3500 },
    ],
    online: "متصل", offline: "غير متصل", queued: "{n} في الطابور",
    cut: "اقطع الاتصال", restore: "أعد الاتصال",
    empty: "اضغط على منتج لبدء عملية بيع.",
    subtotal: "المجموع الفرعي", tax: "ضريبة ٢٠٪", total: "الإجمالي",
    pay: "استلام الدفع", paying: "جارٍ المعالجة…",
    receipt: "إيصال", synced: "تمت المزامنة مع الخادم.",
    savedLocally: "لا يوجد اتصال — حُفظ على هذا الجهاز وأُضيف إلى الطابور.",
    newSale: "عملية بيع جديدة",
  },
  footer: { tagline: "مصمّم لصناديق لا تحتمل التوقف.", language: "اللغة", nav: "تذييل الصفحة" },
};

export const DICTS: Record<Lang, Dict> = { en, fr, ar };
