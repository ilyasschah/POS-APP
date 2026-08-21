using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSellByWeightAndBarcodeRules : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsToWeigh",
                table: "Product",
                type: "bit",
                nullable: false,
                defaultValue: false);

            // 1 = pieces. EF's own default would be 0, which is not a member of
            // the UnitOfMeasure catalog — every existing row would then resolve
            // through the "unknown id" fallback instead of holding a real unit.
            migrationBuilder.AddColumn<int>(
                name: "UomId",
                table: "Product",
                type: "int",
                nullable: false,
                defaultValue: 1);

            // Backfill from the legacy free-text MeasurementUnit. Mirrors
            // UnitOfMeasure.FromLegacyText — keep the two in step. Anything
            // unrecognised keeps the pieces default, which converts 1:1 and so
            // cannot move an existing stock number.
            migrationBuilder.Sql(@"
                UPDATE Product SET UomId = CASE LOWER(LTRIM(RTRIM(MeasurementUnit)))
                    WHEN 'kg' THEN 10 WHEN 'kgs' THEN 10 WHEN 'kilo' THEN 10
                    WHEN 'kilos' THEN 10 WHEN 'kilogram' THEN 10 WHEN 'kilograms' THEN 10
                    WHEN 'g' THEN 11 WHEN 'gr' THEN 11 WHEN 'gm' THEN 11
                    WHEN 'gram' THEN 11 WHEN 'grams' THEN 11
                    WHEN 'lb' THEN 12 WHEN 'lbs' THEN 12 WHEN 'pound' THEN 12 WHEN 'pounds' THEN 12
                    WHEN 'l' THEN 20 WHEN 'lt' THEN 20 WHEN 'ltr' THEN 20
                    WHEN 'litre' THEN 20 WHEN 'litres' THEN 20 WHEN 'liter' THEN 20 WHEN 'liters' THEN 20
                    WHEN 'ml' THEN 21 WHEN 'millilitre' THEN 21 WHEN 'millilitres' THEN 21
                    WHEN 'milliliter' THEN 21 WHEN 'milliliters' THEN 21
                    WHEN 'm' THEN 30 WHEN 'mtr' THEN 30 WHEN 'meter' THEN 30
                    WHEN 'meters' THEN 30 WHEN 'metre' THEN 30 WHEN 'metres' THEN 30
                    WHEN 'cm' THEN 31 WHEN 'centimeter' THEN 31 WHEN 'centimeters' THEN 31
                    WHEN 'centimetre' THEN 31 WHEN 'centimetres' THEN 31
                    WHEN 'dozen' THEN 2 WHEN 'dz' THEN 2 WHEN 'doz' THEN 2
                    WHEN 'box' THEN 3 WHEN 'bx' THEN 3 WHEN 'carton' THEN 3
                    WHEN 'pack' THEN 4 WHEN 'pk' THEN 4 WHEN 'packet' THEN 4
                    ELSE 1 END
                WHERE MeasurementUnit IS NOT NULL;");

            // A weight or volume unit is only ever put on a product that is
            // actually weighed, so light it up rather than making the user tick
            // every one of them by hand after upgrading.
            migrationBuilder.Sql(
                "UPDATE Product SET IsToWeigh = 1 WHERE UomId IN (10, 11, 12, 20, 21);");

            migrationBuilder.CreateTable(
                name: "BarcodeRule",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Sequence = table.Column<int>(type: "int", nullable: false),
                    Type = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Encoding = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    Pattern = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsEnabled = table.Column<bool>(type: "bit", nullable: false),
                    LastModified = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BarcodeRule", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BarcodeRule_Company_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Company",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BarcodeRule_CompanyId_Sequence",
                table: "BarcodeRule",
                columns: new[] { "CompanyId", "Sequence" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BarcodeRule");

            migrationBuilder.DropColumn(
                name: "IsToWeigh",
                table: "Product");

            migrationBuilder.DropColumn(
                name: "UomId",
                table: "Product");
        }
    }
}
