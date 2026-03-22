using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.StockQuery
{
    public class GetStockByIdQuery : IRequest<StockDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }
        public class GetStockByIdQueryHandler : IRequestHandler<GetStockByIdQuery, StockDto?>
        {
            private readonly StockRepository _stockRepository;
            public GetStockByIdQueryHandler(StockRepository stockRepository)
            {
                _stockRepository = stockRepository;
            }
            public async Task<StockDto?> Handle(GetStockByIdQuery request, CancellationToken cancellationToken)
            {
                var stockEntity = await _stockRepository.GetStockByIdAsync(request.Id, request.CompanyId);
                return stockEntity == null ? null : MapperStock_P_Name_W_Name.MapToStockDetails(stockEntity);
            }
        }
    }
    public class GetStockByIdQueryValidator : AbstractValidator<GetStockByIdQuery>
    {
        public GetStockByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Stock ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
