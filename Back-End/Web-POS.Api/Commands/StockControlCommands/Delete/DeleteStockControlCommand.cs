using FluentValidation;
using MediatR;
using Api.Services;
using System.Threading;
using System.Threading.Tasks;

namespace Api.Commands.StockControlCommands.Delete
{
    public class DeleteStockControlCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; } // SECURED: Added CompanyId

        public DeleteStockControlCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteStockControlCommandHandler : IRequestHandler<DeleteStockControlCommand, bool>
        {
            private readonly StockControlService _service;

            public DeleteStockControlCommandHandler(StockControlService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(DeleteStockControlCommand request, CancellationToken cancellationToken)
            {
                // SECURED: Passing the CompanyId down to your Service layer
                return await _service.Delete(request.Id, request.CompanyId);
            }
        }

        public class DeleteStockControlCommandValidator : AbstractValidator<DeleteStockControlCommand>
        {
            public DeleteStockControlCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0).WithMessage("Id must be valid.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId is required."); // Validating tenant
            }
        }
    }
}