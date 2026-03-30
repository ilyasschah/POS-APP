using Api.Services;
using FluentValidation;
using MediatR;

namespace Api.Commands.CompanyCommands.Delete;

public class DeleteCompanyCommand : IRequest<bool>
{
    public int Id { get; }

    public DeleteCompanyCommand(int id)
    {
        Id = id;
    }
    public class DeleteCompanyCommandHandler : IRequestHandler<DeleteCompanyCommand, bool>
    {
        private readonly CompanyService _service;

        public DeleteCompanyCommandHandler(CompanyService service)
        {
            _service = service;
        }
        public async Task<bool> Handle(DeleteCompanyCommand request, CancellationToken cancellationToken)
        {
            var result = await _service.DeleteAsync(request.Id);
            return result;
        }
        public class DeleteCompanyCommandValidator : AbstractValidator<DeleteCompanyCommand>
        {
            public DeleteCompanyCommandValidator()
            {
                RuleFor(bcv => bcv.Id).NotNull().NotEmpty().WithMessage("Id must not be null.");
            }
        }
    }
}
