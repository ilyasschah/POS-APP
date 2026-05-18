using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ReportQueries
{
    public class GetSalesByProductGroupQuery : IRequest<List<SalesByProductGroupDto>>
    {
        public int CompanyId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public int? WarehouseId { get; set; }
        public int? ProductId { get; set; }
        public int? ProductGroupId { get; set; }
        public bool IncludeSubgroups { get; set; }
    }

    public class GetSalesByProductGroupQueryHandler
        : IRequestHandler<GetSalesByProductGroupQuery, List<SalesByProductGroupDto>>
    {
        private readonly AppDbContext _db;

        public GetSalesByProductGroupQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<SalesByProductGroupDto>> Handle(
            GetSalesByProductGroupQuery request,
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
            {
                List<int> groupIds;

                if (request.IncludeSubgroups)
                {
                    var allGroups = await _db.ProductGroups
                        .Where(g => g.CompanyId == request.CompanyId)
                        .Select(g => new { g.Id, g.ParentGroupId })
                        .ToListAsync(cancellationToken);

                    var ids = new HashSet<int> { request.ProductGroupId.Value };
                    bool changed;
                    do
                    {
                        changed = false;
                        foreach (var g in allGroups)
                            if (g.ParentGroupId.HasValue
                                && ids.Contains(g.ParentGroupId.Value)
                                && ids.Add(g.Id))
                                changed = true;
                    } while (changed);

                    groupIds = ids.ToList();
                }
                else
                {
                    groupIds = new List<int> { request.ProductGroupId.Value };
                }

                query = query.Where(r => r.ProductGroupId != null
                                      && groupIds.Contains(r.ProductGroupId!.Value));
            }

            return await query
                .GroupBy(r => new { r.ProductGroupId, r.ProductGroupName })
                .Select(g => new SalesByProductGroupDto
                {
                    ProductGroup   = g.Key.ProductGroupName ?? "Uncategorized",
                    Quantity       = g.Sum(r => r.Quantity),
                    TotalBeforeTax = g.Sum(r => r.TotalBeforeTax),
                    Total          = g.Sum(r => r.Total),
                })
                .OrderBy(r => r.ProductGroup)
                .ToListAsync(cancellationToken);
        }
    }
}
