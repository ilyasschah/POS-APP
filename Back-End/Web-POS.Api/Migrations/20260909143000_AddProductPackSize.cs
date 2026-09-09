using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddProductPackSize : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // How many pieces are in one box / one pack of THIS product.
            //
            // Nullable with no default on purpose: NULL means "use the catalog's
            // nominal 12 (box) / 6 (pack)", which is exactly what every existing
            // row already behaved as, so applying this migration cannot move a
            // single stock figure or reprice a single line.
            migrationBuilder.AddColumn<decimal>(
                name: "PackSize",
                table: "Product",
                type: "decimal(18,4)",
                precision: 18,
                scale: 4,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PackSize",
                table: "Product");
        }
    }
}
