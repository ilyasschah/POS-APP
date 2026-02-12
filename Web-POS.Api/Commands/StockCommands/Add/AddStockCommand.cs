using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.StockCommands.Add
{
    public class AddStockCommand : IRequest<StockDto>
    {
        public CreateStockRequest Request { get; set; }
        public int CompanyId { get; }

        public AddStockCommand(CreateStockRequest createStockRequest, int companyId)
        {
            Request = createStockRequest;
            CompanyId = companyId;
        }
        public class AddStockCommandHandler : IRequestHandler<AddStockCommand, StockDto>
        {
            private readonly StockService _stockService;
            public AddStockCommandHandler(StockService stockService)
            {
                _stockService = stockService;
            }
            public async Task<StockDto> Handle(AddStockCommand request, CancellationToken cancellationToken)
            {
                var newEntity = await _stockService.CreateStockAsync(request.Request, request.CompanyId);
                return MapperStock_P_Name_W_Name.MapToStockDetails(newEntity);
            }
            public class AddStockCommandValidator : AbstractValidator<AddStockCommand>
            {
                public AddStockCommandValidator()
                {
                    RuleFor(o => o.Request.Quantity).NotNull().WithMessage("Quantity must not be null.");
                    RuleFor(pid => pid.Request.ProductId).NotNull().WithMessage("Product ID must be provided.");
                    RuleFor(wid => wid.Request.WarehouseId).NotNull().WithMessage("Warehouse ID must be provided.");
                }
            }
        }
    }
}

