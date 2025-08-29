using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.GroupsQuery.Get
{
    public class GetProductGroupByNameQuery : IRequest<List<ProductGroupDto>>
    {
    }
    public class GetProductGroupByNameQueryHandler : IRequestHandler<GetProductGroupByNameQuery, List<ProductGroupDto>>
    {
        private readonly ProductGroupRepository _productgroupRepository;

        public GetProductGroupByNameQueryHandler(ProductGroupRepository productgroupRepository)
        {
            _productgroupRepository = productgroupRepository;
        }
        public async Task<List<ProductGroupDto>> Handle(GetProductGroupByNameQuery request, CancellationToken cancellationToken)
        {
            var productGroups = await _productgroupRepository.GetAllProductGroupsAsync();
            return productGroups.Select(MapperProductGroup.MapToProductGroupDetail).ToList();
        }
    }
}
