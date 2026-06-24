using Api.DataBase;
using Microsoft.EntityFrameworkCore;

namespace Api.Services
{
    /// <summary>
    /// Seeds the GLOBAL shared reference tables (DocumentCategory, DocumentType,
    /// Currency) when they are empty. Runs once on app startup so a database wipe
    /// can never leave the app without the static data it needs to function.
    /// IDs are pinned to match DocumentTypeConstants / DocumentCategoryConstants.
    /// </summary>
    public static class GlobalDefaultsSeeder
    {
        public static async Task SeedAsync(AppDbContext db)
        {
            if (!await db.DocumentCategories.AnyAsync())
            {
                await db.Database.ExecuteSqlRawAsync(@"
SET IDENTITY_INSERT dbo.DocumentCategory ON;
INSERT INTO dbo.DocumentCategory (Id, Name, LanguageKey) VALUES
 (1, N'Expenses',  N'Document.Category.Expenses'),
 (2, N'Sales',     N'Document.Category.Sales'),
 (3, N'Inventory', N'Document.Category.Inventory'),
 (4, N'Loss',      N'Document.Category.Loss');
SET IDENTITY_INSERT dbo.DocumentCategory OFF;");
            }

            if (!await db.DocumentTypes.AnyAsync())
            {
                await db.Database.ExecuteSqlRawAsync(@"
SET IDENTITY_INSERT dbo.DocumentType ON;
INSERT INTO dbo.DocumentType (Id, Name, Code, DocumentCategoryId, StockDirection, EditorType, PrintTemplate, PriceType, LanguageKey) VALUES
 (1, N'Purchase',        N'100', 1, 1, 1, N'Purchase',       2, N'Document.Category.Expenses.Purchase'),
 (2, N'Sales',           N'200', 2, 2, 2, N'Invoice',        1, N'Document.Category.Sales.Sales'),
 (3, N'Inventory Count', N'300', 3, 1, 1, N'InventoryCount', 0, N'Document.Category.Inventory.InventoryCount'),
 (4, N'Refund',          N'220', 2, 1, 1, N'Refund',         1, N'Document.Category.Sales.Refund'),
 (5, N'Stock Return',    N'120', 1, 2, 2, N'StockReturn',    2, N'Document.Category.Expenses.StockReturn'),
 (6, N'Loss And Damage', N'400', 4, 2, 2, N'LossAndDamage',  1, N'Document.Category.Loss.LossAndDamage'),
 (7, N'Proforma',        N'230', 2, 0, 0, N'Proforma',       1, N'Document.Category.Sales.Proforma');
SET IDENTITY_INSERT dbo.DocumentType OFF;");
            }

            if (!await db.Currencies.AnyAsync())
            {
                await db.Database.ExecuteSqlRawAsync(
                    "INSERT INTO dbo.Currency (Name, Code) VALUES (N'Moroccan Dirham', N'MAD');");
            }
        }
    }
}
