/*  Backlog 38, phase 6 — the free-text COMMENT catalogue becomes modifier groups.
    ------------------------------------------------------------------------------
    Run this ONCE per database, before deploying the build that hides the comment
    editor. It converts what is already there; it deletes nothing.

    WHAT IT DOES
      For every product that has ProductComment rows, it creates ONE modifier
      group named "<Product name> — Notes", fills it with that product's comments
      as FREE choices (AdditionalPrice = 0), and attaches it to that product.

    WHY THAT SHAPE
      It is what the old dialog actually did: a list of switches the cashier could
      tick in any combination, joined with ", " into the line's comment. So the
      group is optional (MinSelections = 0) and pick-many (MaxSelections = the
      number of choices). AllowsFreeText = 1 keeps the "…and anything else"
      box that dialog also had.

      🚨 One group PER PRODUCT, not one shared group. Two products' comment lists
      overlap by accident, never by intent — merging them would offer "No Onions"
      on the coffee. Groups are cheap and the operator can merge them by hand
      afterwards; un-merging a wrong guess is the expensive direction.

    IDEMPOTENT
      Re-running matches nothing: each step skips a product that already has a
      group of this exact name. Safe to run twice, and safe to run on a database
      that has no comments at all.

    NOT DELETED
      ProductComment rows are left exactly where they are. This script is the
      dangerous half of the retirement and it is reversible only while the source
      data still exists — check the result on the real catalogue first. Dropping
      the table is a separate, later step.
*/

SET NOCOUNT ON;
BEGIN TRANSACTION;

DECLARE @suffix nvarchar(20) = N' — Notes';
DECLARE @now datetime2 = SYSUTCDATETIME();

/* Products that have comments and do not yet have their converted group. */
IF OBJECT_ID('tempdb..#ToConvert') IS NOT NULL DROP TABLE #ToConvert;

SELECT DISTINCT
       pc.CompanyId,
       pc.ProductId,
       CAST(LEFT(p.Name + @suffix, 100) AS nvarchar(100)) AS GroupName
INTO   #ToConvert
FROM   ProductComment pc
JOIN   Product p
       ON p.Id = pc.ProductId AND p.CompanyId = pc.CompanyId
WHERE  NOT EXISTS (
           SELECT 1 FROM ModifierGroup mg
           WHERE  mg.CompanyId = pc.CompanyId
             AND  mg.Name = CAST(LEFT(p.Name + @suffix, 100) AS nvarchar(100))
       );

/* 1. One group per product. MaxSelections is set below, once its choices are
      counted — a group whose max is lower than the number of options it offers
      is refused by the editor, and the seeder must not create one. */
INSERT INTO ModifierGroup (CompanyId, Name, MinSelections, MaxSelections,
                           AllowsFreeText, IconKey, Rank, IsEnabled, LastModified)
SELECT c.CompanyId, c.GroupName, 0, 1, 1, NULL, 0, 1, @now
FROM   #ToConvert c;

/* 2. The comments themselves, as free choices, in id order (the order they were
      added, which is the order the old dialog listed them in). */
INSERT INTO ModifierOption (CompanyId, ModifierGroupId, Name, AdditionalPrice,
                            Rank, IsEnabled, LastModified)
SELECT pc.CompanyId,
       mg.Id,
       CAST(LEFT(pc.Comment, 100) AS nvarchar(100)),
       0,
       ROW_NUMBER() OVER (PARTITION BY pc.ProductId ORDER BY pc.Id) - 1,
       1,
       @now
FROM   ProductComment pc
JOIN   #ToConvert c
       ON c.ProductId = pc.ProductId AND c.CompanyId = pc.CompanyId
JOIN   ModifierGroup mg
       ON mg.CompanyId = c.CompanyId AND mg.Name = c.GroupName
WHERE  LEN(LTRIM(RTRIM(pc.Comment))) > 0;

/* 3. Now the max: as many as there are, so every previously-possible
      combination is still possible. */
UPDATE mg
SET    mg.MaxSelections = x.OptionCount
FROM   ModifierGroup mg
JOIN   #ToConvert c
       ON c.CompanyId = mg.CompanyId AND c.GroupName = mg.Name
CROSS APPLY (
       SELECT COUNT(*) AS OptionCount
       FROM   ModifierOption mo
       WHERE  mo.ModifierGroupId = mg.Id
) x
WHERE  x.OptionCount > 0;

/* 4. Attach each group to the product it came from. */
INSERT INTO ProductModifierGroup (CompanyId, ProductId, ModifierGroupId, Rank, LastModified)
SELECT c.CompanyId, c.ProductId, mg.Id,
       ISNULL((SELECT MAX(pmg.Rank) + 1
               FROM   ProductModifierGroup pmg
               WHERE  pmg.ProductId = c.ProductId AND pmg.CompanyId = c.CompanyId), 0),
       @now
FROM   #ToConvert c
JOIN   ModifierGroup mg
       ON mg.CompanyId = c.CompanyId AND mg.Name = c.GroupName
WHERE  NOT EXISTS (
           SELECT 1 FROM ProductModifierGroup pmg
           WHERE  pmg.CompanyId = c.CompanyId
             AND  pmg.ProductId = c.ProductId
             AND  pmg.ModifierGroupId = mg.Id
       );

/* 5. A group that ended up with NO choices would be offered at the till and
      answer nothing. Only possible from comments that were entirely blank. */
DELETE pmg
FROM   ProductModifierGroup pmg
JOIN   #ToConvert c
       ON c.CompanyId = pmg.CompanyId AND c.ProductId = pmg.ProductId
JOIN   ModifierGroup mg
       ON mg.Id = pmg.ModifierGroupId AND mg.Name = c.GroupName
WHERE  NOT EXISTS (SELECT 1 FROM ModifierOption mo WHERE mo.ModifierGroupId = mg.Id);

DELETE mg
FROM   ModifierGroup mg
JOIN   #ToConvert c
       ON c.CompanyId = mg.CompanyId AND c.GroupName = mg.Name
WHERE  NOT EXISTS (SELECT 1 FROM ModifierOption mo WHERE mo.ModifierGroupId = mg.Id);

SELECT (SELECT COUNT(*) FROM #ToConvert)                        AS ProductsConverted,
       (SELECT COUNT(*) FROM ProductComment)                    AS CommentsStillOnFile,
       (SELECT COUNT(*) FROM ModifierGroup WHERE Name LIKE '%' + @suffix) AS GroupsNamedNotes;

DROP TABLE #ToConvert;

COMMIT;
GO
