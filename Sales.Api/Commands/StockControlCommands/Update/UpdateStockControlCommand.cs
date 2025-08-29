// FILE: Sales.Api.Commands\StockControlCommands\Update\UpdateStockControlCommand.cs

using FluentValidation;
using MediatR;
using Sales.Api.Models;
using Sales.Api.Services;

namespace Sales.Api.Commands.StockControlCommands.Update;

public class UpdateStockControlCommand : IRequest<bool>
{
    public UpdateStockControlRequest Request { get; set; }

    public UpdateStockControlCommand(UpdateStockControlRequest request)
    {
        Request = request;
    }

    public class UpdateStockControlCommandHandler : IRequestHandler<UpdateStockControlCommand, bool>
    {
        private readonly StockControlService _service;

        public UpdateStockControlCommandHandler(StockControlService service)
        {
            _service = service;
        }

        public Task<bool> Handle(UpdateStockControlCommand request, CancellationToken cancellationToken)
        {
            return _service.Update(request.Request);
        }
    }

    public class UpdateStockControlCommandValidator : AbstractValidator<UpdateStockControlCommand>
    {
        public UpdateStockControlCommandValidator()
        {
            RuleFor(c => c.Request.Id).GreaterThan(0).WithMessage("Id must be valid.");
        }
    }
}
