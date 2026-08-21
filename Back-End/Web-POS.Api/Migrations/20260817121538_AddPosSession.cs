using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddPosSession : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "SessionId",
                table: "StartingCash",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "CashDifference",
                table: "Shift",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ClosedByUserId",
                table: "Shift",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ClosingNote",
                table: "Shift",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ExpectedCash",
                table: "Shift",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ForceCloseReason",
                table: "Shift",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "ForceClosed",
                table: "Shift",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "ForceClosedByUserId",
                table: "Shift",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "HasLateArrivals",
                table: "Shift",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "LocalId",
                table: "Shift",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PosDeviceId",
                table: "Shift",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SessionId",
                table: "PosOrder",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SessionId",
                table: "Payment",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "ArrivedAfterClose",
                table: "Document",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "SessionId",
                table: "Document",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "PosDevice",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    DeviceUid = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    FirstSeenAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastSeenAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastModified = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PosDevice", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PosSessionPaymentCount",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    SessionId = table.Column<int>(type: "int", nullable: false),
                    PaymentTypeId = table.Column<int>(type: "int", nullable: false),
                    Expected = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Counted = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    Difference = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    DateCreated = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PosSessionPaymentCount", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PosSessionPaymentCount_PaymentType_PaymentTypeId",
                        column: x => x.PaymentTypeId,
                        principalTable: "PaymentType",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PosSessionPaymentCount_Shift_SessionId",
                        column: x => x.SessionId,
                        principalTable: "Shift",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ZReportCorrection",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    SessionId = table.Column<int>(type: "int", nullable: false),
                    OriginalZReportId = table.Column<int>(type: "int", nullable: true),
                    LateOrderCount = table.Column<int>(type: "int", nullable: false),
                    LateAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    LateCashAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    FirstDetectedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastDetectedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Acknowledged = table.Column<bool>(type: "bit", nullable: false),
                    AcknowledgedByUserId = table.Column<int>(type: "int", nullable: true),
                    AcknowledgedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ZReportCorrection", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ZReportCorrection_Shift_SessionId",
                        column: x => x.SessionId,
                        principalTable: "Shift",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_StartingCash_SessionId",
                table: "StartingCash",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_Shift_CompanyId_LocalId",
                table: "Shift",
                columns: new[] { "CompanyId", "LocalId" },
                unique: true,
                filter: "[LocalId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Shift_PosDeviceId_Status",
                table: "Shift",
                columns: new[] { "PosDeviceId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_PosOrder_SessionId",
                table: "PosOrder",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_Payment_SessionId",
                table: "Payment",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_Document_SessionId",
                table: "Document",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_PosDevice_CompanyId_DeviceUid",
                table: "PosDevice",
                columns: new[] { "CompanyId", "DeviceUid" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PosSessionPaymentCount_PaymentTypeId",
                table: "PosSessionPaymentCount",
                column: "PaymentTypeId");

            migrationBuilder.CreateIndex(
                name: "IX_PosSessionPaymentCount_SessionId_PaymentTypeId",
                table: "PosSessionPaymentCount",
                columns: new[] { "SessionId", "PaymentTypeId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ZReportCorrection_SessionId_OriginalZReportId",
                table: "ZReportCorrection",
                columns: new[] { "SessionId", "OriginalZReportId" },
                unique: true,
                filter: "[OriginalZReportId] IS NOT NULL");

            migrationBuilder.AddForeignKey(
                name: "FK_Document_Shift_SessionId",
                table: "Document",
                column: "SessionId",
                principalTable: "Shift",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Payment_Shift_SessionId",
                table: "Payment",
                column: "SessionId",
                principalTable: "Shift",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_PosOrder_Shift_SessionId",
                table: "PosOrder",
                column: "SessionId",
                principalTable: "Shift",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Shift_PosDevice_PosDeviceId",
                table: "Shift",
                column: "PosDeviceId",
                principalTable: "PosDevice",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_StartingCash_Shift_SessionId",
                table: "StartingCash",
                column: "SessionId",
                principalTable: "Shift",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Document_Shift_SessionId",
                table: "Document");

            migrationBuilder.DropForeignKey(
                name: "FK_Payment_Shift_SessionId",
                table: "Payment");

            migrationBuilder.DropForeignKey(
                name: "FK_PosOrder_Shift_SessionId",
                table: "PosOrder");

            migrationBuilder.DropForeignKey(
                name: "FK_Shift_PosDevice_PosDeviceId",
                table: "Shift");

            migrationBuilder.DropForeignKey(
                name: "FK_StartingCash_Shift_SessionId",
                table: "StartingCash");

            migrationBuilder.DropTable(
                name: "PosDevice");

            migrationBuilder.DropTable(
                name: "PosSessionPaymentCount");

            migrationBuilder.DropTable(
                name: "ZReportCorrection");

            migrationBuilder.DropIndex(
                name: "IX_StartingCash_SessionId",
                table: "StartingCash");

            migrationBuilder.DropIndex(
                name: "IX_Shift_CompanyId_LocalId",
                table: "Shift");

            migrationBuilder.DropIndex(
                name: "IX_Shift_PosDeviceId_Status",
                table: "Shift");

            migrationBuilder.DropIndex(
                name: "IX_PosOrder_SessionId",
                table: "PosOrder");

            migrationBuilder.DropIndex(
                name: "IX_Payment_SessionId",
                table: "Payment");

            migrationBuilder.DropIndex(
                name: "IX_Document_SessionId",
                table: "Document");

            migrationBuilder.DropColumn(
                name: "SessionId",
                table: "StartingCash");

            migrationBuilder.DropColumn(
                name: "CashDifference",
                table: "Shift");

            migrationBuilder.DropColumn(
                name: "ClosedByUserId",
                table: "Shift");

            migrationBuilder.DropColumn(
                name: "ClosingNote",
                table: "Shift");

            migrationBuilder.DropColumn(
                name: "ExpectedCash",
                table: "Shift");

            migrationBuilder.DropColumn(
                name: "ForceCloseReason",
                table: "Shift");

            migrationBuilder.DropColumn(
                name: "ForceClosed",
                table: "Shift");

            migrationBuilder.DropColumn(
                name: "ForceClosedByUserId",
                table: "Shift");

            migrationBuilder.DropColumn(
                name: "HasLateArrivals",
                table: "Shift");

            migrationBuilder.DropColumn(
                name: "LocalId",
                table: "Shift");

            migrationBuilder.DropColumn(
                name: "PosDeviceId",
                table: "Shift");

            migrationBuilder.DropColumn(
                name: "SessionId",
                table: "PosOrder");

            migrationBuilder.DropColumn(
                name: "SessionId",
                table: "Payment");

            migrationBuilder.DropColumn(
                name: "ArrivedAfterClose",
                table: "Document");

            migrationBuilder.DropColumn(
                name: "SessionId",
                table: "Document");
        }
    }
}
