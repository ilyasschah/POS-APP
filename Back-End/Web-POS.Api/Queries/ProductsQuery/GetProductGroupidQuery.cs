using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.ProductsQuery
{
    public class GetProductGroupQuery : IRequest<List<ProductDto>>
    {
        public int ProductGroup { get; set; } = default!;
        public int CompanyId { get; set; }

        public class GetProductByProductGroupQueryHandler : IRequestHandler<GetProductGroupQuery, List<ProductDto>>
        {
            private readonly ProductRepository _repository;

            public GetProductByProductGroupQueryHandler(ProductRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductDto>> Handle(GetProductGroupQuery request, CancellationToken cancellationToken)
            {
                var entities = await _repository.GetByProductGroupAsync(request.ProductGroup, request.CompanyId);
                if (entities == null) return new List<ProductDto>();
                return MapperProduct.MapToProductDtoPG(entities);
            }
        }
    }

}
