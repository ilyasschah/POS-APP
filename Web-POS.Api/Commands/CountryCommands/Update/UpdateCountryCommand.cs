using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.CountryCommands.Update
{
    public class UpdateCountryCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdateCountryRequest Request { get; }
        public int CompanyId { get; }

        public UpdateCountryCommand(int id, UpdateCountryRequest request, int companyId)
        {
            Id = id;
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateCountryCommandHandler : IRequestHandler<UpdateCountryCommand, bool>
        {
            private readonly CountryService _service;
            public UpdateCountryCommandHandler(CountryService service) => _service = service;
            public Task<bool> Handle(UpdateCountryCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request.Name, command.CompanyId);
            }
        }

        public class UpdateCountryCommandValidator : AbstractValidator<UpdateCountryCommand>
        {
            public UpdateCountryCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty();
            }
        }
    }
}
