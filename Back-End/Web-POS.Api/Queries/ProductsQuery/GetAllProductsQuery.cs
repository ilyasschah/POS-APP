using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.ProductsQuery
{
    public class GetAllProductsQuery : IRequest<List<ProductDto>>
    {
        public int CompanyId { get; set; }
        public DateTime? ModifiedAfter { get; set; }

        public class GetAllProductsQueryHandler : IRequestHandler<GetAllProductsQuery, List<ProductDto>>
        {
            private readonly ProductRepository _repository;

            public GetAllProductsQueryHandler(ProductRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductDto>> Handle(GetAllProductsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync(request.CompanyId, request.ModifiedAfter);
                return list.Select(MapperProduct.MapToProductDto).ToList();
            }
        }
    }
}
