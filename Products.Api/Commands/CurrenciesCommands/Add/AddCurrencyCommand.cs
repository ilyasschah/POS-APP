using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.CurrenciesCommands.Add
{
    public class AddCurrencycommand : IRequest<bool>
    {
        public CreateCurrencyRequest request { get; set; }
        
        public AddCurrencycommand(CreateCurrencyRequest createCurrencyRequest)
        {
            request = createCurrencyRequest;
        }
        public class AddCurrencycommandHandler : IRequestHandler<AddCurrencycommand, bool>
        {
            private readonly CurrencyService _currencyService;
            public AddCurrencycommandHandler(CurrencyService currencyService)
            {
                _currencyService = currencyService;
            }
            public Task<bool> Handle(AddCurrencycommand request, CancellationToken cancellationToken)
            {
                return _currencyService.Create(request.request.Name , request.request.Code);
            }
        }
    }
}
    
