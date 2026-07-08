using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class MultiTableBookings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "FloorPlanTableId",
                table: "Booking");

            migrationBuilder.AddColumn<int>(
                name: "CompanyId",
                table: "Counter",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "TableIds",
                table: "Booking",
                type: "nvarchar(1000)",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CompanyId",
                table: "Counter");

            migrationBuilder.DropColumn(
                name: "TableIds",
                table: "Booking");

            migrationBuilder.AddColumn<int>(
                name: "FloorPlanTableId",
                table: "Booking",
                type: "int",
                nullable: true);

        }
    }
}
