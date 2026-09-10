using Api.DataBase;
using Api.Models;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.ProductGroupsQuery
{
    /// <summary>
    /// Every product group of a company, parents before children, for export.
    /// </summary>
    /// <remarks>
    /// Deliberately NOT <c>GetAll</c>: that one ships each group's image, which an
    /// export has no column for. And the order is the point — parents first,
    /// siblings by rank then name — so a reader, a spreadsheet user or a simple
    /// importer always meets a parent before the group that names it.
    /// </remarks>
    public class GetProductGroupsForExportQuery : IRequest<List<ProductGroupExportDto>>
    {
        public int CompanyId { get; set; }
    }

    public class GetProductGroupsForExportQueryHandler
        : IRequestHandler<GetProductGroupsForExportQuery, List<ProductGroupExportDto>>
    {
        private readonly AppDbContext _db;
        public GetProductGroupsForExportQueryHandler(AppDbContext db) => _db = db;

        public async Task<List<ProductGroupExportDto>> Handle(
            GetProductGroupsForExportQuery request, CancellationToken ct)
        {
            var groups = await _db.ProductGroups.AsNoTracking()
                .Where(g => g.CompanyId == request.CompanyId)
                .Select(g => new { g.Id, g.Name, g.ParentGroupId, g.Color, g.Rank })
                .ToListAsync(ct);

            if (groups.Count == 0) return [];

            var counts = await _db.Products.AsNoTracking()
                .Where(p => p.CompanyId == request.CompanyId && p.ProductGroupId != null)
                .GroupBy(p => p.ProductGroupId!.Value)
                .Select(g => new { GroupId = g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.GroupId, x => x.Count, ct);

            var byId = groups.ToDictionary(g => g.Id);

            // A parent that is not in this company (or not at all) makes the group a
            // root rather than dropping it: an export must never lose a row.
            int? ParentOf(int id) =>
                byId[id].ParentGroupId is int p && byId.ContainsKey(p) && p != id ? p : null;

            var children = groups
                .GroupBy(g => ParentOf(g.Id) ?? 0)
                .ToDictionary(
                    g => g.Key,
                    g => g.OrderBy(x => x.Rank).ThenBy(x => x.Name, StringComparer.OrdinalIgnoreCase).ToList());

            var ordered = new List<ProductGroupExportDto>(groups.Count);
            var visited = new HashSet<int>();

            void Walk(int parentKey)
            {
                if (!children.TryGetValue(parentKey, out var kids)) return;
                foreach (var g in kids)
                {
                    if (!visited.Add(g.Id)) continue;
                    ordered.Add(new ProductGroupExportDto
                    {
                        Id = g.Id,
                        Name = g.Name,
                        ParentGroupName = ParentOf(g.Id) is int p ? byId[p].Name : null,
                        Color = string.IsNullOrWhiteSpace(g.Color) ? "Transparent" : g.Color,
                        Rank = g.Rank,
                        ProductCount = counts.GetValueOrDefault(g.Id),
                    });
                    Walk(g.Id);
                }
            }

            Walk(0);

            // Anything a cycle kept out of the walk (A under B under A) still ships,
            // as a root — the importer then decides what to do with the loop.
            foreach (var g in groups.Where(g => !visited.Contains(g.Id))
                         .OrderBy(g => g.Rank).ThenBy(g => g.Name, StringComparer.OrdinalIgnoreCase))
            {
                visited.Add(g.Id);
                ordered.Add(new ProductGroupExportDto
                {
                    Id = g.Id,
                    Name = g.Name,
                    ParentGroupName = null,
                    Color = string.IsNullOrWhiteSpace(g.Color) ? "Transparent" : g.Color,
                    Rank = g.Rank,
                    ProductCount = counts.GetValueOrDefault(g.Id),
                });
            }

            return ordered;
        }
    }
}
