using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public static class MapperStartingCash
    {
        public static StartingCashDto MapToStartingCashDto(StartingCash entity)
        {
            return new StartingCashDto
            {
                Id = entity.Id,
                CompanyId = entity.CompanyId,
                UserId = entity.UserId,
                UserName = entity.User != null
                    ? $"{entity.User.FirstName} {entity.User.LastName}".Trim()
                    : null,
                Amount = entity.Amount,
                Description = entity.Description,
                StartingCashType = entity.StartingCashType,
                ZReportNumber = entity.ZReportNumber,
                DateCreated = entity.DateCreated
            };
        }
    }
}
