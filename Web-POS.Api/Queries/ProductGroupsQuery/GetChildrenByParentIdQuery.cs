using MediatR;
using Api.Helpers;
using Api.Repository;
using Api.Models;

namespace Api.Queries.ProductGroupsQuery
{
    public class GetChildrenByParentIdQuery : IRequest<List<ProductGroupDto>>
    {
        public int ParentGroupId { get; set; }

        public class GetChildrenByParentIdQueryHandler
            : IRequestHandler<GetChildrenByParentIdQuery, List<ProductGroupDto>>
        {
            private readonly ProductGroupRepository _repository;

            public GetChildrenByParentIdQueryHandler(ProductGroupRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<ProductGroupDto>> Handle(GetChildrenByParentIdQuery request, CancellationToken cancellationToken)
            {
                var list = await _repository.GetChildrenAsync(request.ParentGroupId);
                return list.Select(MapperProductGroup.MapToProductGroupDto).ToList();
            }
        }
    }
}
