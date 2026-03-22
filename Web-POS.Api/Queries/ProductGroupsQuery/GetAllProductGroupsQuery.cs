using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ProductGroupsQuery
{
    public class GetAllProductGroupsQuery : IRequest<List<ProductGroupDto>>
    {
        public class GetAllProductGroupsQueryHandler
            : IRequestHandler<GetAllProductGroupsQuery, List<ProductGroupDto>>
        {
            private readonly ProductGroupRepository _repository;

            public GetAllProductGroupsQueryHandler(ProductGroupRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductGroupDto>> Handle(GetAllProductGroupsQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetAllAsync();
                return list.Select(MapperProductGroup.MapToProductGroupDto).ToList();
            }
        }
    }
}
