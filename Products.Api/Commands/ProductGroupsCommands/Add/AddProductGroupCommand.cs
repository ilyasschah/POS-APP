using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.ProductGroupsCommands.Add
{
    public class AddProductGroupcommand(CreateProductGroupRequest createProductGroupRequest) : IRequest<bool>
    {
        public CreateProductGroupRequest Request { get; set; } = createProductGroupRequest;

        public class AddProductGroupcommandHandler(ProductGroupService productGroupService) : IRequestHandler<AddProductGroupcommand, bool>
        {
            private readonly ProductGroupService _productGroupService = productGroupService;

            public Task<bool> Handle(AddProductGroupcommand request, CancellationToken cancellationToken)
            {
                return _productGroupService.Create(request.Request.Name, request.Request.ParentGroupId, request.Request.Color, request.Request.Image, request.Request.Rank);
            }
        }
    }
}