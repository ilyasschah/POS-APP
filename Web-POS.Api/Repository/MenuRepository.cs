using Microsoft.EntityFrameworkCore;
using Api.DataBase;
using Api.Models;

namespace Api.Repository
{
    public class MenuRepository
    {
        private readonly AppDbContext _db;

        public MenuRepository(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<MenuCategoryDto>> GetFullMenuAsync(int companyId, int warehouseId)
        {
            return await _db.ProductGroups
                .Where(pg => pg.CompanyId == companyId)
                .AsNoTracking()
                .Select(pg => new MenuCategoryDto
                {
                    Id = pg.Id,
                    Name = pg.Name,
                    Color = pg.Color,
                    Image = pg.Image,

                    Products = _db.Products
                        .Where(p => p.ProductGroupId == pg.Id && p.CompanyId == companyId && p.IsEnabled)
                        .Select(p => new MenuProductDto
                        {
                            Id = p.Id,
                            Name = p.Name,
                            Price = p.Price,
                            IsTaxInclusivePrice = p.IsTaxInclusivePrice,
                            Color = p.Color,
                            Image = p.Image,

                            StockQuantity = _db.Stocks
                                .Where(s => s.ProductId == p.Id && s.WarehouseId == warehouseId)
                                .Select(s => s.Quantity)
                                .FirstOrDefault(),

                            Taxes = p.ProductTaxes.Select(pt => new MenuTaxDto
                            {
                                Id = pt.Tax.Id,
                                Name = pt.Tax.Name,
                                Rate = pt.Tax.Rate,
                                IsFixed = pt.Tax.IsFixed,
                                IsTaxOnTotal = pt.Tax.IsTaxOnTotal
                            }).ToList()
                        }).ToList()
                })
                .ToListAsync();
        }
    }
}