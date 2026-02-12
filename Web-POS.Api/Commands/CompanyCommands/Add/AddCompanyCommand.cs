using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.CompanyCommands.Add;

public class AddCompanyCommand : IRequest<CompanyDto>
{
    public CreateCompanyRequest Request { get; set; }

    public AddCompanyCommand(CreateCompanyRequest request)
    {
        Request = request;
    }
    public class AddCompanyCommandHandler : IRequestHandler<AddCompanyCommand, CompanyDto>
    {
        private readonly CompanyService _service;

        public AddCompanyCommandHandler(CompanyService service)
        {
            _service = service;
        }

        public async Task<CompanyDto> Handle(AddCompanyCommand request, CancellationToken cancellationToken)
        {
            var newEntity = await _service.Create(request.Request);
            return newEntity;
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
