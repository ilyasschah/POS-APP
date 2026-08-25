using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddModifiers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "DocumentItemModifier",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    DocumentItemId = table.Column<int>(type: "int", nullable: false),
                    ModifierOptionId = table.Column<int>(type: "int", nullable: true),
                    GroupName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    AdditionalPrice = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Rank = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DocumentItemModifier", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DocumentItemModifier_Company_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Company",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_DocumentItemModifier_DocumentItem_DocumentItemId",
                        column: x => x.DocumentItemId,
                        principalTable: "DocumentItem",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ModifierGroup",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    MinSelections = table.Column<int>(type: "int", nullable: false),
                    MaxSelections = table.Column<int>(type: "int", nullable: false),
                    AllowsFreeText = table.Column<bool>(type: "bit", nullable: false),
                    Rank = table.Column<int>(type: "int", nullable: false),
                    IsEnabled = table.Column<bool>(type: "bit", nullable: false),
                    LastModified = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ModifierGroup", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ModifierGroup_Company_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Company",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "PosOrderItemModifier",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    PosOrderItemId = table.Column<int>(type: "int", nullable: false),
                    ModifierOptionId = table.Column<int>(type: "int", nullable: true),
                    GroupName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    AdditionalPrice = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Rank = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PosOrderItemModifier", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PosOrderItemModifier_Company_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Company",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_PosOrderItemModifier_PosOrderItem_PosOrderItemId",
                        column: x => x.PosOrderItemId,
                        principalTable: "PosOrderItem",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ModifierOption",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    ModifierGroupId = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    AdditionalPrice = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Rank = table.Column<int>(type: "int", nullable: false),
                    IsEnabled = table.Column<bool>(type: "bit", nullable: false),
                    LastModified = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ModifierOption", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ModifierOption_Company_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Company",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ModifierOption_ModifierGroup_ModifierGroupId",
                        column: x => x.ModifierGroupId,
                        principalTable: "ModifierGroup",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ProductModifierGroup",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    ProductId = table.Column<int>(type: "int", nullable: false),
                    ModifierGroupId = table.Column<int>(type: "int", nullable: false),
                    Rank = table.Column<int>(type: "int", nullable: false),
                    LastModified = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProductModifierGroup", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProductModifierGroup_Company_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "Company",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ProductModifierGroup_ModifierGroup_ModifierGroupId",
                        column: x => x.ModifierGroupId,
                        principalTable: "ModifierGroup",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ProductModifierGroup_Product_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Product",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_DocumentItemModifier_CompanyId_ModifierOptionId",
                table: "DocumentItemModifier",
                columns: new[] { "CompanyId", "ModifierOptionId" });

            migrationBuilder.CreateIndex(
                name: "IX_DocumentItemModifier_DocumentItemId_Rank",
                table: "DocumentItemModifier",
                columns: new[] { "DocumentItemId", "Rank" });

            migrationBuilder.CreateIndex(
                name: "IX_ModifierGroup_CompanyId_Rank",
                table: "ModifierGroup",
                columns: new[] { "CompanyId", "Rank" });

            migrationBuilder.CreateIndex(
                name: "IX_ModifierOption_CompanyId",
                table: "ModifierOption",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_ModifierOption_ModifierGroupId_Rank",
                table: "ModifierOption",
                columns: new[] { "ModifierGroupId", "Rank" });

            migrationBuilder.CreateIndex(
                name: "IX_PosOrderItemModifier_CompanyId",
                table: "PosOrderItemModifier",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_PosOrderItemModifier_PosOrderItemId_Rank",
                table: "PosOrderItemModifier",
                columns: new[] { "PosOrderItemId", "Rank" });

            migrationBuilder.CreateIndex(
                name: "IX_ProductModifierGroup_CompanyId_ProductId_Rank",
                table: "ProductModifierGroup",
                columns: new[] { "CompanyId", "ProductId", "Rank" });

            migrationBuilder.CreateIndex(
                name: "IX_ProductModifierGroup_ModifierGroupId",
                table: "ProductModifierGroup",
                column: "ModifierGroupId");

            migrationBuilder.CreateIndex(
                name: "IX_ProductModifierGroup_ProductId_ModifierGroupId",
                table: "ProductModifierGroup",
                columns: new[] { "ProductId", "ModifierGroupId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DocumentItemModifier");

            migrationBuilder.DropTable(
                name: "ModifierOption");

            migrationBuilder.DropTable(
                name: "PosOrderItemModifier");

            migrationBuilder.DropTable(
                name: "ProductModifierGroup");

            migrationBuilder.DropTable(
                name: "ModifierGroup");
        }
    }
}
