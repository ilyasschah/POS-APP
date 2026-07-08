using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.CountryCommands.Add
{
    public class AddCountryCommand(CreateCountryRequest createCountryRequest) : IRequest<bool>
    {
        public CreateCountryRequest Request { get; set; } = createCountryRequest;

        public class AddCountryCommandHandler : IRequestHandler<AddCountryCommand, bool>
        {
            private readonly CountryService _countryService;
            public AddCountryCommandHandler(CountryService countryService) => _countryService = countryService;
            public Task<bool> Handle(AddCountryCommand request, CancellationToken cancellationToken)
            {
                return _countryService.Create(request.Request.Name, request.Request.Code);
            }
        }
    }

}
