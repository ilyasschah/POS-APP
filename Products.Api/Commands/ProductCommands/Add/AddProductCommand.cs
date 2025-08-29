using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.ProductCommands.Add
{
    public class AddProductcommand(CreateProductRequest createproductRequest) : IRequest<bool>
    {
        public CreateProductRequest Request { get; set; } = createproductRequest;

        public class AddProductcommandHandler(ProductService productsService) : IRequestHandler<AddProductcommand, bool>
        {
            private readonly ProductService _productService = productsService;

            public Task<bool> Handle(AddProductcommand request, CancellationToken cancellationToken)
            {
                return _productService.Create(
                    request.Request.Name,
                    request.Request.Code,
                    request.Request.PLU,
                    request.Request.MeasurementUnit,
                    request.Request.Price,
                    request.Request.IsTaxInclusivePrice,
                    request.Request.IsPriceChangeAllowed,
                    request.Request.IsService,
                    request.Request.IsUsingDefaultQuantity,
                    request.Request.IsEnabled,
                    request.Request.Description,
                    request.Request.Cost,
                    request.Request.Markup,
                    request.Request.Image,
                    request.Request.Color,
                    request.Request.AgeRestriction,
                    request.Request.LastPurchasePrice,
                    request.Request.Rank,
                    request.Request.ProductGroupId,
                    request.Request.CurrencyId,
                    request.Request.DateCreated ?? DateTime.UtcNow,
                    request.Request.DateUpdated ?? DateTime.UtcNow
                    );
            }
        }
    }
}