using MediatR;
using Microsoft.EntityFrameworkCore;
using Api.DataBase;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.PosVoidQuery;

public class GetPosVoidsByDateRangeQuery : IRequest<List<PosVoidDto>>
{
    public GetPosVoidsByDateRangeRequest Request { get; set; } = default!;

    public class Handler : IRequestHandler<GetPosVoidsByDateRangeQuery, List<PosVoidDto>>
    {
        private readonly AppDbContext _db;

        public Handler(AppDbContext db) => _db = db;

        public async Task<List<PosVoidDto>> Handle(GetPosVoidsByDateRangeQuery query, CancellationToken cancellationToken)
        {
            var r = query.Request;
            var start = r.StartDate.Date;
            var end   = r.EndDate.Date.AddDays(1);

            var q = _db.PosVoids
                .Where(pv => pv.CompanyId == r.CompanyId
                          && pv.DateCreated >= start
                          && pv.DateCreated <  end);

            if (r.UserId.HasValue)
                q = q.Where(pv => pv.UserId == r.UserId);

            if (r.ProductId.HasValue)
                q = q.Where(pv => pv.ProductId == r.ProductId);

            var entities = await q.OrderBy(pv => pv.DateCreated).AsNoTracking().ToListAsync(cancellationToken);
            return entities.Select(MapperPosVoid.MapToPosVoidDto).ToList();
        }
    }
}
