// FILE: Products.Api.Commands\StockControlCommands\Add\AddStockControlCommand.cs

using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.StockControlCommands.Add;

public class AddStockControlCommand : IRequest<bool>
{
    public CreateStockControlRequest Request { get; set; }

    public AddStockControlCommand(CreateStockControlRequest request)
    {
        Request = request;
    }

    public class AddStockControlCommandHandler : IRequestHandler<AddStockControlCommand, bool>
    {
        private readonly StockControlService _service;

        public AddStockControlCommandHandler(StockControlService service)
        {
            _service = service;
        }

        public Task<bool> Handle(AddStockControlCommand request, CancellationToken cancellationToken)
        {
            return _service.Create(request.Request);
        }
    }

    public class AddStockControlCommandValidator : AbstractValidator<AddStockControlCommand>
    {
        public AddStockControlCommandValidator()
        {
            RuleFor(c => c.Request.ProductId).GreaterThan(0).WithMessage("ProductId must be valid.");
        }
    }
}
