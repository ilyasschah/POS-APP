using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class DropProductComment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // The free-text product-comment catalogue was retired with backlog 43 —
            // modifier groups replaced it, and a group's AllowsFreeText carries the
            // one thing it was still good for. The ENTITY went then; the table did
            // not, so the model and the database have disagreed ever since and EF 10
            // refuses to apply ANY migration while that is true
            // (PendingModelChangesWarning).
            //
            // Verified against the live database on 2026-09-09 before writing this:
            // 0 rows, and nothing references it (its two foreign keys both point
            // outward, to Product and Company). The tills dropped their own copy at
            // Drift schema v65. Nothing in either codebase can create a row.
            migrationBuilder.DropTable(name: "ProductComment");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Rebuilds the table as the MODEL last described it, which is what EF
            // itself would generate. Two deliberate differences from the table this
            // dropped, both harmless on an empty table: the live one carried an extra
            // FK_ProductComment_Company that was never in the EF model, and its
            // primary key had a SQL Server auto-name (PK__ProductC__3214EC07…),
            // because the original table predates this project's migrations.
            migrationBuilder.CreateTable(
                name: "ProductComment",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Comment = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    ProductId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProductComment", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProductComment_Product_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Product",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ProductComment_ProductId",
                table: "ProductComment",
                column: "ProductId");
        }
    }
}
