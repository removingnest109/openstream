using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Openstream.Core.Migrations
{
    /// <inheritdoc />
    public partial class AddAlbumArtPathToAlbum : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AlbumArtPath",
                table: "Albums",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AlbumArtPath",
                table: "Albums");
        }
    }
}
