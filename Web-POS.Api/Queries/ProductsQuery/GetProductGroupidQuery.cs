using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.ProductsQuery
{
    public class GetProductGroupQuery : IRequest<List<ProductDto?>>
    {
        public int ProductGroup { get; set; } = default!;
        public int CompanyId { get; set; }

        public class GetProductByProductGroupQueryHandler : IRequestHandler<GetProductGroupQuery, List<ProductDto?>>
        {
            private readonly ProductRepository _repository;

            public GetProductByProductGroupQueryHandler(ProductRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductDto?>> Handle(GetProductGroupQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByProductGroupAsync(request.ProductGroup, request.CompanyId);
                return entity == null ? null : MapperProduct.MapToProductDtoPG(entity);
            }
        }
    }

}
