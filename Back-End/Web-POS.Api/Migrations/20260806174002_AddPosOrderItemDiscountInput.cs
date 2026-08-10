using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddPosOrderItemDiscountInput : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "DiscountInputType",
                table: "PosOrderItem",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "DiscountInputValue",
                table: "PosOrderItem",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DiscountInputType",
                table: "PosOrderItem");

            migrationBuilder.DropColumn(
                name: "DiscountInputValue",
                table: "PosOrderItem");
        }
    }
}
