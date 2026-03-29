using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;
using System.Threading;
using System.Threading.Tasks;

namespace Api.Commands.StockControlCommands.Add
{
    public class AddStockControlCommand : IRequest<bool>
    {
        public CreateStockControlRequest Request { get; set; }
        public int CompanyId { get; set; } 

        public AddStockControlCommand(CreateStockControlRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddStockControlCommandHandler : IRequestHandler<AddStockControlCommand, bool>
        {
            private readonly StockControlService _service;

            public AddStockControlCommandHandler(StockControlService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(AddStockControlCommand request, CancellationToken cancellationToken)
            {
                return await _service.Create(request.Request, request.CompanyId);
            }
        }

        public class AddStockControlCommandValidator : AbstractValidator<AddStockControlCommand>
        {
            public AddStockControlCommandValidator()
            {
                RuleFor(c => c.Request.ProductId).GreaterThan(0).WithMessage("ProductId must be valid.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId is required."); // Validating tenant
            }
        }
    }
}