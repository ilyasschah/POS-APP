using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.ProductTaxQuery.Get
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