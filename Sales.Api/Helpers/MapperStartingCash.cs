using Sales.Api.Domain;
using Sales.Api.Models;

namespace Sales.Api.Helpers
{
    public static class MapperStartingCash
    {
        public static StartingCashDto MapToStartingCashDto(StartingCash entity)
        {
            return new StartingCashDto
            {
                Id = entity.Id,
                UserId = entity.UserId,
                Amount = entity.Amount,
                Description = entity.Description,
                StartingCashType = entity.StartingCashType,
                ZReportNumber = entity.ZReportNumber,
                DateCreated = entity.DateCreated
            };
        }
    }
}
