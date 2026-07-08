using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;
using System.Threading;
using System.Threading.Tasks;

namespace Api.Commands.StockControlCommands.Update
{
    public class UpdateStockControlCommand : IRequest<bool>
    {
        public UpdateStockControlRequest Request { get; set; }
        public int CompanyId { get; set; }

        public UpdateStockControlCommand(UpdateStockControlRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateStockControlCommandHandler : IRequestHandler<UpdateStockControlCommand, bool>
        {
            private readonly StockControlService _service;

            public UpdateStockControlCommandHandler(StockControlService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(UpdateStockControlCommand request, CancellationToken cancellationToken)
            {
                return await _service.Update(request.Request, request.CompanyId);
            }
        }

        public class UpdateStockControlCommandValidator : AbstractValidator<UpdateStockControlCommand>
        {
            public UpdateStockControlCommandValidator()
            {
                RuleFor(c => c.Request.Id).GreaterThan(0).WithMessage("Id must be valid.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId is required."); 
            }
        }
    }
}