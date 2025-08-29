using MediatR;
using Products.Api.Domain;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;
using Products.Api.Services;

namespace Products.Api.Commands.ProductsCommentsCommands.Add
{
    public class AddProductCommentcommand : IRequest<bool>
    {
        public CreateProductCommentRequest Request { get; set; }

        public AddProductCommentcommand(CreateProductCommentRequest createproductcommentRequest)
        {
            Request = createproductcommentRequest;
        }
        public class AddProductCommentcommandHandler : IRequestHandler<AddProductCommentcommand, bool>
        {
            private readonly ProductCommentsService _productcommentsService;

            public AddProductCommentcommandHandler(ProductCommentsService productcommentsService)
            {
                _productcommentsService = productcommentsService;
            }
            public Task<bool> Handle(AddProductCommentcommand request, CancellationToken cancellationToken)
            {
                return _productcommentsService.Create(request.Request.Comment, request.Request.ProductId);
            }
        }
    }
}