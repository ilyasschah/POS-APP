using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.ProductsQuery
{
    public class GetProductByIdQuery : IRequest<ProductDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class GetProductByIdQueryHandler : IRequestHandler<GetProductByIdQuery, ProductDto?>
        {
            private readonly ProductRepository _repository;

            public GetProductByIdQueryHandler(ProductRepository repository)
            {
                _repository = repository;
            }

            public async Task<ProductDto?> Handle(GetProductByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
                return entity == null ? null : MapperProduct.MapToProductDto(entity);
            }
        }
    }
}
