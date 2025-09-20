using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.CurrenciesCommands.Delete
{
    public class DeleteCurrencyCommand : IRequest<bool>
    {
        public int Id { get; }

        public DeleteCurrencyCommand(int id)
        {
            Id = id;
        }

        public class DeleteCurrencyCommandHandler : IRequestHandler<DeleteCurrencyCommand, bool>
        {
            private readonly CurrencyService _service;

            public DeleteCurrencyCommandHandler(CurrencyService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteCurrencyCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id);
            }
        }
    }
}
