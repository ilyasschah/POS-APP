using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.CompanyCommands.Update;

public class UpdateCompanyCommand : IRequest<CompanyDto>
{
    public UpdateCompanyRequest Request { get; set; }

    public UpdateCompanyCommand(UpdateCompanyRequest request)
    {
        Request = request;
    }
    public class UpdateCompanyCommandHandler : IRequestHandler<UpdateCompanyCommand, CompanyDto>
    {
        private readonly CompanyService _service;

        public UpdateCompanyCommandHandler(CompanyService service)
        {
            _service = service;
        }
        public async Task<CompanyDto> Handle(UpdateCompanyCommand request, CancellationToken cancellationToken)
        {
            var updatedEntity = await _service.Update_DetailsAsync(request.Request);
            return updatedEntity;
        }
    }
    public class UpdateCompanyCommandValidator : AbstractValidator<UpdateCompanyCommand>
    {
        public UpdateCompanyCommandValidator()
        {
            RuleFor(c => c.Request.Id).NotNull().NotEmpty().WithMessage("Id must not be empty.");
            RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Name must not be empty.");
            RuleFor(c => c.Request.CountryId).NotNull().NotEmpty().WithMessage("CountryId must not be empty.");
        }
    }
}
