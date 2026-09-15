import type { GlyphName } from "../components/Glyph";
import type { Lang } from "../i18n";

/*
 * The help centre's copy, in the site's three languages.
 *
 * Every step describes what the app ACTUALLY does, and every word the operator
 * will see on screen is written the way the app writes it — taken from the
 * app's own translations (Front-End/lib/l10n/app_*.arb) — and wrapped in
 * [[double brackets]], which render as a quiet chip. If a label changes in the
 * app, change it here too, or the guide sends people looking for a button that
 * no longer exists.
 *
 * Screenshots are real captures of the running app, never mockups (DESIGN.md
 * §8). An article without a capture simply has no figure: a visitor is never
 * shown a placeholder.
 */

export type HelpShot = { src: string; width: number; height: number; alt: string; caption: string };

export type HelpArticle = {
  /** Anchor id — identical in every language, so a shared link works for all. */
  id: string;
  title: string;
  summary: string;
  steps: string[];
  note?: string;
  shot?: HelpShot;
};

export type HelpSection = {
  id: string;
  icon: GlyphName;
  title: string;
  summary: string;
  /** Troubleshooting reads as questions: collapsed until opened. */
  faq?: boolean;
  articles: HelpArticle[];
};

export type HelpDict = {
  eyebrow: string;
  h1: string;
  lede: string;
  search: { label: string; placeholder: string; clear: string; none: (query: string) => string };
  topics: string;
  onThisPage: string;
  articles: (count: number) => string;
  note: string;
  stuck: { h2: string; lede: string; cta: string; cta2: string };
  sections: HelpSection[];
};

const REGISTRATION = { src: "/help/device-registration.png", width: 560, height: 540 };
const TERMINAL_SETUP = { src: "/help/terminal-setup.png", width: 852, height: 780 };
const DATA_SOURCE = { src: "/help/data-source-choice.png", width: 852, height: 780 };
const business_type = { src: "/help/business-type.png", width: 852, height: 780 };
const sign_in = { src: "/help/pin-sign-in.png", width: 852, height: 780 };
const open_register = { src: "/help/opening-control.png", width: 852, height: 780 };
const make_sale = { src: "/help/sale-screen.png", width: 852, height: 780 };
const floor_plan = { src: "/help/floor-plan.png", width: 852, height: 780 };
const refund_dialog = { src: "/help/refund-dialog.png", width: 852, height: 780 };
const cash_in_out = { src: "/help/cash-in-out.png", width: 852, height: 780 };
const closing_register = { src: "/help/closing-register.png", width: 852, height: 780 };
const offline_pending_sync = { src: "/help/offline-pending-sync.png", width: 852, height: 780 };
const sync_status_panel = { src: "/help/sync-status-panel.png", width: 852, height: 780 };
const database_backup_settings = { src: "/help/database-backup-settings.png", width: 852, height: 780 };
const product_editor = { src: "/help/product-editor.png", width: 852, height: 780 };
const stock_warehouses = { src: "/help/stock-warehouses.png", width: 852, height: 780 };
const customer_loyalty = { src: "/help/customer-loyalty.png", width: 852, height: 780 };
const security_rules = { src: "/help/security-rules.png", width: 852, height: 780 };
const reports = { src: "/help/reports.png", width: 852, height: 780 };
const kitchen_display_settings = { src: "/help/kitchen-display-settings.png", width: 852, height: 780 };
const customer_display_qr = { src: "/help/customer-display-qr.png", width: 852, height: 780 };
const weighing_scale_settings = { src: "/help/weighing-scale-settings.png", width: 852, height: 780 };
const subscription_inactive = { src: "/help/subscription-inactive.png", width: 852, height: 780 };
const cashier_refused = { src: "/help/cashier-refused.png", width: 852, height: 780 };


/* -------------------------------------------------------------------------- */

