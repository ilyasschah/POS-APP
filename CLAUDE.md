# Project Overview
This is an enterprise-grade Point of Sale (POS) ecosystem designed for Windows touch-screen monitors AND 13-inch Android tablets. 
It consists of a C# .NET backend API, a cross-platform Flutter POS frontend, and a Kitchen Display System (KDS).

## 📂 Workspace Folder Structure
This repository contains three main directories. **You must ensure you are in the correct directory before executing any terminal commands (like `dotnet run` or `flutter pub get`).**
* `/Front-End` -> The main Flutter POS application (compiled to .exe and .apk). Uses Riverpod and Dio.
* `/Back-End` -> The C# .NET 8/9 API. Uses Entity Framework Core, SQL Server, and MediatR (CQRS).
* `/kitchen_display` -> The companion frontend application for the kitchen staff to view and manage incoming orders.

---

## 🚫 STRICT BACKEND RULES (CRITICAL)
1.  **NEVER modify Entity Framework Domain Models** (e.g., `PosOrder.cs`, `PosOrderItem.cs`) to add transient/frontend-only data (like `WarehouseId` or UI state).
2.  **Use DTOs for Data Transfer:** Transient data required for business logic (like checking inventory before saving) MUST be passed via Request DTOs (e.g., `CreatePosOrderRequest`) and parsed in the Controllers/Command Handlers.
3.  **Do Not Create Migrations unless explicitly told to.** Do not alter the database schema to solve a UI or logic problem.
4.  **Graceful API Errors:** Business logic failures (like "Out of Stock") must return a `400 Bad Request` with a structured JSON payload: `{ success: false, message: "...", fallbackWarehouses: [...], failedProductId: 123 }`. Do not throw unhandled 500 exceptions for business logic.

---

## 🚫 STRICT FRONTEND RULES (CRITICAL)
1.  **Cross-Platform Compatibility:** The `/Front-End` app must compile for both Windows and Android. If adding new hardware features (like printers or scanners), use packages that support both platforms or cleanly abstract the platform-specific code. 
2.  **10-inch Tablet Responsiveness:** Design UI elements for touch. Buttons and dropdowns must be easily tappable by fingers. Use `LayoutBuilder` and `MediaQuery` to ensure the layout scales beautifully across 10-inch landscape screens without RenderFlex overflows.
3.  **100% Dark Mode Compatibility:** NEVER use hardcoded colors like `Colors.white`, `Colors.black`, or `Colors.grey[100]`. 
4.  **Theme Sourcing:** Always use Material 3 theme properties:
    * Main backgrounds: `Theme.of(context).scaffoldBackgroundColor`
    * Cards/Dialogs: `Theme.of(context).cardColor` or `Theme.of(context).colorScheme.surface`
    * Table Headers: `WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest)`
5.  **"Ilyass Style" (say it and this is the contract):** the house layout
    rules — full spec in `PROJECT_DOCUMENTATION.md` §7 and `handoff.md` §0.
    * **No dead flex space:** never `Expanded(label) + Flexible(value)` — that
      strands the value at the midpoint. Use loose `Flexible` on both sides with
      `MainAxisAlignment.spaceBetween` and flex caps (3/2).
    * **Math-based wrapping:** grids/filter rows compute their own column count
      from `constraints.maxWidth` and a `minTileWidth`, never from
      `context.isCompact`.
    * **Max-width caps:** reading views are wrapped in `Center` +
      `ConstrainedBox(maxWidth: kMaxReadableWidth)` (`lib/core/responsive.dart`).
      Data tables are the exception — they scroll horizontally instead.
    * **Tables:** use `IlyassTable<T>` (`lib/core/ilyass_table.dart`) — draggable
      columns, surplus width to one `flexible` column, `numeric: true` (money,
      counts) end-aligned, actions fixed-width and `resizable: false`.

6.  **API Client Handling:** When using Dio, catch `400 Bad Request` errors safely and return the JSON response `e.response?.data` to the UI instead of throwing a fatal exception, so the UI can show interactive dialogs.

---

## 🧠 Core Business Logic to Remember
* **Inventory Reservation (Delta Logic):** When updating an existing order, calculate the *Delta* (`IncomingQuantity - OldQuantity`). Only deduct the difference to prevent double-deduction. If the user removes an item, add the quantity back to stock. Skip inventory checks for products marked as "Services".
* **Item-Level Sourcing (Split Sourcing):** Warehouse allocation happens at the *Item Level*, not the global cart level. A single cart can have Product A from Warehouse A, and Product B from Warehouse B.
* **All Products vs Stock:** The Stock/Inventory UI must always list *ALL* products. If a product does not have a stock record in a warehouse, display it as "Unassigned" and provide an option to add it.

---

## State Management Notes
* The Flutter frontends rely heavily on Riverpod (`FutureProvider`, `StateProvider`). Ensure state invalidation (`ref.invalidate(...)`) is called after successful POST/PATCH/DELETE API calls to keep the UI fresh without network reloading.