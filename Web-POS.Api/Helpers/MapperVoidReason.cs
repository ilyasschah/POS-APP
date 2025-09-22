using Products.Api.Domain;
using Products.Api.Models;

namespace Products.Api.Helpers
{
    public static class MapperVoidReason
    {
        public static VoidReasonDto MapToVoidReasonDto(VoidReason entity)
        {
            return new VoidReasonDto
            {
                Id = entity.Id,
                Name = entity.Name,
                Rank = entity.Rank,
                DateCreated = entity.DateCreated
            };
        }
    }
}