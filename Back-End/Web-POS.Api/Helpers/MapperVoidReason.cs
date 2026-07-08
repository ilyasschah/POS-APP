using Api.Domain;
using Api.Models;

namespace Api.Helpers
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