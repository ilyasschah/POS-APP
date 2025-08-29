// File: Commands/PosOrderCommands/Update/UpdatePosOrderCommand.cs

using FluentValidation;
using MediatR;
using Sales.Api.Models;
using Sales.Api.Services;
using System.Threading;
using System.Threading.Tasks;

namespace Sales.Api.Commands.PosOrderCommands.Delete
{
    public class UpdatePosOrderCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdatePosOrderRequest Request { get; }

        public UpdatePosOrderCommand(int id, UpdatePosOrderRequest request)
        {
            Id = id;
            Request = request;
        }

        // Nested Handler
        public class UpdatePosOrderCommandHandler : IRequestHandler<UpdatePosOrderCommand, bool>
        {
            private readonly PosOrderService _service;

            public UpdatePosOrderCommandHandler(PosOrderService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdatePosOrderCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        // Nested Validator
        public class UpdatePosOrderCommandValidator : AbstractValidator<UpdatePosOrderCommand>
        {
            public UpdatePosOrderCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0).WithMessage("A valid Order ID is required.");
                RuleFor(c => c.Request.Number).NotNull().NotEmpty().WithMessage("Order number is required.");
                RuleFor(c => c.Request.UserId).GreaterThan(0).WithMessage("A valid user is required.");
            }
        }
    }
}