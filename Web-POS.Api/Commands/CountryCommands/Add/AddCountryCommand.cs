using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.CountryCommands.Add
{
    public class AddCountryCommand : IRequest<bool>
    {
        public CreateCountryRequest Request { get; set; }
        public int CompanyId { get; }

        public AddCountryCommand(CreateCountryRequest createCountryRequest, int companyId)
        {
            Request = createCountryRequest;
            CompanyId = companyId;
        }

        public class AddCountryCommandHandler : IRequestHandler<AddCountryCommand, bool>
        {
            private readonly CountryService _countryService;
            public AddCountryCommandHandler(CountryService countryService) => _countryService = countryService;
            public Task<bool> Handle(AddCountryCommand request, CancellationToken cancellationToken)
            {
                return _countryService.Create(request.Request.Name, request.Request.Code, request.CompanyId);
            }
        }
    }

}
