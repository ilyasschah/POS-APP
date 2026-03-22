using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ProductTaxQuery
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