using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddZReportSessionAndOpeningNote : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DisplayNumber",
                table: "ZReport",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PosDeviceId",
                table: "ZReport",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SessionId",
                table: "ZReport",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "OpeningNote",
                table: "Shift",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ZReport_CompanyId_PosDeviceId",
                table: "ZReport",
                columns: new[] { "CompanyId", "PosDeviceId" });

            migrationBuilder.CreateIndex(
                name: "IX_ZReport_PosDeviceId",
                table: "ZReport",
                column: "PosDeviceId");

            migrationBuilder.CreateIndex(
                name: "IX_ZReport_SessionId",
                table: "ZReport",
                column: "SessionId");

            migrationBuilder.AddForeignKey(
                name: "FK_ZReport_PosDevice_PosDeviceId",
                table: "ZReport",
                column: "PosDeviceId",
                principalTable: "PosDevice",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_ZReport_Shift_SessionId",
                table: "ZReport",
                column: "SessionId",
                principalTable: "Shift",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ZReport_PosDevice_PosDeviceId",
                table: "ZReport");

            migrationBuilder.DropForeignKey(
                name: "FK_ZReport_Shift_SessionId",
                table: "ZReport");

            migrationBuilder.DropIndex(
                name: "IX_ZReport_CompanyId_PosDeviceId",
                table: "ZReport");

            migrationBuilder.DropIndex(
                name: "IX_ZReport_PosDeviceId",
                table: "ZReport");

            migrationBuilder.DropIndex(
                name: "IX_ZReport_SessionId",
                table: "ZReport");

            migrationBuilder.DropColumn(
                name: "DisplayNumber",
                table: "ZReport");

            migrationBuilder.DropColumn(
                name: "PosDeviceId",
                table: "ZReport");

            migrationBuilder.DropColumn(
                name: "SessionId",
                table: "ZReport");

            migrationBuilder.DropColumn(
                name: "OpeningNote",
                table: "Shift");
        }
    }
}
