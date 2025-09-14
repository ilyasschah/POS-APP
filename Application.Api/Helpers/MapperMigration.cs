using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
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
