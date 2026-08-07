using Api.DataBase;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace Api.Commands.Dashboard
{
    public class DashboardDataDto
    {
        public decimal TotalSales { get; set; }
        public List<MonthlySaleDto> MonthlySales { get; set; } = new();
        public List<HourlySaleDto> HourlySales { get; set; } = new();
        public List<TopProductDto> TopProducts { get; set; } = new();
        public List<TopGroupDto> TopProductGroups { get; set; } = new();
        public List<TopCustomerDto> TopCustomers { get; set; } = new();
    }

    public record MonthlySaleDto(int Month, int Year, decimal Total);
    public record HourlySaleDto(int Hour, decimal Total);
    public record TopProductDto(string ProductName, decimal Quantity, decimal Total);
    public record TopGroupDto(string GroupName, decimal Total);
    public record TopCustomerDto(string CustomerName, decimal Total);

    /// <param name="TzOffsetMinutes">
    /// The caller's offset from UTC, in minutes (e.g. +60 for UTC+1). Used to
    /// report Hourly Peak Times in local time — see the Handler. 0 keeps the
    /// legacy UTC behaviour for callers that don't send it.
    /// </param>
    public record GetDashboardDataQuery(
        int CompanyId,
        DateTime StartDate,
        DateTime EndDate,
        int TzOffsetMinutes = 0) : IRequest<DashboardDataDto>;

    // 3. The Handler
    public class GetDashboardDataQueryHandler : IRequestHandler<GetDashboardDataQuery, DashboardDataDto>
    {
        private readonly AppDbContext _context;

        public GetDashboardDataQueryHandler(AppDbContext context)
        {
            _context = context;
        }

        public async Task<DashboardDataDto> Handle(GetDashboardDataQuery request, CancellationToken cancellationToken)
        {
            var baseQuery = _context.DashboardSalesDataViews
                .Where(x => x.CompanyId == request.CompanyId
                         && x.Date >= request.StartDate
                         && x.Date <= request.EndDate);

            var dashboardData = new DashboardDataDto();

            dashboardData.TotalSales = await baseQuery.SumAsync(x => x.ItemTotal, cancellationToken);

            // 1. Fetch Monthly Sales (Anonymous type first, then map to DTO)
            var monthlyData = await baseQuery
                .GroupBy(x => new { x.SalesYear, x.SalesMonth })
                .Select(g => new { g.Key.SalesMonth, g.Key.SalesYear, Total = g.Sum(x => x.ItemTotal) })
                .ToListAsync(cancellationToken);

            dashboardData.MonthlySales = monthlyData
                .Select(x => new MonthlySaleDto(x.SalesMonth, x.SalesYear, x.Total))
                .OrderBy(x => x.Year).ThenBy(x => x.Month)
                .ToList();

            // 2. Fetch Hourly Sales.
            // The view buckets on the UTC hour, because StockDate is written as
            // DateTime.UtcNow. Rotate the buckets into the caller's timezone so
            // "Hourly Peak Times" reads in local time and agrees with the POS
            // app, which buckets on toLocal(). Rotating whole buckets is exact
            // for whole-hour offsets; a :30/:45 zone lands on the nearest hour,
            // which is as precise as an hour bucket gets anyway.
            var hourlyData = await baseQuery
                .GroupBy(x => x.SalesHour)
                .Select(g => new { Hour = g.Key, Total = g.Sum(x => x.ItemTotal) })
                .ToListAsync(cancellationToken);

            var offsetHours = (int)Math.Round(
                request.TzOffsetMinutes / 60.0, MidpointRounding.AwayFromZero);

            dashboardData.HourlySales = hourlyData
                .GroupBy(x => ((x.Hour + offsetHours) % 24 + 24) % 24)
                .Select(g => new HourlySaleDto(g.Key, g.Sum(x => x.Total)))
                .OrderBy(x => x.Hour)
                .ToList();

            // 3. Fetch Top Products
            var topProductsData = await baseQuery
                .Where(x => x.ProductName != null)
                .GroupBy(x => x.ProductName)
                .Select(g => new { ProductName = g.Key, Quantity = g.Sum(x => x.Quantity), Total = g.Sum(x => x.ItemTotal) })
                .OrderByDescending(x => x.Total)
                .Take(5)
                .ToListAsync(cancellationToken);

            dashboardData.TopProducts = topProductsData
                .Select(x => new TopProductDto(x.ProductName!, x.Quantity, x.Total))
                .ToList();

            // 4. Fetch Top Groups
            var topGroupsData = await baseQuery
                .Where(x => x.ProductGroupName != null)
                .GroupBy(x => x.ProductGroupName)
                .Select(g => new { GroupName = g.Key, Total = g.Sum(x => x.ItemTotal) })
                .OrderByDescending(x => x.Total)
                .Take(5)
                .ToListAsync(cancellationToken);

            dashboardData.TopProductGroups = topGroupsData
                .Select(x => new TopGroupDto(x.GroupName!, x.Total))
                .ToList();

            // 5. Fetch Top Customers
            var topCustomersData = await baseQuery
                .Where(x => x.CustomerName != null)
                .GroupBy(x => x.CustomerName)
                .Select(g => new { CustomerName = g.Key, Total = g.Sum(x => x.ItemTotal) })
                .OrderByDescending(x => x.Total)
                .Take(5)
                .ToListAsync(cancellationToken);

            dashboardData.TopCustomers = topCustomersData
                .Select(x => new TopCustomerDto(x.CustomerName!, x.Total))
                .ToList();

            return dashboardData;
        }
    }
}