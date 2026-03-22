using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ProductGroupsQuery
{
    public class GetProductGroupByNameQuery : IRequest<ProductGroupDto?>
    {
        public string Name { get; set; } = default!;

        public class GetProductGroupByNameQueryHandler
            : IRequestHandler<GetProductGroupByNameQuery, ProductGroupDto?>
        {
            private readonly ProductGroupRepository _repository;

            public GetProductGroupByNameQueryHandler(ProductGroupRepository repository)
            {
                _repository = repository;
            }

            public async Task<ProductGroupDto?> Handle(GetProductGroupByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name);
                return entity == null ? null : MapperProductGroup.MapToProductGroupDto(entity);
            }
        }
    }
}
