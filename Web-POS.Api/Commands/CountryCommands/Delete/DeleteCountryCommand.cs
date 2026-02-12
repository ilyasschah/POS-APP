using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.CountryCommands.Delete
{
    public class DeleteCountryCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }

        public DeleteCountryCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteCountryCommandHandler : IRequestHandler<DeleteCountryCommand, bool>
        {
            private readonly CountryService _service;

            public DeleteCountryCommandHandler(CountryService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteCountryCommand request, CancellationToken cancellationToken)
            {
                return _service.Delete(request.Id, request.CompanyId);
            }
        }
    }
}
