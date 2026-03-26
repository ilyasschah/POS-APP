using Api.Models;
using Api.Repository;
using FluentValidation;
using MediatR;

namespace Api.Commands.CurrenciesCommands.Update
{
    public class UpdateCurrencyCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public UpdateCurrencyRequest Request { get; set; }

        public UpdateCurrencyCommand(int id, UpdateCurrencyRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdateCurrencyCommandHandler : IRequestHandler<UpdateCurrencyCommand, bool>
        {
            private readonly CurrencyRepository _repository;

            public UpdateCurrencyCommandHandler(CurrencyRepository repository)
            {
                _repository = repository;
            }

            public async Task<bool> Handle(UpdateCurrencyCommand command, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(command.Id, trackEntity: true);
                if (entity == null) throw new KeyNotFoundException("Currency not found.");

                if (command.Request.Name != entity.Name && await _repository.ExistsAsync(command.Request.Name))
                    throw new InvalidOperationException($"Currency '{command.Request.Name}' already exists.");

                entity.Update(command.Request.Name, command.Request.Code);
                await _repository.UpdateAsync(entity);

                return true;
            }
        }

        public class UpdateCurrencyCommandValidator : AbstractValidator<UpdateCurrencyCommand>
        {
            public UpdateCurrencyCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty().MaximumLength(100);
                RuleFor(c => c.Request.Code).MaximumLength(10).When(x => x.Request.Code != null);
            }
        }
    }
}
