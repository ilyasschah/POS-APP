using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;

namespace Products.Api.Commands.CurrencyCommands.Update
{
    public class UpdateCurrencyCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdateCurrencyRequest Request { get; }

        public UpdateCurrencyCommand(int id, UpdateCurrencyRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdateCurrencyCommandHandler : IRequestHandler<UpdateCurrencyCommand, bool>
        {
            private readonly CurrencyService _service;

            public UpdateCurrencyCommandHandler(CurrencyService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateCurrencyCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
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