const en: HelpDict = {
  eyebrow: "Help centre",
  h1: "Everything you need to run the till.",
  lede: "Step-by-step guides for setting up a terminal, selling, closing the day and fixing common problems — using the words you see on screen.",
  search: {
    label: "Search the help centre",
    placeholder: "Search: printer, refund, backup…",
    clear: "Clear search",
    none: (q) => `No article matches “${q}”.`,
  },
  topics: "Topics",
  onThisPage: "On this page",
  articles: (n) => (n === 1 ? "1 article" : `${n} articles`),
  note: "Good to know:",
  stuck: {
    h2: "Still stuck?",
    lede: "Send us the terminal’s name, what you were doing and the exact message on screen, and we will help you fix it.",
    cta: "Email support",
    cta2: "Book a demo",
  },
  sections: [
    {
      id: "getting-started",
      icon: "desktop",
      title: "Getting started",
      summary: "Take a new terminal from installation to its first sale.",
      articles: [
        {
          id: "register-terminal",
          title: "Register a new terminal",
          summary: "Each Windows till and Android tablet is linked to your company account once, the first time the app opens.",
          steps: [
            "Install Octopus POS on the terminal and open it.",
            "On [[Device Registration]], sign in with your company account’s email and password.",
            "Press [[LINK DEVICE]]. The terminal now uses one of your license’s device seats.",
          ],
          note: "Registration needs an internet connection. After that, the terminal keeps selling offline.",
          shot: {
            ...REGISTRATION,
            alt: "The Device Registration screen: email and password fields above the Link device button.",
            caption: "Device Registration, the first screen on a new terminal.",
          },
        },
        {
          id: "data-source",
          title: "Start fresh or take over from another terminal",
          summary: "The first set-up question decides where this terminal’s data comes from.",
          steps: [
            "Choose [[Sync with the cloud]] for a new terminal. You sign in and your company data downloads.",
            "Choose [[Restore from a backup]] when you replace a machine, and pick the old terminal’s .sqlite backup. It brings back work that never synced, with its settings, layout and theme.",
            "A restore restarts the app and skips the rest of set-up — the backup already carries it.",
          ],
          shot: {
            ...DATA_SOURCE,
            alt: "The data source screen: options to sync with the cloud or restore from a backup.",
            caption: "Choose your data source — shown here in French.",
          },
        },
        {
          id: "name-terminal",
          title: "Name the terminal and choose its look",
          summary: "A short, unique name, then the theme, colour and text size that suit your counter.",
          steps: [
            "In [[Set up your terminal]], type a short name — letters and digits only, such as CAISSE1.",
            "The name starts every document number the terminal issues (CAISSE1‑200‑000045), so two terminals never produce the same number. The server checks the name is free before you can continue.",
            "Pick light or dark, an accent colour and the text size. They apply straight away and can be changed later in [[Settings]].",
            "Switch on the on-screen keyboard if the terminal has no physical keyboard.",
          ],
          note: "If the name is taken, another terminal on your account already uses it: choose another name, or revoke that terminal under [[Active Devices]] first.",
          shot: {
            ...TERMINAL_SETUP,
            alt: "The terminal set-up screen, in French: device name, theme, accent colour, text size and on-screen keyboard.",
            caption: "Set up your terminal — shown here in French.",
          },
        },
        {
          id: "business-type",
          title: "Pick your business type and menu layout",
          summary: "Two last choices shape the sales screen.",
          steps: [
            "Choose the kind of business you run. Where it fits — a restaurant, for example — you can switch tables and bookings on or off.",
            "Choose how products appear on the sales screen: a scrolling list or pages of tiles. You can change it anytime in [[Settings]].",
            "Press [[Get Started]].",
          ],
          shot: {
            ...business_type,
            alt: "The business type screen, in French: options for restaurant, retail, etc.",
            caption: "Choose your business type — shown here in French.",
          },
        },
      ],
    },
    {
      id: "selling",
      icon: "receipt",
      title: "Selling at the till",
      summary: "The daily routine: sign in, open the register, sell, and close at the end of the day.",
      articles: [
        {
          id: "sign-in",
          title: "Sign in with your PIN",
          summary: "Everyone signs in with their own PIN, so each sale is recorded against the right name.",
          steps: ["Tap your name on the sign-in screen.", "Enter your PIN."],
          note: "A PIN belongs to one user on one terminal. What you can do once signed in depends on your role — see [[Security Rules]].",
          shot: {
            ...sign_in,
            alt: "The sign-in screen, in French: enter your name and PIN.",
            caption: "Sign in — shown here in French.",
          },
        },
        {
          id: "open-register",
          title: "Open the register",
          summary: "A session ties the day’s sales, payments and cash movements to one register.",
          steps: [
            "If the terminal asks, [[Choose register]]. [[This device only]] gives the terminal its own session; a named register such as “Front Till” is shared by every terminal pointed at it.",
            "In [[Opening Control]], count the cash float in the drawer and confirm it.",
            "The register is open. You can sell.",
          ],
          note: "Count the float carefully: the cash expected at closing is worked out from it.",
          shot: {
            ...open_register,
            alt: "The open register screen, in French: options to open the register.",
            caption: "Open the register — shown here in French.",
          },
        },
        {
          id: "make-sale",
          title: "Ring up a sale",
          summary: "Add products, adjust quantities, take the payment.",
          steps: [
            "Tap products on the sales screen, or scan their barcode.",
            "To change a quantity, open the quantity keypad. On a Windows till with a serial scale it shows the live weight — press [[Use weight]] once the reading is stable.",
            "Take the payment. The receipt prints if a receipt printer is set up.",
          ],
          shot: {
            ...make_sale,
            alt: "The sales screen, in French: options to add products and take payment.",
            caption: "Ring up a sale — shown here in French.",
          },
        },
        {
          id: "tables-orders",
          title: "Tables, open orders and bookings",
          summary: "For businesses that serve at the table.",
          steps: [
            "Open [[Floor Plan]], pick a table and add its order.",
            "Orders that are not paid yet wait in [[Open Orders]] until you come back to them.",
            "Reservations are managed in [[Bookings]].",
          ],
          note: "[[Floor Plan]] and [[Bookings]] only appear when they are switched on for your business.",
          shot: {
            ...floor_plan,
            alt: "The floor plan screen, in French: options to manage tables and orders.",
            caption: "Manage tables and orders — shown here in French.",
          },
        },
        {
          id: "refund",
          title: "Refund a sale",
          summary: "A refund always starts from the original sale.",
          steps: ["Open [[Sales history]] and find the sale.", "Choose [[Refund]] and follow the dialog."],
          note: "Refunds can be limited to admins in [[Security Rules]].",
          shot: {
            ...refund_dialog,
            alt: "The refund dialog, in French: options to process a refund.",
            caption: "Refund a sale — shown here in French.",
          }
        },
        {
          id: "cash-in-out",
          title: "Record cash in and out",
          summary: "Cash that enters or leaves the drawer outside a sale.",
          steps: [
            "Use [[Cash In / Out]] for change brought in, a supplier paid from the till, or cash taken to the bank.",
            "Each movement is added to the register’s expected cash, so the closing count still balances.",
          ],
          shot: {
            ...cash_in_out,
            alt: "The cash in/out screen, in French: options to record cash movements.",
            caption: "Record cash in and out — shown here in French.",
          },
        },
        {
          id: "close-register",
          title: "Close the register",
          summary: "Count the drawer, reconcile each payment method and issue the Z-report.",
          steps: [
            "Choose [[Close Register]] at the end of the day.",
            "Each payment method shows the amount expected. Count the cash in the drawer and enter it; confirm the card and other totals.",
            "Add a closing note if something does not match, then press [[Close Register]]. The session’s Z-report is generated.",
          ],
          note: "Selling stops the moment closing starts, so no sale can land between the count and the report.",
          shot: {
            ...closing_register,
            alt: "The closing register screen, in French: options to close the register.",
            caption: "Close the register — shown here in French.",
          },
        },
      ],
    },
    {
      id: "offline",
      icon: "sync",
      title: "Offline and sync",
      summary: "The terminal keeps selling without internet and catches up on its own.",
      articles: [
        {
          id: "selling-offline",
          title: "Keep selling when the connection drops",
          summary: "Nothing changes at the till.",
          steps: [
            "Sales, receipts and kitchen tickets keep working — they run on the terminal and your local network.",
            "Changes are saved on the terminal and marked [[Pending sync]].",
            "When the connection returns, they are sent automatically.",
          ],
          shot: {
            ...offline_pending_sync,
            alt: "The offline pending sync screen, in French: options to manage offline sales.",
            caption: "Manage offline sales — shown here in French.",
          },
        },
        {
          id: "sync-status",
          title: "Check what has synced",
          summary: "See what is still waiting to reach the server.",
          steps: [
            "Open the sync status panel from the sync button. It lists each kind of record, with what is pending and what is [[Synced]].",
            "Press [[Sync now]] to send everything straight away.",
          ],
          shot: {
            ...sync_status_panel,
            alt: "The sync status panel, in French: options to check sync status.",
            caption: "Check sync status — shown here in French.",
          },
        },
        {
          id: "backups",
          title: "Back up the terminal",
          summary: "Automatic backups protect work that has not synced yet.",
          steps: [
            "In [[Settings]], open [[Database & Backup]].",
            "Set [[Back up automatically every]] and choose where backups are saved. You can also back up each time the app starts or closes.",
            "A backup is a single .sqlite file. To move a terminal to new hardware, restore it during set-up.",
          ],
          shot: {
            ...database_backup_settings,
            alt: "The database backup settings screen, in French: options to configure automatic backups.",
            caption: "Configure database backups — shown here in French.",
          },
        },
      ],
    },
    {
      id: "management",
      icon: "dashboard",
      title: "Management",
      summary: "Catalogue, stock, customers and staff, from [[Management]] on the terminal.",
      articles: [
        {
          id: "products",
          title: "Products, categories and taxes",
          summary: "Build the catalogue the till sells from.",
          steps: [
            "In [[Management]], create your [[Categories]] and [[Taxes]] first.",
            "Add [[Products]] with a price, a category, a tax and, if they have one, a barcode.",
          ],
          shot: {
            ...product_editor,
            alt: "The product editor screen, in French: options to create and edit products.",
            caption: "Create and edit products — shown here in French.",
          }
        },
        {
          id: "stock",
          title: "Stock and warehouses",
          summary: "Track stock per warehouse.",
          steps: [
            "Create your [[Warehouses]].",
            "[[Stock]] lists every product in every warehouse. A product with no stock record in a warehouse shows as unassigned, with an option to add it.",
            "Items in one sale can come from different warehouses. If an item is out of stock, the app suggests warehouses that still have it.",
          ],
          shot: {
            ...stock_warehouses,
            alt: "The stock and warehouses screen, in French: options to manage stock and warehouses.",
            caption: "Manage stock and warehouses — shown here in French.",
          }
        },
        {
          id: "customers",
          title: "Customers, loyalty and promotions",
          summary: "Know your regulars and reward them.",
          steps: [
            "Keep customer records in [[Customers]] and attach a customer to a sale.",
            "Issue [[Loyalty Cards]] and set how customers earn points.",
            "Set up your offers in [[Promotions]].",
          ],
          shot: {
            ...customer_loyalty,
            alt: "The customer loyalty screen, in French: options to manage customer loyalty programs.",
            caption: "Manage customer loyalty — shown here in French.",
          }
        },
        {
          id: "users-security",
          title: "Users and security rules",
          summary: "Decide who can do what.",
          steps: [
            "Add staff in [[Users]]. An [[Admin]] can do everything; a [[Cashier]] can do what the security rules allow.",
            "In [[Security Rules]], set each action — refunds, opening the cash drawer, viewing cost prices — to [[Cashier]] or [[Admin]].",
            "Rules apply to the whole company, on every terminal.",
          ],
          shot: {
            ...security_rules,
            alt: "The security rules screen, in French: options to configure security settings.",
            caption: "Configure security rules — shown here in French.",
          }
        },
        {
          id: "reports",
          title: "Reports and sales history",
          summary: "See how the business is doing.",
          steps: [
            "[[Reports]] break sales down by product, customer and user.",
            "[[Sales history]] lists every sale. From there you can reprint a receipt or start a refund.",
          ],
          shot: {
            ...reports,
            alt: "The reports screen, in French: options to view sales reports.",
            caption: "View sales reports — shown here in French.",
          }
        },
      ],
    },
    {
      id: "hardware",
      icon: "hardware",
      title: "Printers and displays",
      summary: "Receipt printers, the kitchen display, the customer display and scales.",
      articles: [
        {
          id: "receipt-printer",
          title: "Set up a receipt printer",
          summary: "Windows printers and network printers.",
          steps: [
            "Open [[Printer settings]] and choose the printer you are setting up, such as the receipt printer.",
            "Under [[Connection]], choose [[This computer (Windows printer)]] for a printer installed in Windows, or [[Network printer (Wi-Fi / LAN)]] and enter its IP address and port — usually 9100.",
            "Set the [[Paper size]] to 58 mm or 80 mm and print a test page. It is a ruler across the full width: if it wraps, the paper size is wrong.",
          ],
          note: "Android tablets print through a network printer. The connection is saved per terminal, so a Windows till and a tablet can reach the same printer in different ways.",
        },
        {
          id: "kitchen-display",
          title: "Send orders to the kitchen display",
          summary: "Tickets on a screen in the kitchen instead of paper.",
          steps: [
            "Install the Octopus kitchen display app on the kitchen screen, on the same local network as your tills.",
            "On each till, open [[Settings]], then [[Kitchen Display]], and add the kitchen screen’s [[KDS IP address]].",
            "Orders sent from the till appear in the kitchen straight away.",
          ],
          note: "The till and the kitchen talk over your local network, so this keeps working without internet.",
          shot: {
            ...kitchen_display_settings,
            alt: "The kitchen display settings screen, in French: options to configure the kitchen display.",
            caption: "Configure the kitchen display — shown here in French.",
          }
        },
        {
          id: "customer-display",
          title: "Show the order to your customer",
          summary: "A second screen that mirrors the cart as you sell.",
          steps: [
            "In [[Settings]], turn on the [[Customer display]].",
            "Scan the QR code shown there to open the customer display on another device, such as a tablet facing the customer.",
            "The customer sees each item and the total as you add them.",
          ],
          shot: {
            ...customer_display_qr,
            alt: "The customer display QR code screen, in French: options to open the customer display.",
            caption: "Open the customer display — shown here in French.",
          }
        },
        {
          id: "scales",
          title: "Weighing scales",
          summary: "Barcode scales and serial scales work differently.",
          steps: [
            "Barcode scales: items weighed and labelled on the scale are scanned like any other barcode, on Windows and Android.",
            "Serial scales (Windows only): in [[Settings]], open [[Weighing Scale]], choose the COM port and speed, and check the live reading before you sell.",
            "At the till, the quantity keypad shows the live weight. [[Use weight]] becomes available once the reading is stable.",
          ],
          shot: {
            ...weighing_scale_settings,
            alt: "The weighing scale settings screen, in French: options to configure the weighing scale.",
            caption: "Configure the weighing scale — shown here in French.",
          }
        },
      ],
    },
    {
      id: "troubleshooting",
      icon: "lifebuoy",
      title: "Troubleshooting",
      summary: "Quick fixes for the problems that come up most.",
      faq: true,
      articles: [
        {
          id: "printer-unreachable",
          title: "The printer prints nothing",
          summary: "The error message tells you which address the terminal tried.",
          steps: [
            "The error names the address and port the terminal could not reach, for example 192.168.1.50:9100.",
            "Check the printer is switched on and on the same network, and that its IP address and port match [[Printer settings]].",
            "Type the IP address on its own — no “http://” and no port, which has its own field — then print a test page.",
          ],
        },
        {
          id: "not-syncing",
          title: "Sales are not reaching the back office",
          summary: "They are waiting on the terminal.",
          steps: [
            "Open the sync status panel and look for records marked [[Pending sync]].",
            "“Could not reach the server” means the terminal has no internet. Reconnect it, then press [[Sync now]].",
          ],
        },
        {
          id: "name-taken",
          title: "The terminal name is already used",
          summary: "A name can belong to only one terminal on your account.",
          steps: [
            "Choose another name.",
            "Or, if the old terminal is gone for good, revoke it under [[Active Devices]] and use the name again.",
          ],
        },
        {
          id: "subscription",
          title: "“Subscription inactive” blocks the till",
          summary: "The terminal could not confirm your license for too long.",
          steps: [
            "Connect the terminal to the internet so it can refresh its license.",
            "If [[Subscription inactive]] stays on screen, contact us.",
          ],
          shot: {
            ...subscription_inactive,
            alt: "The subscription inactive screen, in French: indicates the terminal cannot confirm its license.",
            caption: "Subscription inactive — shown here in French.",
          }
        },
        {
          id: "switch-register",
          title: "The terminal will not switch register",
          summary: "The current register still has an open session.",
          steps: [
            "Close this register’s session first.",
            "Switching with a session open would leave that register open, with no way back to it from this terminal.",
          ],
        },
        {
          id: "cashier-refused",
          title: "A cashier is refused an action",
          summary: "The action is reserved for admins.",
          steps: [
            "In [[Security Rules]], the action is set to [[Admin]].",
            "Ask an admin to do it, or change the rule to [[Cashier]] for the whole company.",
          ],
          shot: {
            ...cashier_refused,
            alt: "The cashier refused screen, in French: indicates the user is not an admin.",
            caption: "Cashier refused — shown here in French.",
          }
        },
      ],
    },
  ],
};

