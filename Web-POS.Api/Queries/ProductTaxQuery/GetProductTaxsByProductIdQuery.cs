using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ProductTaxQuery
{
    public class GetProductTaxesByProductIdQuery : IRequest<List<ProductTaxDto>>
    {
        public int ProductId { get; set; }
        public class GetProductTaxesByProductIdQueryHandler : IRequestHandler<GetProductTaxesByProductIdQuery, List<ProductTaxDto>>
        {
            private readonly ProductTaxRepository _repository;
            public GetProductTaxesByProductIdQueryHandler(ProductTaxRepository repository)
            {
                _repository = repository;
            }
            public async Task<List<ProductTaxDto>> Handle(GetProductTaxesByProductIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByProductIdAsync(request.ProductId);
                return entities.Select(MapperProductTax.MapToProductTaxDto).ToList();
            }
        }
    }
}