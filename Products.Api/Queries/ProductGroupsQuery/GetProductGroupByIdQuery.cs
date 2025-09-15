using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.ProductGroupQuery
{
    public class GetProductGroupByIdQuery : IRequest<ProductGroupDto?>
    {
        public int Id { get; set; }

        public class GetProductGroupByIdQueryHandler
            : IRequestHandler<GetProductGroupByIdQuery, ProductGroupDto?>
        {
            private readonly ProductGroupRepository _repository;

            public GetProductGroupByIdQueryHandler(ProductGroupRepository repository)
            {
                _repository = repository;
            }

            public async Task<ProductGroupDto?> Handle(GetProductGroupByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperProductGroup.MapToProductGroupDto(entity);
            }
        }
    }
}
