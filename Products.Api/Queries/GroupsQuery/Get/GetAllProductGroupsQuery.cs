//using MediatR;
//using Products.Api.Models;
//using Products.Api.Repository;
//namespace Products.Api.Queries.GroupsQuery.Get
//{
//    public class GetAllProductGroupsQuery : IRequest<ProductGroupInfoDto[]>
//    {
//        public class GetAllProductGroupsQueryHandler : IRequestHandler<GetAllProductGroupsQuery, ProductGroupInfoDto[]>
//        {
//            private readonly ProductGroupRepository _productGroupRepository;
//            public GetAllProductGroupsQueryHandler(ProductGroupRepository productGroupRepository)
//            {
//                _productGroupRepository = productGroupRepository;
//            }
//            public async Task<ProductGroupInfoDto[]> Handle(GetAllProductGroupsQuery request, CancellationToken cancellationToken)
//            {
//                return await _productGroupRepository.GetAllProductGroupsAsync();
//            }
//        }
//    }
//}
