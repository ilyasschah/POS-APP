using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Services;
using Api.Models;

namespace Api.Commands.StockCommands.Add
{
    public class AddStockCommand : IRequest<StockDto>
    {
        public CreateStockRequest Request { get; set; }
        public int CompanyId { get; }

        public AddStockCommand(CreateStockRequest request, int companyId)
        {
            Request = request;
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
                return await _stockService.CreateStockAsync(request.Request, request.CompanyId);
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

