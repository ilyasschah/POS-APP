using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ProductTaxQuery
{
    public class GetProductTaxesByTaxIdQuery : IRequest<List<ProductTaxDto>>
    {
        public int TaxId { get; set; }

        public class GetProductTaxesByTaxIdQueryHandler : IRequestHandler<GetProductTaxesByTaxIdQuery, List<ProductTaxDto>>
        {
            private readonly ProductTaxRepository _repository;

            public GetProductTaxesByTaxIdQueryHandler(ProductTaxRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductTaxDto>> Handle(GetProductTaxesByTaxIdQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByTaxIdAsync(request.TaxId);
                return entities.Select(MapperProductTax.MapToProductTaxDto).ToList();
            }
        }
    }
}