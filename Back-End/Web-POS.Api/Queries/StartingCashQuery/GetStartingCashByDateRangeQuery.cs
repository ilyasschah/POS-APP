using Api.DataBase;
using Api.Helpers;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.StartingCashQuery
{
    public class GetStartingCashByDateRangeQuery : IRequest<List<StartingCashDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? UserId { get; set; }
    }

    public class GetStartingCashByDateRangeQueryHandler
        : IRequestHandler<GetStartingCashByDateRangeQuery, List<StartingCashDto>>
    {
        private readonly AppDbContext _db;

        public GetStartingCashByDateRangeQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<StartingCashDto>> Handle(
            GetStartingCashByDateRangeQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date.AddDays(1);

            var query = _db.StartingCashes
                .Include(sc => sc.User)
                .Where(sc => sc.CompanyId == request.CompanyId
                          && sc.DateCreated >= start
                          && sc.DateCreated < end)
                .AsNoTracking();

            if (request.UserId.HasValue)
                query = query.Where(sc => sc.UserId == request.UserId.Value);

            var items = await query
                .OrderBy(sc => sc.DateCreated)
                .ToListAsync(cancellationToken);

            return items.Select(MapperStartingCash.MapToStartingCashDto).ToList();
        }
    }
}
