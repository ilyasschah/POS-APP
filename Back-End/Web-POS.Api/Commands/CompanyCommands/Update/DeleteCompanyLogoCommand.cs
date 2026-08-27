using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.CompanyCommands.Update
{
    /// <summary>
    /// Clears a company's logo. Lives beside UpdateCompanyLogoCommand because it
    /// is the same field, but it is a separate command on purpose: the update
    /// validates the payload as NotNull().NotEmpty(), and folding "delete" into
    /// it would mean an empty upload silently wiped the logo.
    /// </summary>
    public class DeleteCompanyLogoCommand : IRequest<bool>
    {
        public int Id { get; set; }

        public DeleteCompanyLogoCommand(int id)
        {
            Id = id;
        }

        public class DeleteCompanyLogoCommandHandler : IRequestHandler<DeleteCompanyLogoCommand, bool>
        {
            private readonly CompanyService _service;

            public DeleteCompanyLogoCommandHandler(CompanyService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteCompanyLogoCommand request, CancellationToken cancellationToken)
                => _service.Delete_LogoAsync(request.Id);
        }

        public class DeleteCompanyLogoCommandValidator : AbstractValidator<DeleteCompanyLogoCommand>
        {
            public DeleteCompanyLogoCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0).WithMessage("Id must not be empty.");
            }
        }
    }
}
