using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.CompanyCommands.Update
{
    public class UpdateCompanyCommand : IRequest<CompanyDto>
    {
        public UpdateCompanyRequest Request { get; }

        public UpdateCompanyCommand(UpdateCompanyRequest request)
        {
            Request = request;
        }

        public class UpdateCompanyCommandHandler : IRequestHandler<UpdateCompanyCommand, CompanyDto>
        {
            private readonly CompanyService _service;

            public UpdateCompanyCommandHandler(CompanyService service) => _service = service;

            public Task<CompanyDto> Handle(UpdateCompanyCommand command, CancellationToken cancellationToken)
            {
                return _service.Update_DetailsAsync(command.Request);
            }
        }
        public class UpdateCompanyCommandValidator : AbstractValidator<UpdateCompanyCommand>
        {
            public UpdateCompanyCommandValidator()
            {
                RuleFor(c => c.Request.Id).GreaterThan(0).WithMessage("Company ID must be valid.");
                RuleFor(c => c.Request.Name).NotEmpty().WithMessage("Company Name cannot be empty.");
                RuleFor(c => c.Request.CountryId).GreaterThan(0).WithMessage("Country ID must be valid.");
            }
        }
    }
}