/* -------------------------------------------------------------------------- */

const fr: HelpDict = {
  eyebrow: "Centre d’aide",
  h1: "Tout ce qu’il faut pour faire tourner la caisse.",
  lede: "Des guides pas à pas pour installer un terminal, vendre, clôturer la journée et régler les problèmes courants — avec les mots que vous voyez à l’écran.",
  search: {
    label: "Rechercher dans le centre d’aide",
    placeholder: "Rechercher : imprimante, remboursement, sauvegarde…",
    clear: "Effacer la recherche",
    none: (q) => `Aucun article ne correspond à « ${q} ».`,
  },
  topics: "Rubriques",
  onThisPage: "Sur cette page",
  articles: (n) => (n === 1 ? "1 article" : `${n} articles`),
  note: "Bon à savoir :",
  stuck: {
    h2: "Toujours bloqué ?",
    lede: "Envoyez-nous le nom du terminal, ce que vous faisiez et le message exact affiché à l’écran : nous vous aiderons à régler le problème.",
    cta: "Écrire au support",
    cta2: "Réserver une démo",
  },
  sections: [
    {
      id: "getting-started",
      icon: "desktop",
      title: "Premiers pas",
      summary: "Du premier lancement d’un nouveau terminal à sa première vente.",
      articles: [
        {
          id: "register-terminal",
          title: "Enregistrer un nouveau terminal",
          summary: "Chaque caisse Windows et chaque tablette Android est liée une seule fois au compte de votre entreprise, au premier lancement.",
          steps: [
            "Installez Octopus POS sur le terminal et ouvrez-le.",
            "Sur [[Enregistrement de l'appareil]], connectez-vous avec l’e-mail et le mot de passe du compte de votre entreprise.",
            "Appuyez sur [[ASSOCIER L'APPAREIL]]. Le terminal occupe désormais l’un des postes de votre licence.",
          ],
          note: "L’enregistrement demande une connexion Internet. Ensuite, le terminal continue de vendre hors ligne.",
          shot: {
            ...REGISTRATION,
            alt: "L’écran d’enregistrement de l’appareil, en anglais : champs e-mail et mot de passe au-dessus du bouton d’association.",
            caption: "Enregistrement de l’appareil — affiché ici en anglais.",
          },
        },
        {
          id: "data-source",
          title: "Repartir de zéro ou reprendre un autre terminal",
          summary: "La première question de la configuration décide d’où viennent les données du terminal.",
          steps: [
            "Choisissez [[Synchroniser avec le cloud]] pour un nouveau terminal : vous vous connectez et les données de l’entreprise se téléchargent.",
            "Choisissez [[Restaurer une sauvegarde]] pour remplacer une machine, puis la sauvegarde .sqlite de l’ancien terminal. Elle ramène le travail jamais synchronisé, avec ses réglages, sa disposition et son thème.",
            "La restauration redémarre l’application et saute le reste de la configuration : la sauvegarde la contient déjà.",
          ],
        },
        {
          id: "name-terminal",
          title: "Nommer le terminal et choisir son apparence",
          summary: "Un nom court et unique, puis le thème, la couleur et la taille du texte adaptés à votre comptoir.",
          steps: [
            "Dans [[Configurez votre terminal]], saisissez un nom court — lettres et chiffres uniquement, par exemple CAISSE1.",
            "Ce nom préfixe chaque numéro de document émis par le terminal (CAISSE1‑200‑000045) : deux terminaux ne produisent jamais le même numéro. Le serveur vérifie que le nom est libre avant de continuer.",
            "Choisissez clair ou sombre, une couleur d’accent et la taille du texte. Tout s’applique immédiatement et reste modifiable dans les [[Paramètres]].",
            "Activez le clavier à l’écran si le terminal n’a pas de clavier physique.",
          ],
          note: "Si le nom est pris, un autre terminal de votre compte l’utilise : choisissez-en un autre, ou révoquez d’abord ce terminal dans [[Appareils actifs]].",
          shot: {
            ...TERMINAL_SETUP,
            alt: "L’écran Configurez votre terminal : nom de l’appareil, thème, couleur d’accent, taille du texte et clavier à l’écran.",
            caption: "Configurez votre terminal, le premier écran de réglages.",
          },
        },
        {
          id: "business-type",
          title: "Choisir votre activité et l’affichage du menu",
          summary: "Deux derniers choix qui façonnent l’écran de vente.",
          steps: [
            "Choisissez votre type d’activité. Quand c’est pertinent — un restaurant, par exemple — vous pouvez activer ou non les tables et les réservations.",
            "Choisissez l’affichage des produits sur l’écran de vente : une liste qui défile ou des pages de tuiles. Modifiable à tout moment dans les [[Paramètres]].",
            "Appuyez sur [[Commencer]].",
          ],
        },
      ],
    },
    {
      id: "selling",
      icon: "receipt",
      title: "Vendre en caisse",
      summary: "La routine du jour : se connecter, ouvrir la caisse, vendre, puis clôturer le soir.",
      articles: [
        {
          id: "sign-in",
          title: "Se connecter avec son PIN",
          summary: "Chacun se connecte avec son propre PIN, pour que chaque vente soit enregistrée au bon nom.",
          steps: ["Touchez votre nom sur l’écran de connexion.", "Saisissez votre PIN."],
          note: "Un PIN appartient à un utilisateur sur un terminal. Ce que vous pouvez faire ensuite dépend de votre rôle — voir les [[Règles de sécurité]].",
        },
        {
          id: "open-register",
          title: "Ouvrir la caisse",
          summary: "Une session rattache les ventes, les paiements et les mouvements d’espèces de la journée à une caisse.",
          steps: [
            "Si le terminal le demande, [[Choisir la caisse]]. [[Cet appareil uniquement]] donne au terminal sa propre session ; une caisse nommée, comme « Caisse principale », est partagée par tous les terminaux qui l’utilisent.",
            "Dans [[Contrôle d'ouverture]], comptez le fond de caisse et confirmez-le.",
            "La caisse est ouverte : vous pouvez vendre.",
          ],
          note: "Comptez le fond de caisse avec soin : les espèces attendues à la clôture sont calculées à partir de lui.",
        },
        {
          id: "make-sale",
          title: "Enregistrer une vente",
          summary: "Ajouter des produits, ajuster les quantités, encaisser.",
          steps: [
            "Touchez les produits sur l’écran de vente, ou scannez leur code-barres.",
            "Pour changer une quantité, ouvrez le pavé de quantité. Sur une caisse Windows reliée à une balance série, il affiche le poids en direct : appuyez sur [[Utiliser le poids]] une fois la lecture stable.",
            "Encaissez le paiement. Le ticket s’imprime si une imprimante de tickets est configurée.",
          ],
        },
        {
          id: "tables-orders",
          title: "Tables, commandes ouvertes et réservations",
          summary: "Pour les établissements qui servent à table.",
          steps: [
            "Ouvrez le [[Plan de salle]], choisissez une table et ajoutez sa commande.",
            "Les commandes pas encore payées attendent dans [[Commandes ouvertes]] jusqu’à ce que vous y reveniez.",
            "Les réservations se gèrent dans [[Réservations]].",
          ],
          note: "[[Plan de salle]] et [[Réservations]] n’apparaissent que s’ils sont activés pour votre activité.",
        },
        {
          id: "refund",
          title: "Rembourser une vente",
          summary: "Un remboursement part toujours de la vente d’origine.",
          steps: ["Ouvrez l’[[Historique des ventes]] et retrouvez la vente.", "Choisissez [[Remboursement]] et suivez la boîte de dialogue."],
          note: "Les remboursements peuvent être réservés aux administrateurs dans les [[Règles de sécurité]].",
        },
        {
          id: "cash-in-out",
          title: "Enregistrer les entrées et sorties d’espèces",
          summary: "Les espèces qui entrent ou sortent du tiroir en dehors d’une vente.",
          steps: [
            "Utilisez [[Entrées / sorties de caisse]] pour de la monnaie apportée, un fournisseur payé depuis la caisse ou un dépôt en banque.",
            "Chaque mouvement s’ajoute aux espèces attendues de la caisse, pour que le comptage de clôture tombe juste.",
          ],
        },
        {
          id: "close-register",
          title: "Clôturer la caisse",
          summary: "Compter le tiroir, rapprocher chaque moyen de paiement et éditer le rapport Z.",
          steps: [
            "Choisissez [[Clôturer la caisse]] en fin de journée.",
            "Chaque moyen de paiement affiche le montant attendu. Comptez les espèces du tiroir et saisissez-les ; confirmez les totaux carte et autres.",
            "Ajoutez une note de clôture si quelque chose ne correspond pas, puis appuyez sur [[Clôturer la caisse]]. Le rapport Z de la session est généré.",
          ],
          note: "La vente s’arrête dès le début de la clôture : aucune vente ne peut se glisser entre le comptage et le rapport.",
        },
      ],
    },
    {
      id: "offline",
      icon: "sync",
      title: "Hors ligne et synchronisation",
      summary: "Le terminal continue de vendre sans Internet et rattrape son retard tout seul.",
      articles: [
        {
          id: "selling-offline",
          title: "Continuer à vendre quand la connexion tombe",
          summary: "Rien ne change en caisse.",
          steps: [
            "Ventes, tickets et bons de cuisine continuent de fonctionner : ils tournent sur le terminal et votre réseau local.",
            "Les modifications sont enregistrées sur le terminal et marquées [[Synchronisation en attente]].",
            "Au retour de la connexion, elles sont envoyées automatiquement.",
          ],
        },
        {
          id: "sync-status",
          title: "Vérifier ce qui est synchronisé",
          summary: "Voir ce qui attend encore d’atteindre le serveur.",
          steps: [
            "Ouvrez le panneau d’état de la synchronisation depuis le bouton de synchronisation. Il indique, pour chaque type de données, ce qui est en attente et ce qui est [[Synchronisé]].",
            "Appuyez sur [[Synchroniser maintenant]] pour tout envoyer tout de suite.",
          ],
        },
        {
          id: "backups",
          title: "Sauvegarder le terminal",
          summary: "Les sauvegardes automatiques protègent le travail pas encore synchronisé.",
          steps: [
            "Dans les [[Paramètres]], ouvrez [[Base de données et sauvegarde]].",
            "Réglez [[Sauvegarder automatiquement tous les]] et choisissez où enregistrer les sauvegardes. Vous pouvez aussi sauvegarder à chaque ouverture ou fermeture de l’application.",
            "Une sauvegarde est un seul fichier .sqlite. Pour passer un terminal sur un nouveau matériel, restaurez-la pendant la configuration.",
          ],
        },
      ],
    },
    {
      id: "management",
      icon: "dashboard",
      title: "Gestion",
      summary: "Catalogue, stock, clients et équipe, depuis [[Gestion]] sur le terminal.",
      articles: [
        {
          id: "products",
          title: "Produits, catégories et taxes",
          summary: "Construire le catalogue que la caisse vend.",
          steps: [
            "Dans [[Gestion]], créez d’abord vos [[Catégories]] et vos [[Taxes]].",
            "Ajoutez les [[Produits]] avec un prix, une catégorie, une taxe et, s’ils en ont un, un code-barres.",
          ],
        },
        {
          id: "stock",
          title: "Stock et entrepôts",
          summary: "Suivre le stock par entrepôt.",
          steps: [
            "Créez vos [[Entrepôts]].",
            "[[Stock]] liste tous les produits dans tous les entrepôts. Un produit sans fiche de stock dans un entrepôt apparaît comme non assigné, avec une option pour l’ajouter.",
            "Les articles d’une même vente peuvent venir d’entrepôts différents. Si un article est en rupture, l’application propose les entrepôts qui en ont encore.",
          ],
        },
        {
          id: "customers",
          title: "Clients, fidélité et promotions",
          summary: "Connaître vos habitués et les récompenser.",
          steps: [
            "Tenez vos fiches dans [[Clients]] et associez un client à une vente.",
            "Émettez des [[Cartes de fidélité]] et réglez la façon dont les clients gagnent des points.",
            "Créez vos offres dans [[Promotions]].",
          ],
        },
        {
          id: "users-security",
          title: "Utilisateurs et règles de sécurité",
          summary: "Décider qui peut faire quoi.",
          steps: [
            "Ajoutez l’équipe dans [[Utilisateurs]]. Un [[Administrateur]] peut tout faire ; un [[Caissier]] peut faire ce que les règles de sécurité autorisent.",
            "Dans [[Règles de sécurité]], réglez chaque action — rembourser, ouvrir le tiroir-caisse, voir les prix de revient — sur [[Caissier]] ou [[Administrateur]].",
            "Les règles s’appliquent à toute l’entreprise, sur chaque terminal.",
          ],
        },
        {
          id: "reports",
          title: "Rapports et historique des ventes",
          summary: "Voir comment se porte l’activité.",
          steps: [
            "Les [[Rapports]] détaillent les ventes par produit, par client et par utilisateur.",
            "L’[[Historique des ventes]] liste chaque vente. De là, vous pouvez réimprimer un ticket ou lancer un remboursement.",
          ],
        },
      ],
    },
    {
      id: "hardware",
      icon: "hardware",
      title: "Imprimantes et écrans",
      summary: "Imprimantes de tickets, écran de cuisine, afficheur client et balances.",
      articles: [
        {
          id: "receipt-printer",
          title: "Configurer une imprimante de tickets",
          summary: "Imprimantes Windows et imprimantes réseau.",
          steps: [
            "Ouvrez les [[Paramètres d'imprimante]] et choisissez l’imprimante à configurer, par exemple celle des tickets.",
            "Sous [[Connexion]], choisissez [[Cet ordinateur (imprimante Windows)]] pour une imprimante installée dans Windows, ou [[Imprimante réseau (Wi-Fi / LAN)]] et saisissez son adresse IP et son port — généralement 9100.",
            "Réglez la [[Taille du papier]] sur 58 mm ou 80 mm et imprimez une page de test. C’est une règle sur toute la largeur : si elle passe à la ligne, la taille du papier est fausse.",
          ],
          note: "Les tablettes Android impriment via une imprimante réseau. La connexion est enregistrée par terminal : une caisse Windows et une tablette peuvent joindre la même imprimante de deux façons différentes.",
        },
        {
          id: "kitchen-display",
          title: "Envoyer les commandes à l’écran de cuisine",
          summary: "Des bons sur un écran en cuisine plutôt que sur papier.",
          steps: [
            "Installez l’application écran de cuisine Octopus sur l’écran de la cuisine, sur le même réseau local que vos caisses.",
            "Sur chaque caisse, ouvrez les [[Paramètres]], puis [[Écran de cuisine]], et ajoutez l’[[Adresse IP du KDS]] de l’écran de cuisine.",
            "Les commandes envoyées depuis la caisse s’affichent aussitôt en cuisine.",
          ],
          note: "La caisse et la cuisine communiquent par votre réseau local : cela continue de fonctionner sans Internet.",
        },
        {
          id: "customer-display",
          title: "Montrer la commande au client",
          summary: "Un second écran qui reflète le panier pendant la vente.",
          steps: [
            "Dans les [[Paramètres]], activez l’[[Afficheur client]].",
            "Scannez le code QR affiché pour ouvrir l’afficheur client sur un autre appareil, par exemple une tablette tournée vers le client.",
            "Le client voit chaque article et le total au fur et à mesure.",
          ],
        },
        {
          id: "scales",
          title: "Balances",
          summary: "Les balances à code-barres et les balances série fonctionnent différemment.",
          steps: [
            "Balances à code-barres : les articles pesés et étiquetés sur la balance se scannent comme n’importe quel code-barres, sur Windows et Android.",
            "Balances série (Windows uniquement) : dans les [[Paramètres]], ouvrez [[Balance]], choisissez le port COM et la vitesse, et vérifiez la lecture en direct avant de vendre.",
            "En caisse, le pavé de quantité affiche le poids en direct. [[Utiliser le poids]] devient disponible une fois la lecture stable.",
          ],
        },
      ],
    },
    {
      id: "troubleshooting",
      icon: "lifebuoy",
      title: "Dépannage",
      summary: "Des solutions rapides aux problèmes les plus fréquents.",
      faq: true,
      articles: [
        {
          id: "printer-unreachable",
          title: "L’imprimante n’imprime rien",
          summary: "Le message d’erreur indique l’adresse que le terminal a essayée.",
          steps: [
            "L’erreur indique l’adresse et le port que le terminal n’a pas pu joindre, par exemple 192.168.1.50:9100.",
            "Vérifiez que l’imprimante est allumée et sur le même réseau, et que son adresse IP et son port correspondent aux [[Paramètres d'imprimante]].",
            "Saisissez l’adresse IP seule — sans « http:// » ni port, qui a son propre champ — puis imprimez une page de test.",
          ],
        },
        {
          id: "not-syncing",
          title: "Les ventes n’arrivent pas au back-office",
          summary: "Elles attendent sur le terminal.",
          steps: [
            "Ouvrez le panneau d’état de la synchronisation et cherchez les éléments marqués [[Synchronisation en attente]].",
            "« Impossible de joindre le serveur » signifie que le terminal n’a pas Internet. Reconnectez-le, puis appuyez sur [[Synchroniser maintenant]].",
          ],
        },
        {
          id: "name-taken",
          title: "Le nom du terminal est déjà utilisé",
          summary: "Un nom ne peut appartenir qu’à un seul terminal de votre compte.",
          steps: [
            "Choisissez un autre nom.",
            "Ou, si l’ancien terminal n’existe plus, révoquez-le dans [[Appareils actifs]] et réutilisez le nom.",
          ],
        },
        {
          id: "subscription",
          title: "« Abonnement inactif » bloque la caisse",
          summary: "Le terminal n’a pas pu confirmer votre licence depuis trop longtemps.",
          steps: [
            "Connectez le terminal à Internet pour qu’il actualise sa licence.",
            "Si [[Abonnement inactif]] reste affiché, contactez-nous.",
          ],
        },
        {
          id: "switch-register",
          title: "Le terminal refuse de changer de caisse",
          summary: "La caisse actuelle a encore une session ouverte.",
          steps: [
            "Fermez d’abord la session de cette caisse.",
            "Changer avec une session ouverte la laisserait ouverte, sans moyen d’y revenir depuis ce terminal.",
          ],
        },
        {
          id: "cashier-refused",
          title: "Un caissier se voit refuser une action",
          summary: "L’action est réservée aux administrateurs.",
          steps: [
            "Dans les [[Règles de sécurité]], l’action est réglée sur [[Administrateur]].",
            "Demandez à un administrateur de la faire, ou réglez la règle sur [[Caissier]] pour toute l’entreprise.",
          ],
        },
      ],
    },
  ],
};

