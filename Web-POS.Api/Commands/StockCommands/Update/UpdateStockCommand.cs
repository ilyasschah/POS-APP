using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.StockCommands.Update
{
    public class UpdateStockCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public UpdateStockRequest Request { get; set; }
        public int CompanyId { get; }

        public UpdateStockCommand(UpdateStockRequest updateStockRequest, int companyId)
        {
            Request = updateStockRequest;
            CompanyId = companyId;
        }

        public class UpdateStockCommandHandler : IRequestHandler<UpdateStockCommand, bool>
        {
            private readonly StockService _stockService;
            public UpdateStockCommandHandler(StockService stockService)
            {
                _stockService = stockService;
            }
            public Task<bool> Handle(UpdateStockCommand request, CancellationToken cancellationToken)
            {
                try
                {
                    return _stockService.Update(request.Id, request.Request, request.CompanyId);

                }
                catch (Exception)
                {
                    throw;
                }
            }
            public class UpdateStockCommandValidator : AbstractValidator<UpdateStockCommand>
            {
                public UpdateStockCommandValidator()
                {
                    RuleFor(sv => sv.Request.newQuantity).NotNull().WithMessage("Stock value must not be null.");
                    RuleFor(wid => wid.Request.newWarehouseId).NotNull().WithMessage("Warehouse ID must be provided.");
                    RuleFor(sid => sid.Id).NotNull().WithMessage("Stock ID must be provided.");
                }
            }
        }
    }
}

