using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetPaymentTypesByUserQuery : IRequest<List<PaymentTypesByUserDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
    }

    public class GetPaymentTypesByUserQueryHandler
        : IRequestHandler<GetPaymentTypesByUserQuery, List<PaymentTypesByUserDto>>
    {
        private readonly AppDbContext _db;

        public GetPaymentTypesByUserQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<PaymentTypesByUserDto>> Handle(
            GetPaymentTypesByUserQuery request,
            CancellationToken cancellationToken)
        {
            var start = request.StartDate.Date;
            var end   = request.EndDate.Date;

            var query = _db.SalesByPaymentTypeRows
                .Where(r => r.CompanyId == request.CompanyId
                         && r.Date >= start
                         && r.Date <= end);

            if (request.CustomerId.HasValue)
                query = query.Where(r => r.CustomerId == request.CustomerId);

            if (request.UserId.HasValue)
                query = query.Where(r => r.UserId == request.UserId);

            if (request.WarehouseId.HasValue)
                query = query.Where(r => r.WarehouseId == request.WarehouseId);

            var grouped = await query
                .GroupBy(r => new { r.UserId, r.PaymentTypeName })
                .Select(g => new
                {
                    UserId          = g.Key.UserId,
                    PaymentTypeName = g.Key.PaymentTypeName,
                    Amount          = g.Sum(r => r.Amount),
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
                    return new PaymentTypesByUserDto
                    {
                        UserName        = displayName,
                        PaymentTypeName = g.PaymentTypeName,
                        Amount          = g.Amount,
                    };
                })
                .OrderBy(r => r.UserName)
                .ThenBy(r => r.PaymentTypeName)
                .ToList();
        }
    }
}
