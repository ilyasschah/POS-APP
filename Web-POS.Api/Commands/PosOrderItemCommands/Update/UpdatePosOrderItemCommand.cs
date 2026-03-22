using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.PosOrderItemCommands.Update
{
    public class UpdatePosOrderItemCommand : IRequest<bool>
    {
        public UpdatePosOrderItemRequest Request { get; set; }
        public UpdatePosOrderItemCommand (UpdatePosOrderItemRequest updatePosOrderItemRequest)
        {
            Request = updatePosOrderItemRequest;
        }
        public class UpdatePosOrderItemCommandHandler : IRequestHandler<UpdatePosOrderItemCommand, bool>
        {
            private readonly PosOrderItemService _service;

            public UpdatePosOrderItemCommandHandler(PosOrderItemService service)
            {
                _service = service;
            }
            public Task<bool> Handle(UpdatePosOrderItemCommand command, CancellationToken cancellationToken)
            {
                try
                {
                    return _service.UpdateAsync(command.Request);
                }
                catch (Exception)
                {

                    throw;
                }
            }
        }

        public class UpdatePosOrderItemCommandValidator : AbstractValidator<UpdatePosOrderItemCommand>
        {
            public UpdatePosOrderItemCommandValidator()
            {
                RuleFor(c => c.Request.Quantity).NotNull().NotEmpty().GreaterThan(0);
                RuleFor(c => c.Request.Price).NotNull().NotEmpty().GreaterThanOrEqualTo(0);
            }
        }
    }
}