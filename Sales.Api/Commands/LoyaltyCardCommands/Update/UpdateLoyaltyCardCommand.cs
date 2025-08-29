// FILE: Sales.Api.Commands\LoyaltyCardCommands\Update\UpdateLoyaltyCardCommand.cs

using FluentValidation;
using MediatR;
using Sales.Api.Models;
using Sales.Api.Services;

namespace Sales.Api.Commands.LoyaltyCardCommands.Update;

public class UpdateLoyaltyCardCommand : IRequest<bool>
{
    public UpdateLoyaltyCardRequest Request { get; set; }

    public UpdateLoyaltyCardCommand(UpdateLoyaltyCardRequest request)
    {
        Request = request;
    }

    public class UpdateLoyaltyCardCommandHandler : IRequestHandler<UpdateLoyaltyCardCommand, bool>
    {
        private readonly LoyaltyCardService _service;

        public UpdateLoyaltyCardCommandHandler(LoyaltyCardService service)
        {
            _service = service;
        }

        public Task<bool> Handle(UpdateLoyaltyCardCommand request, CancellationToken cancellationToken)
        {
            return _service.Update(request.Request);
        }
    }

    public class UpdateLoyaltyCardCommandValidator : AbstractValidator<UpdateLoyaltyCardCommand>
    {
        public UpdateLoyaltyCardCommandValidator()
        {
            RuleFor(c => c.Request.Id).GreaterThan(0).WithMessage("Id must be valid.");
        }
    }
}
