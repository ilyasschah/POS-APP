using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperMigration
    {
        public static MigrationDto MapToMigrationDto(Migration entity)
        {
            return new MigrationDto
            {
                Id = entity.Id,
                Version = entity.Version,
                Description = entity.Description,
                FileName = entity.FileName,
                Module = entity.Module,
                Date = entity.Date
            };
        }
    }
}
