using FluentValidation;
using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.CurrenciesCommands.Add
{
    public class AddCurrencyCommand : IRequest<CurrencyDto>
    {
        public CreateCurrencyRequest Request { get; }

        public AddCurrencyCommand(CreateCurrencyRequest request)
        {
            Request = request;
        }

        public class AddCurrencyCommandHandler : IRequestHandler<AddCurrencyCommand, CurrencyDto>
        {
            private readonly CurrencyService _service;

            public AddCurrencyCommandHandler(CurrencyService service)
            {
                _service = service;
            }

            public async Task<CurrencyDto> Handle(AddCurrencyCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.Request);
                return MapperCurrency.MapToCurrencyDto(entity);
            }
        }

        public class AddCurrencyCommandValidator : AbstractValidator<AddCurrencyCommand>
        {
            public AddCurrencyCommandValidator()
            {
                RuleFor(c => c.Request.Name).NotEmpty().MaximumLength(100);
                RuleFor(c => c.Request.Code).MaximumLength(10).When(x => x.Request.Code != null);
            }
        }
    }
}
