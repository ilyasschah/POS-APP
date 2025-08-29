using FluentValidation;
using MediatR;
using Sales.Api.Models;
using Sales.Api.Services;

namespace Sales.Api.Commands.CompanyCommands.Add;

public class AddCompanyCommand : IRequest<bool>
{
    public CreateCompanyRequest Request { get; set; }

    public AddCompanyCommand(CreateCompanyRequest request)
    {
        Request = request;
    }

    public class AddCompanyCommandHandler : IRequestHandler<AddCompanyCommand, bool>
    {
        private readonly CompanyService _service;

        public AddCompanyCommandHandler(CompanyService service)
        {
            _service = service;
        }

        public Task<bool> Handle(AddCompanyCommand request, CancellationToken cancellationToken)
        {
            return _service.Create(request.Request);
        }
    }

    public class AddCompanyCommandValidator : AbstractValidator<AddCompanyCommand>
    {
        public AddCompanyCommandValidator()
        {
            RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Name must not be empty.");
            RuleFor(c => c.Request.CountryId).NotNull().NotEmpty().WithMessage("CountryId must not be empty.");
        }
    }
}
