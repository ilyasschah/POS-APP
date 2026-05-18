using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetSalesByUserQuery : IRequest<List<SalesByUserDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
        public int? ProductId { get; set; }
        public int? ProductGroupId { get; set; }
    }

    public class GetSalesByUserQueryHandler
        : IRequestHandler<GetSalesByUserQuery, List<SalesByUserDto>>
    {
        private readonly AppDbContext _db;

        public GetSalesByUserQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<SalesByUserDto>> Handle(
            GetSalesByUserQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.SalesByProductRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.CustomerId.HasValue)
                query = query.Where(r => r.CustomerId == request.CustomerId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            if (request.ProductId.HasValue)
                query = query.Where(r => r.ProductId == request.ProductId);

            if (request.ProductGroupId.HasValue)
                query = query.Where(r => r.ProductGroupId == request.ProductGroupId);

            var grouped = await query
                .GroupBy(r => r.UserId)
                .Select(g => new
                {
                    UserId         = g.Key,
                    TotalBeforeTax = g.Sum(r => r.TotalBeforeTax),
                    Total          = g.Sum(r => r.Total),
                })
                .ToListAsync(cancellationToken);

            var userIds = grouped.Select(g => g.UserId).Distinct().ToList();

            var userNames = await _db.Users
                .Where(u => u.CompanyId == request.CompanyId
                         && userIds.Contains(u.Id))
                .Select(u => new { u.Id, u.FirstName, u.LastName, u.Username })
                .ToDictionaryAsync(u => u.Id, u => u, cancellationToken);

            return grouped
                .Select(g =>
                {
                    var displayName = "Unknown";
                    if (userNames.TryGetValue(g.UserId, out var u))
                    {
                        var full = $"{u.FirstName ?? ""} {u.LastName ?? ""}".Trim();
                        displayName = full.Length > 0 ? full : u.Username ?? $"User {g.UserId}";
                    }
                    return new SalesByUserDto
                    {
                        User           = displayName,
                        TotalBeforeTax = g.TotalBeforeTax,
                        Total          = g.Total,
                    };
                })
                .OrderBy(r => r.User)
                .ToList();
        }
    }
}
