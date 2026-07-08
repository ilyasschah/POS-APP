using MediatR;
using Api.Repository;
using FluentValidation;

namespace Api.Commands.CurrenciesCommands.Delete
{
    public class DeleteCurrencyCommand : IRequest<bool>
    {
        public int Id { get; set; }

        public DeleteCurrencyCommand(int id)
        {
            Id = id;
        }

        public class DeleteCurrencyCommandHandler : IRequestHandler<DeleteCurrencyCommand, bool>
        {
            private readonly CurrencyRepository _repository;

            public DeleteCurrencyCommandHandler(CurrencyRepository repository)
            {
                _repository = repository;
            }

            public async Task<bool> Handle(DeleteCurrencyCommand command, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(command.Id);
                if (entity == null) throw new KeyNotFoundException("Currency not found.");

                await _repository.DeleteAsync(entity);
                return true;
            }
        }
    }
    public class DeleteCurrencyCommandValidator : AbstractValidator<DeleteCurrencyCommand>
    {
        public DeleteCurrencyCommandValidator()
        {
            RuleFor(c => c.Id).GreaterThan(0).WithMessage("Currency ID must be valid.");
        }
    }
}