/* -------------------------------------------------------------------------- */

const ar: HelpDict = {
  eyebrow: "مركز المساعدة",
  h1: "كل ما تحتاجه لتشغيل الصندوق.",
  lede: "أدلة خطوة بخطوة لإعداد الجهاز والبيع وإغلاق اليوم وحل المشكلات الشائعة — بالكلمات نفسها التي تراها على الشاشة.",
  search: {
    label: "ابحث في مركز المساعدة",
    placeholder: "ابحث: طابعة، استرجاع، نسخة احتياطية…",
    clear: "مسح البحث",
    none: (q) => `لا توجد مقالات تطابق «${q}».`,
  },
  topics: "المواضيع",
  onThisPage: "في هذه الصفحة",
  articles: (n) => (n === 1 ? "مقال واحد" : n === 2 ? "مقالان" : n <= 10 ? `${n} مقالات` : `${n} مقالًا`),
  note: "معلومة مفيدة:",
  stuck: {
    h2: "ما زلت تواجه مشكلة؟",
    lede: "أرسل إلينا اسم الجهاز وما كنت تفعله والرسالة الظاهرة على الشاشة بالضبط، وسنساعدك على حلها.",
    cta: "راسل الدعم",
    cta2: "احجز عرضًا",
  },
  sections: [
    {
      id: "getting-started",
      icon: "desktop",
      title: "البدء",
      summary: "من تثبيت جهاز جديد حتى أول عملية بيع.",
      articles: [
        {
          id: "register-terminal",
          title: "تسجيل جهاز جديد",
          summary: "يُربط كل صندوق Windows وكل جهاز لوحي Android بحساب شركتك مرة واحدة، عند فتح التطبيق لأول مرة.",
          steps: [
            "ثبّت Octopus POS على الجهاز وافتحه.",
            "في شاشة [[تسجيل الجهاز]]، سجّل الدخول بالبريد الإلكتروني وكلمة المرور لحساب شركتك.",
            "اضغط [[ربط الجهاز]]. أصبح الجهاز يشغل أحد مقاعد الأجهزة في ترخيصك.",
          ],
          note: "يتطلب التسجيل اتصالًا بالإنترنت. بعد ذلك يواصل الجهاز البيع دون اتصال.",
          shot: {
            ...REGISTRATION,
            alt: "شاشة تسجيل الجهاز بالإنجليزية: حقلا البريد الإلكتروني وكلمة المرور فوق زر ربط الجهاز.",
            caption: "تسجيل الجهاز — معروضة هنا بالإنجليزية.",
          },
        },
        {
          id: "data-source",
          title: "البدء من جديد أو استلام بيانات جهاز آخر",
          summary: "أول سؤال في الإعداد يحدد مصدر بيانات هذا الجهاز.",
          steps: [
            "اختر [[المزامنة مع السحابة]] لجهاز جديد: تسجّل الدخول فتُنزَّل بيانات شركتك.",
            "اختر [[استعادة من نسخة]] عند استبدال جهاز، ثم اختر نسخة .sqlite من الجهاز القديم. تعيد النسخة العمل الذي لم تتم مزامنته، مع إعداداته وتخطيطه وسمته.",
            "تعيد الاستعادة تشغيل التطبيق وتتخطى بقية الإعداد، لأن النسخة تحمله بالفعل.",
          ],
        },
        {
          id: "name-terminal",
          title: "تسمية الجهاز واختيار مظهره",
          summary: "اسم قصير وفريد، ثم السمة واللون وحجم النص المناسبة لمكان عملك.",
          steps: [
            "في [[قم بإعداد جهازك]]، اكتب اسمًا قصيرًا — حروفًا وأرقامًا فقط، مثل CAISSE1.",
            // U+2066/U+2069 isolate the Latin document number, or the bidi algorithm
            // flips the parentheses around it into the Arabic run.
            "يصبح الاسم بادئة كل رقم مستند يصدره الجهاز (⁦CAISSE1‑200‑000045⁩)، فلا ينتج جهازان الرقم نفسه أبدًا. يتحقق الخادم من أن الاسم متاح قبل المتابعة.",
            "اختر الوضع الفاتح أو الداكن ولون التمييز وحجم النص. تُطبَّق فورًا ويمكن تغييرها لاحقًا من [[الإعدادات]].",
            "فعّل لوحة المفاتيح على الشاشة إذا لم يكن للجهاز لوحة مفاتيح فعلية.",
          ],
          note: "إذا كان الاسم مستخدمًا، فهناك جهاز آخر في حسابك يحمله: اختر اسمًا آخر، أو ألغِ ذلك الجهاز أولًا من [[الأجهزة النشطة]].",
          shot: {
            ...TERMINAL_SETUP,
            alt: "شاشة إعداد الجهاز بالفرنسية: اسم الجهاز والسمة ولون التمييز وحجم النص ولوحة المفاتيح على الشاشة.",
            caption: "قم بإعداد جهازك — معروضة هنا بالفرنسية.",
          },
        },
        {
          id: "business-type",
          title: "اختيار نوع النشاط وطريقة عرض القائمة",
          summary: "خياران أخيران يحددان شكل شاشة البيع.",
          steps: [
            "اختر نوع نشاطك التجاري. عندما يناسب ذلك — كالمطعم مثلًا — يمكنك تفعيل الطاولات والحجوزات أو إيقافها.",
            "اختر طريقة ظهور المنتجات في شاشة البيع: قائمة متصلة أو صفحات من المربعات. يمكنك تغييرها في أي وقت من [[الإعدادات]].",
            "اضغط [[ابدأ الآن]].",
          ],
        },
      ],
    },
    {
      id: "selling",
      icon: "receipt",
      title: "البيع على الصندوق",
      summary: "روتين اليوم: تسجيل الدخول، فتح الصندوق، البيع، ثم الإغلاق في نهاية اليوم.",
      articles: [
        {
          id: "sign-in",
          title: "تسجيل الدخول بالرمز السري",
          summary: "يسجّل كل شخص دخوله برمزه الخاص، فتُسجَّل كل عملية بيع باسم صاحبها.",
          steps: ["المس اسمك في شاشة تسجيل الدخول.", "أدخل رمزك السري."],
          note: "الرمز السري خاص بمستخدم واحد على جهاز واحد. ما يمكنك فعله بعد الدخول يعتمد على دورك — راجع [[قواعد الأمان]].",
        },
        {
          id: "open-register",
          title: "فتح الصندوق",
          summary: "تربط الجلسة مبيعات اليوم ومدفوعاته وحركات نقده بصندوق واحد.",
          steps: [
            "إذا طلب الجهاز ذلك، استخدم [[اختيار الصندوق]]. يمنح [[هذا الجهاز فقط]] الجهاز جلسة خاصة به، أما الصندوق المسمّى مثل «الصندوق الأمامي» فتتشاركه كل الأجهزة الموجّهة إليه.",
            "في [[مراقبة الافتتاح]]، عُدّ النقد الافتتاحي في الدرج وأكّده.",
            "أصبح الصندوق مفتوحًا ويمكنك البيع.",
          ],
          note: "عُدّ النقد الافتتاحي بعناية: النقد المتوقع عند الإغلاق يُحسب انطلاقًا منه.",
        },
        {
          id: "make-sale",
          title: "تسجيل عملية بيع",
          summary: "أضف المنتجات، وعدّل الكميات، واستلم الدفع.",
          steps: [
            "المس المنتجات في شاشة البيع، أو امسح رمزها الشريطي.",
            "لتغيير الكمية، افتح لوحة الكمية. على صندوق Windows متصل بميزان تسلسلي تعرض اللوحة الوزن مباشرة — اضغط [[استخدام الوزن]] عندما تستقر القراءة.",
            "استلم الدفع. يُطبع الإيصال إذا كانت طابعة الإيصالات مُعدّة.",
          ],
        },
        {
          id: "tables-orders",
          title: "الطاولات والطلبات المفتوحة والحجوزات",
          summary: "للمحلات التي تقدّم الخدمة على الطاولات.",
          steps: [
            "افتح [[مخطط القاعة]]، واختر طاولة، وأضف طلبها.",
            "تبقى الطلبات غير المدفوعة في [[الطلبات المفتوحة]] حتى تعود إليها.",
            "تُدار الحجوزات من [[الحجوزات]].",
          ],
          note: "لا يظهر [[مخطط القاعة]] و[[الحجوزات]] إلا إذا كانا مفعّلين لنشاطك.",
        },
        {
          id: "refund",
          title: "استرجاع عملية بيع",
          summary: "يبدأ الاسترجاع دائمًا من عملية البيع الأصلية.",
          steps: ["افتح [[سجل المبيعات]] وابحث عن عملية البيع.", "اختر [[استرجاع]] واتبع خطوات النافذة."],
          note: "يمكن قصر الاسترجاع على المديرين من [[قواعد الأمان]].",
        },
        {
          id: "cash-in-out",
          title: "تسجيل إدخال النقد وإخراجه",
          summary: "النقد الذي يدخل الدرج أو يخرج منه خارج عمليات البيع.",
          steps: [
            "استخدم [[إدخال / إخراج النقد]] للفكة التي تُحضَر، أو لدفع مورّد من الصندوق، أو لإيداع النقد في البنك.",
            "تُضاف كل حركة إلى النقد المتوقع للصندوق، ليبقى عدّ الإغلاق متوازنًا.",
          ],
        },
        {
          id: "close-register",
          title: "إغلاق الصندوق",
          summary: "عُدّ الدرج، وطابِق كل طريقة دفع، وأصدر تقرير Z.",
          steps: [
            "اختر [[إغلاق الصندوق]] في نهاية اليوم.",
            "تعرض كل طريقة دفع المبلغ المتوقع. عُدّ النقد في الدرج وأدخله، وأكّد مبالغ البطاقات وغيرها.",
            "أضف ملاحظة إغلاق إذا لم يتطابق شيء، ثم اضغط [[إغلاق الصندوق]]. يُنشأ تقرير Z للجلسة.",
          ],
          note: "يتوقف البيع بمجرد بدء الإغلاق، فلا يمكن أن تتسلل عملية بيع بين العدّ والتقرير.",
        },
      ],
    },
    {
      id: "offline",
      icon: "sync",
      title: "العمل دون اتصال والمزامنة",
      summary: "يواصل الجهاز البيع دون إنترنت ويلحق بما فاته تلقائيًا.",
      articles: [
        {
          id: "selling-offline",
          title: "واصل البيع عند انقطاع الاتصال",
          summary: "لا شيء يتغير على الصندوق.",
          steps: [
            "تستمر المبيعات والإيصالات وتذاكر المطبخ في العمل — فهي تعمل على الجهاز وشبكتك المحلية.",
            "تُحفظ التغييرات على الجهاز ويُشار إليها بـ [[بانتظار المزامنة]].",
            "عند عودة الاتصال تُرسَل تلقائيًا.",
          ],
        },
        {
          id: "sync-status",
          title: "تحقق مما تمت مزامنته",
          summary: "اعرف ما الذي ما زال ينتظر الوصول إلى الخادم.",
          steps: [
            "افتح لوحة حالة المزامنة من زر المزامنة. تعرض لكل نوع من البيانات ما هو معلّق وما [[تمت المزامنة]].",
            "اضغط [[المزامنة الآن]] لإرسال كل شيء فورًا.",
          ],
        },
        {
          id: "backups",
          title: "النسخ الاحتياطي للجهاز",
          summary: "تحمي النسخ الاحتياطية التلقائية العمل الذي لم تتم مزامنته بعد.",
          steps: [
            "في [[الإعدادات]]، افتح [[قاعدة البيانات والنسخ الاحتياطي]].",
            "اضبط [[النسخ الاحتياطي التلقائي كل]] واختر مكان حفظ النسخ. يمكنك أيضًا النسخ عند كل تشغيل للتطبيق أو إغلاقه.",
            "النسخة الاحتياطية ملف .sqlite واحد. لنقل جهاز إلى عتاد جديد، استعِدها أثناء الإعداد.",
          ],
        },
      ],
    },
    {
      id: "management",
      icon: "dashboard",
      title: "الإدارة",
      summary: "الكتالوج والمخزون والعملاء والموظفون، من [[الإدارة]] على الجهاز.",
      articles: [
        {
          id: "products",
          title: "المنتجات والفئات والضرائب",
          summary: "ابنِ الكتالوج الذي يبيع منه الصندوق.",
          steps: [
            "في [[الإدارة]]، أنشئ [[الفئات]] و[[الضرائب]] أولًا.",
            "أضف [[المنتجات]] بسعر وفئة وضريبة، ورمز شريطي إن وُجد.",
          ],
        },
        {
          id: "stock",
          title: "المخزون والمستودعات",
          summary: "تتبّع المخزون لكل مستودع.",
          steps: [
            "أنشئ [[المستودعات]].",
            "يعرض [[المخزون]] كل المنتجات في كل المستودعات. المنتج الذي لا يملك سجل مخزون في مستودع يظهر كغير مُسنَد، مع خيار لإضافته.",
            "يمكن أن تأتي عناصر عملية البيع الواحدة من مستودعات مختلفة. وإذا نفد عنصر، يقترح التطبيق مستودعات ما زال متوفرًا فيها.",
          ],
        },
        {
          id: "customers",
          title: "العملاء والولاء والعروض",
          summary: "اعرف زبائنك الدائمين وكافئهم.",
          steps: [
            "احتفظ بسجلات العملاء في [[العملاء]] واربط عميلًا بعملية البيع.",
            "أصدر [[بطاقات الولاء]] واضبط طريقة كسب العملاء للنقاط.",
            "أنشئ عروضك من [[العروض]].",
          ],
        },
        {
          id: "users-security",
          title: "المستخدمون وقواعد الأمان",
          summary: "حدّد من يمكنه فعل ماذا.",
          steps: [
            "أضف الموظفين في [[المستخدمون]]. يستطيع دور [[مدير]] فعل كل شيء، أما دور [[أمين الصندوق]] فيقتصر على ما تسمح به قواعد الأمان.",
            "في [[قواعد الأمان]]، اضبط كل إجراء — الاسترجاع، فتح درج النقد، عرض أسعار التكلفة — على [[أمين الصندوق]] أو [[مدير]].",
            "تسري القواعد على الشركة كلها، وعلى كل جهاز.",
          ],
        },
        {
          id: "reports",
          title: "التقارير وسجل المبيعات",
          summary: "اطّلع على أداء نشاطك.",
          steps: [
            "تعرض [[التقارير]] المبيعات حسب المنتج والعميل والمستخدم.",
            "يعرض [[سجل المبيعات]] كل عملية بيع، ومنه يمكنك إعادة طباعة إيصال أو بدء استرجاع.",
          ],
        },
      ],
    },
    {
      id: "hardware",
      icon: "hardware",
      title: "الطابعات والشاشات",
      summary: "طابعات الإيصالات وشاشة المطبخ وشاشة العميل والموازين.",
      articles: [
        {
          id: "receipt-printer",
          title: "إعداد طابعة الإيصالات",
          summary: "طابعات Windows والطابعات الشبكية.",
          steps: [
            "افتح [[إعدادات الطابعة]] واختر الطابعة التي تُعدّها، مثل طابعة الإيصالات.",
            "تحت [[الاتصال]]، اختر [[هذا الحاسوب (طابعة Windows)]] لطابعة مثبّتة في Windows، أو [[طابعة شبكية (Wi-Fi / LAN)]] وأدخل عنوان IP والمنفذ — عادةً 9100.",
            "اضبط [[حجم الورق]] على 58 مم أو 80 مم واطبع صفحة اختبار. إنها مسطرة بعرض الورق كله: إذا انتقلت إلى سطر جديد فحجم الورق خاطئ.",
          ],
          note: "تطبع الأجهزة اللوحية Android عبر طابعة شبكية. يُحفظ الاتصال لكل جهاز على حدة، فيمكن لصندوق Windows وجهاز لوحي الوصول إلى الطابعة نفسها بطريقتين مختلفتين.",
        },
        {
          id: "kitchen-display",
          title: "إرسال الطلبات إلى شاشة المطبخ",
          summary: "تذاكر على شاشة في المطبخ بدل الورق.",
          steps: [
            "ثبّت تطبيق شاشة المطبخ من Octopus على شاشة المطبخ، على الشبكة المحلية نفسها التي تتصل بها صناديقك.",
            "على كل صندوق، افتح [[الإعدادات]] ثم [[شاشة المطبخ]]، وأضف [[عنوان IP لشاشة المطبخ]].",
            "تظهر الطلبات المرسلة من الصندوق في المطبخ فورًا.",
          ],
          note: "يتواصل الصندوق والمطبخ عبر شبكتك المحلية، لذلك يستمر العمل دون إنترنت.",
        },
        {
          id: "customer-display",
          title: "اعرض الطلب على عميلك",
          summary: "شاشة ثانية تعكس السلة أثناء البيع.",
          steps: [
            "في [[الإعدادات]]، فعّل [[شاشة العميل]].",
            "امسح رمز QR الظاهر هناك لفتح شاشة العميل على جهاز آخر، مثل جهاز لوحي موجّه نحو العميل.",
            "يرى العميل كل عنصر والمجموع أثناء إضافتها.",
          ],
        },
        {
          id: "scales",
          title: "الموازين",
          summary: "تعمل موازين الرموز الشريطية والموازين التسلسلية بطريقتين مختلفتين.",
          steps: [
            "موازين الرموز الشريطية: العناصر الموزونة والمُلصقة على الميزان تُمسح مثل أي رمز شريطي، على Windows وAndroid.",
            "الموازين التسلسلية (Windows فقط): في [[الإعدادات]] افتح [[ميزان]]، واختر منفذ COM والسرعة، وتحقق من القراءة المباشرة قبل البيع.",
            "على الصندوق تعرض لوحة الكمية الوزن مباشرة، ويصبح [[استخدام الوزن]] متاحًا عندما تستقر القراءة.",
          ],
        },
      ],
    },
    {
      id: "troubleshooting",
      icon: "lifebuoy",
      title: "حل المشكلات",
      summary: "حلول سريعة للمشكلات الأكثر شيوعًا.",
      faq: true,
      articles: [
        {
          id: "printer-unreachable",
          title: "الطابعة لا تطبع شيئًا",
          summary: "تذكر رسالة الخطأ العنوان الذي حاول الجهاز الوصول إليه.",
          steps: [
            "تذكر رسالة الخطأ العنوان والمنفذ اللذين تعذّر على الجهاز الوصول إليهما، مثل 192.168.1.50:9100.",
            "تأكد أن الطابعة مشغّلة وعلى الشبكة نفسها، وأن عنوان IP والمنفذ يطابقان [[إعدادات الطابعة]].",
            "اكتب عنوان IP وحده — دون «http://» ودون المنفذ الذي له حقل خاص — ثم اطبع صفحة اختبار.",
          ],
        },
        {
          id: "not-syncing",
          title: "المبيعات لا تصل إلى الإدارة",
          summary: "إنها تنتظر على الجهاز.",
          steps: [
            "افتح لوحة حالة المزامنة وابحث عن السجلات الموسومة [[بانتظار المزامنة]].",
            "رسالة «تعذّر الوصول إلى الخادم» تعني أن الجهاز غير متصل بالإنترنت. أعد توصيله ثم اضغط [[المزامنة الآن]].",
          ],
        },
        {
          id: "name-taken",
          title: "اسم الجهاز مستخدم بالفعل",
          summary: "لا يمكن أن يحمل الاسم إلا جهاز واحد في حسابك.",
          steps: [
            "اختر اسمًا آخر.",
            "أو، إذا لم يعد الجهاز القديم موجودًا، ألغِه من [[الأجهزة النشطة]] وأعد استخدام الاسم.",
          ],
        },
        {
          id: "subscription",
          title: "رسالة «الاشتراك غير نشط» توقف الصندوق",
          summary: "لم يتمكن الجهاز من تأكيد ترخيصك لمدة طويلة.",
          steps: [
            "صِل الجهاز بالإنترنت ليحدّث ترخيصه.",
            "إذا بقيت رسالة [[الاشتراك غير نشط]] ظاهرة، تواصل معنا.",
          ],
        },
        {
          id: "switch-register",
          title: "الجهاز لا ينتقل إلى صندوق آخر",
          summary: "ما زالت للصندوق الحالي جلسة مفتوحة.",
          steps: [
            "أغلق جلسة هذا الصندوق أولًا.",
            "التبديل والجلسة مفتوحة سيتركها مفتوحة دون طريقة للعودة إليها من هذا الجهاز.",
          ],
        },
        {
          id: "cashier-refused",
          title: "رفض إجراء لأمين الصندوق",
          summary: "الإجراء مخصص للمديرين.",
          steps: [
            "في [[قواعد الأمان]]، الإجراء مضبوط على [[مدير]].",
            "اطلب من مدير القيام به، أو غيّر القاعدة إلى [[أمين الصندوق]] للشركة كلها.",
          ],
        },
      ],
    },
  ],
};

export const HELP: Record<Lang, HelpDict> = { en, fr, ar };
