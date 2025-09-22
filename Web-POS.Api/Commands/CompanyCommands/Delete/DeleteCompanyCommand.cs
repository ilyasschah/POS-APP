using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.CompanyCommands.Delete;

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

        public Task<bool> Handle(DeleteCompanyCommand request, CancellationToken cancellationToken)
        {
            return _service.Delete(request.Id);
        }
    }
}
