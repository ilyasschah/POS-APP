using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.StockQuery
{
    public class GetAllStockQuery : IRequest<List<StockDto>>
    {
        public int CompanyId { get; set; }
    }
    public class GetAllStockQueryHandler : IRequestHandler<GetAllStockQuery, List<StockDto>>
    {
        private readonly StockRepository _stockRepository;

        public GetAllStockQueryHandler(StockRepository stockRepository)
        {
            _stockRepository = stockRepository;
        }
        public async Task<List<StockDto>> Handle(GetAllStockQuery request, CancellationToken cancellationToken)
        {
            var stockEntities = await _stockRepository.GetAllStocksAsync(request.CompanyId);
            return stockEntities.Select(MapperStock_P_Name_W_Name.MapToStockDetails).ToList();
        }
    }
    public class GetAllStockQueryValidator : AbstractValidator<GetAllStockQuery>
    {
        public GetAllStockQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}