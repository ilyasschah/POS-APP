// FILE: Sales.Api.Commands\CompanyCommands\Update\UpdateCompanyCommand.cs

using FluentValidation;
using MediatR;
using Sales.Api.Models;
using Sales.Api.Services;

namespace Sales.Api.Commands.CompanyCommands.Update;

public class UpdateCompanyCommand : IRequest<bool>
{
    public UpdateCompanyRequest Request { get; set; }

    public UpdateCompanyCommand(UpdateCompanyRequest request)
    {
        Request = request;
    }

    public class UpdateCompanyCommandHandler : IRequestHandler<UpdateCompanyCommand, bool>
    {
        private readonly CompanyService _service;

        public UpdateCompanyCommandHandler(CompanyService service)
        {
            _service = service;
        }

        public Task<bool> Handle(UpdateCompanyCommand request, CancellationToken cancellationToken)
        {
            return _service.Update(request.Request);
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
