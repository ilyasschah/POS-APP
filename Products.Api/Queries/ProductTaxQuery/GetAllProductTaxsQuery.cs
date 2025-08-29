using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.ProductTaxQuery.Get
{
    public class GetAllProductTaxesQuery : IRequest<List<ProductTaxDto>>
    {
        public class GetAllProductTaxesQueryHandler : IRequestHandler<GetAllProductTaxesQuery, List<ProductTaxDto>>
        {
            private readonly ProductTaxRepository _repository;

            public GetAllProductTaxesQueryHandler(ProductTaxRepository repository)
            {
                _repository = repository;
            }
            public async Task<List<ProductTaxDto>> Handle(GetAllProductTaxesQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetAllAsync();
                return entities.Select(MapperProductTax.MapToProductTaxDto).ToList();
            }
        }
    }
}