using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class DropPosPrinterSelectionTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PosPrinterSelectionSettings");

            migrationBuilder.DropTable(
                name: "PosPrinterSelection");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PosPrinterSelection",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    IsEnabled = table.Column<bool>(type: "bit", nullable: false),
                    Key = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    PrinterName = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PosPrinterSelection", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PosPrinterSelectionSettings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PosPrinterSelectionId = table.Column<int>(type: "int", nullable: false),
                    BottomMargin = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    CashDrawerCommand = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    CharacterSet = table.Column<int>(type: "int", nullable: false),
                    CodePage = table.Column<int>(type: "int", nullable: false),
                    CompanyId = table.Column<int>(type: "int", nullable: false),
                    CutPaper = table.Column<bool>(type: "bit", nullable: false),
                    FeedLines = table.Column<int>(type: "int", nullable: false),
                    FontName = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    FontSizePercent = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Footer = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    FooterAlignment = table.Column<int>(type: "int", nullable: false),
                    Header = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    HeaderAlignment = table.Column<int>(type: "int", nullable: false),
                    IsFormattingEnabled = table.Column<bool>(type: "bit", nullable: false),
                    LeftMargin = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Margin = table.Column<int>(type: "int", nullable: false),
                    NumberOfCopies = table.Column<int>(type: "int", nullable: false),
                    OpenCashDrawer = table.Column<bool>(type: "bit", nullable: false),
                    PaperWidth = table.Column<int>(type: "int", nullable: false),
                    PrintBarcode = table.Column<bool>(type: "bit", nullable: false),
                    PrintBitmap = table.Column<bool>(type: "bit", nullable: false),
                    PrintLogoFullWidth = table.Column<bool>(type: "bit", nullable: false),
                    PrinterType = table.Column<int>(type: "int", nullable: false),
                    RightMargin = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    TopMargin = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PosPrinterSelectionSettings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PosPrinterSelectionSettings_PosPrinterSelection_PosPrinterSelectionId",
                        column: x => x.PosPrinterSelectionId,
                        principalTable: "PosPrinterSelection",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PosPrinterSelectionSettings_PosPrinterSelectionId",
                table: "PosPrinterSelectionSettings",
                column: "PosPrinterSelectionId");
        }
    }
}
