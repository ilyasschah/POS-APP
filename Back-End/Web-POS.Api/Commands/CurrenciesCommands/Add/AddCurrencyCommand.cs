using MediatR;
using Api.Models;
using Api.Repository;
using Api.Domain;
using Api.Helpers;
using FluentValidation;

namespace Api.Commands.CurrenciesCommands.Add
{
    public class AddCurrencyCommand : IRequest<CurrencyDto>
    {
        public CreateCurrencyRequest Request { get; set; }

        public AddCurrencyCommand(CreateCurrencyRequest request)
        {
            Request = request;
        }

        public class AddCurrencyCommandHandler : IRequestHandler<AddCurrencyCommand, CurrencyDto>
        {
            private readonly CurrencyRepository _repository;

            public AddCurrencyCommandHandler(CurrencyRepository repository)
            {
                _repository = repository;
            }

            public async Task<CurrencyDto> Handle(AddCurrencyCommand command, CancellationToken cancellationToken)
            {
                if (await _repository.ExistsAsync(command.Request.Name))
                    throw new InvalidOperationException($"Currency '{command.Request.Name}' already exists.");

                var entity = Currency.Create(command.Request.Name, command.Request.Code);
                await _repository.AddAsync(entity);

                return MapperCurrency.MapToCurrencyDto(entity);
            }
        }
    }
    public class AddCurrencyCommandValidator : AbstractValidator<AddCurrencyCommand>
    {
        public AddCurrencyCommandValidator()
        {
            RuleFor(x => x.Request.Name).NotEmpty().WithMessage("Currency name is required.");
        }
    }
}