using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.ProductGroupsQuery
{
    public class GetRootProductGroupsQuery : IRequest<List<ProductGroupDto>>
    {
        public class GetRootProductGroupsQueryHandler
            : IRequestHandler<GetRootProductGroupsQuery, List<ProductGroupDto>>
        {
            private readonly ProductGroupRepository _repository;

            public GetRootProductGroupsQueryHandler(ProductGroupRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductGroupDto>> Handle(GetRootProductGroupsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetRootsAsync();
                return list.Select(MapperProductGroup.MapToProductGroupDto).ToList();
            }
        }
    }
}
