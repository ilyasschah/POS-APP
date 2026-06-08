// FILE: Products.Api.Commands\LoyaltyCardCommands\Add\AddLoyaltyCardCommand.cs

using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.LoyaltyCardCommands.Add;

public class AddLoyaltyCardCommand : IRequest<bool>
{
    
    public CreateLoyaltyCardRequest Request { get; set; }
    public int CompanyId { get; set; }

    public AddLoyaltyCardCommand(CreateLoyaltyCardRequest request, int companyId)
    {
        Request = request;
        CompanyId = companyId;
    }

    public class AddLoyaltyCardCommandHandler : IRequestHandler<AddLoyaltyCardCommand, bool>
    {
        private readonly LoyaltyCardService _service;

        public AddLoyaltyCardCommandHandler(LoyaltyCardService service)
        {
            _service = service;
        }

        public Task<bool> Handle(AddLoyaltyCardCommand request, CancellationToken cancellationToken)
        {
            return _service.Create(request.Request, request.CompanyId);
        }
    }

    public class AddLoyaltyCardCommandValidator : AbstractValidator<AddLoyaltyCardCommand>
    {
        public AddLoyaltyCardCommandValidator()
        {
            RuleFor(c => c.Request.CustomerId).GreaterThan(0).WithMessage("CustomerId must be valid.");
        }
    }
}
